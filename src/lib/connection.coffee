###
  backbone-mongo.js 0.6.4
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-mongo
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

{MongoClient} = require 'mongodb'
{_, Queue, DatabaseURL, ConnectionPool} = require 'backbone-orm'
BackboneMongo = require '../core'

CONNECTION_QUERIES = require './connection_queries'

module.exports = class Connection
  constructor: (@url, @schema={}, options={}) ->
    throw new Error 'Expecting a string url' unless _.isString(@url)
    @connection_options = _.extend({}, BackboneMongo.connection_options, options)

    @collection_requests = []
    @db = null
    database_url = new DatabaseURL(@url, true)
    @collection_name = database_url.table

    # configure query options and regenerate URL
    database_url.query or= {}; delete database_url.search

    # allow for non-url options to be specified on the url (for example, journal)
    @connection_options[key] = value for key, value of database_url.query
    database_url.query = {}

    # transfer options to the url
    (database_url.query[key] = @connection_options[key]; delete @connection_options[key]) for key in CONNECTION_QUERIES when @connection_options.hasOwnProperty(key)
    @url = database_url.format({exclude_table: true})
    @_connect()

  destroy: ->
    return unless @db # already closed
    collection_requests = _.clone(@collection_requests); @collection_requests = []
    request(new Error('Client closed')) for request in collection_requests
    @_collection = null
    @db.close(); @db = null

  collection: (callback) ->
    return callback(null, @_collection) if @_collection

    # wait for connection
    @collection_requests.push(callback)

    # try to reconnect
    (@connection_error = null; @_connect()) if @connection_error

  _connect: ->
    queue = new Queue(1)

    # use pooled connection or create new
    queue.defer (callback) =>
      return callback() if (@db = ConnectionPool.get(@url))

      MongoClient.connect @url, @connection_options, (err, db) =>
        return callback(err) if err

        # it may have already been connected to asynchronously, release new
        if (@db = ConnectionPool.get(@url)) then db.close() else ConnectionPool.set(@url, @db = db)
        callback()

    # get the collection
    queue.defer (callback) =>
      @db.collection @collection_name, (err, collection) =>
        @_collection = collection unless err
        callback(err)

    # process awaiting requests
    queue.await (err) =>
      collection_requests = @collection_requests.splice(0, @collection_requests.length)
      if (@connection_error = err)
        console.log "BackboneMongo: unable to create connection. Error:", err
        request(new Error("Connection failed. Error: #{err.message or err}")) for request in collection_requests
      else
        request(null, @_collection) for request in collection_requests
