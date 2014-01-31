###
  backbone-mongo.js 0.5.2
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-mongo
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

_ = require 'underscore'
Queue = require 'backbone-orm/lib/queue'

DatabaseUrl = require 'backbone-orm/lib/database_url'
ConnectionPool = require 'backbone-orm/lib/connection_pool'
CONNECTION_QUERIES = require './connection_queries'

MongoClient = require('mongodb').MongoClient

module.exports = class Connection
  @options = {}

  constructor: (@url, @schema={}, options={}) ->
    throw new Error 'Expecting a string url' unless _.isString(@url)
    @connection_options = _.extend(_.clone(Connection.options), options)

    @collection_requests = []
    @db = null
    database_url = new DatabaseUrl(@url, true)
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

  ensureIndex: (field_name, table_name) =>
    index_info = {}; index_info[field_name] = 1
    @_collection.ensureIndex index_info, {background: true}, (err) =>
      return new Error("MongoBackbone: Failed to indexed '#{field_name}' on #{table_name}. Reason: #{err}") if err
      console.log("MongoBackbone: Successfully indexed '#{field_name}' on #{table_name}")

  _connect: ->
    queue = new Queue(1)

    # use pooled connection or create new
    queue.defer (callback) =>
      return callback() if @db = ConnectionPool.get(@url)

      MongoClient.connect @url, _.clone(@connection_options), (err, db) =>
        return callback(err) if err

        # it may have already been connected to asynchronously, release new
        if @db = ConnectionPool.get(@url) then db.close() else ConnectionPool.set(@url, @db = db)
        callback()

    # get the collection
    queue.defer (callback) =>
      @db.collection @collection_name, (err, collection) =>
        @_collection = collection unless err
        callback(err)

        # ensure indexes asyncronously
        @ensureIndex(key, @collection_name) for key, field of @schema.fields when field.indexed
        @ensureIndex(relation.foreign_key, @collection_name) for key, relation of @schema.relations when relation.type is 'belongsTo' and not relation.isVirtual() and not relation.isEmbedded()

    # process awaiting requests
    queue.await (err) =>
      collection_requests = @collection_requests.splice(0, @collection_requests.length)
      if @connection_error = err
        console.log "Backbone-Mongo: unable to create connection. Error: #{err}"
        request(new Error("Connection failed. Error: #{err}")) for request in collection_requests
      else
        request(null, @_collection) for request in collection_requests
