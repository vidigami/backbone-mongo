util = require 'util'
_ = require 'underscore'
Queue = require 'queue-async'
MongoClient = require('mongodb').MongoClient
ReadPreference = require('mongodb').ReadPreference

Utils = require 'backbone-orm/lib/utils'

RETRY_INTERVAL = 1000
RETRY_COUNT = 2*60 # retry every second for two minutes

DEFAULT_CLIENT_OPTIONS =
  retryMiliSeconds: RETRY_INTERVAL
  numberOfRetries: RETRY_COUNT
  journal: false
  readPreference: ReadPreference.NEAREST

module.exports = class Connection

  constructor: (@url, @schema={}) ->
    throw new Error 'Expecting a string url' unless _.isString(@url)

    @collection_requests = []
    @db = null
    url_parts = Utils.parseUrl(@url)
    @table = url_parts.table

    queue = Queue(1)
    queue.defer (callback) => MongoClient.connect @url, DEFAULT_CLIENT_OPTIONS, (err, db) => callback(err, @db = db)
    queue.defer (callback) =>
      @db.collection @table, (err, collection) =>
        return callback(err) if err

        for key, field of @schema.fields
          @ensureIndex(collection, key, @table) if field.indexed

        for key, relation of @schema.relations
          if relation.type is 'belongsTo' and not relation.isVirtual() and not relation.isEmbedded()
            @ensureIndex(collection, relation.foreign_key, @table)

        # deal with waiting requests
        collection_requests = _.clone(@collection_requests); @collection_requests = []
        @_collection = collection
        request(null, @_collection) for request in collection_requests
        callback()

    queue.await (err) =>
      if err
        console.log "Backbone-Mongo: connection failed: #{err}"
        @failed_connection = true
        collection_requests = _.clone(@collection_requests); @collection_requests = []
        request(new Error('Connection failed')) for request in collection_requests

  destroy: ->
    return unless @db # already closed
    collection_requests = _.clone(@collection_requests); @collection_requests = []
    request(new Error('Client closed')) for request in collection_requests
    @_collection = null
    @db.close(); @db = null

  collection: (callback) ->
    return callback(new Error('Connection failed')) if @failed_connection
    return callback(null, @_collection) if @_collection
    @collection_requests.push(callback)

  ensureIndex: (collection, field_name, table_name) =>
    index_info = {}; index_info[field_name] = 1
    collection.ensureIndex index_info, {background: true}, (err) =>
      return new Error("MongoBackbone: Failed to indexed '#{field_name}' on #{table_name}. Reason: #{err}") if err
      console.log("MongoBackbone: Successfully indexed '#{field_name}' on #{table_name}")
