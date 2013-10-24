util = require 'util'
URL = require 'url'
_ = require 'underscore'
Queue = require 'queue-async'

ConnectionPool = require 'backbone-orm/lib/connection_pool'

MongoClient = require('mongodb').MongoClient
ReadPreference = require('mongodb').ReadPreference

RETRY_INTERVAL = 1000
RETRY_COUNT = 2*60 # retry every second for two minutes
DEFAULT_POOL_SIZE = 100

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
    url_parts = URL.parse(@url)
    collection_name = url_parts.pathname.split('/')[1]
    delete url_parts.search
    url_parts.query or= {}
    url_parts.query.maxPoolSize = DEFAULT_POOL_SIZE unless url_parts.query.hasOwnProperty('maxPoolSize')
    url_parts.query.autoReconnect = true unless url_parts.query.hasOwnProperty('autoReconnect')
    @url = URL.format(url_parts)

    queue = Queue(1)

    # use pooled connection or create new
    queue.defer (callback) =>
      return callback() if @db = ConnectionPool.get(@url)
      MongoClient.connect @url, DEFAULT_CLIENT_OPTIONS, (err, db) =>
        return callback(err) if err
        ConnectionPool.set(@url, @db = db) # share the connection
        callback()

    # connect to the collection
    queue.defer (callback) =>
      @db.collection collection_name, (err, collection) =>
        return callback(err) if err

        # ensure indexes
        @ensureIndex(collection, key, collection_name) for key, field of @schema.fields when field.indexed
        for key, relation of @schema.relations
          @ensureIndex(collection, relation.foreign_key, collection_name) if relation.type is 'belongsTo' and not relation.isVirtual() and not relation.isEmbedded()

        # handle waiting requests
        collection_requests = _.clone(@collection_requests); @collection_requests = []
        @_collection = collection
        request(null, @_collection) for request in collection_requests
        callback()

    # process awaiting requests
    queue.await (err) =>
      if err
        console.log "Backbone-Mongo: connection to failed: #{err}"
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
