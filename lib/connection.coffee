util = require 'util'
_ = require 'underscore'
Queue = require 'queue-async'
mongodb = require 'mongodb'

Utils = require 'backbone-orm/lib/utils'

# two minutes
RETRY_COUNT = 120
RETRY_INTERVAL = 1000

connectionRetry = (retry_count, name, fn, callback) ->
  attempt_count = 0
  in_attempt = false

  call_fn = ->
    return _.delay(call_fn, RETRY_INTERVAL/2) if in_attempt # trying so try again in 1/2 the time
    in_attempt = true; attempt_count++
    console.log "***retrying #{name}. Attempt: #{attempt_count}" if attempt_count > 1
    fn (err) ->
      if err
        (in_attempt = false; return _.delay(call_fn, RETRY_INTERVAL)) if (attempt_count < retry_count) # try again

      console.log "***retried #{name} #{attempt_count} times. Success: '#{!err}'" if attempt_count > 1
      return callback.apply(null, arguments)
  call_fn()

module.exports = class Connection

  constructor: (@url, @schema={}) ->
    @collection_requests = []
    throw new Error 'Expecting a string url' unless _.isString(@url)
    url_parts = Utils.parseUrl(@url)

    # console.log "MongoDB for '#{url_parts.table}' is: '#{url_parts.host}:#{url_parts.port}/#{url_parts.database}'"
    @client = new mongodb.Db(url_parts.database, new mongodb.Server(url_parts.host, url_parts.port, {}), {auto_reconnect: true, safe: true})

    queue = Queue(1)
    queue.defer (callback) =>
      doOpen = (callback) => @client.open callback

      # socket retries
      connectionRetry(RETRY_COUNT, "MongoDB client open: #{url_parts.table}", doOpen, callback)

    queue.defer (callback) =>
      if url_parts.user
        @client.authenticate url_parts.user, url_parts.password, (err) =>
          console.log "Failed to authenticate user: #{url_parts.user} on #{url_parts.host}:#{url_parts.port}/#{url_parts.database}"if err
          callback(err)

      else
        callback()

    queue.defer (callback) =>

      doConnectToCollection = (callback) =>
        @client.collection url_parts.table, (err, collection) =>
          return callback(err) if err

          for key, field of @schema.fields
            @ensureIndex(collection, key, url_parts.table) if field.indexed

          for key, relation of @schema.relations
            if relation.type is 'belongsTo' and not relation.isVirtual() and not relation.isEmbedded()
              @ensureIndex(collection, relation.foreign_key, url_parts.table)

          # deal with waiting requests
          collection_requests = _.clone(@collection_requests); @collection_requests = []
          @_collection = collection
          request(null, @_collection) for request in collection_requests
          callback()

      # socket retries
      connectionRetry(RETRY_COUNT, "MongoDB collection connect: #{url_parts.table}", doConnectToCollection, callback)

    queue.await (err) =>
      if err
        console.log "Backbone-Mongo: connection failed: #{err}"
        @failed_connection = true
        collection_requests = _.clone(@collection_requests); @collection_requests = []
        request(new Error("Connection failed")) for request in collection_requests

  destroy: ->
    return unless @client # already closed
    collection_requests = _.clone(@collection_requests); @collection_requests = []
    request(new Error("Client closed")) for request in collection_requests
    @_collection = null
    @client.close(); @client = null

  collection: (callback) ->
    return callback(new Error("Client closed")) unless @client
    return callback(new Error("Connection failed")) if @failed_connection
    return callback(null, @_collection) if @_collection
    @collection_requests.push(callback)


  ensureIndex: (collection, field_name, table_name) =>
    index_info = {}; index_info[field_name] = 1
    collection.ensureIndex index_info, {background: true}, (err) =>
      return new Error("MongoBackbone: Failed to indexed '#{field_name}' on #{table_name}. Reason: #{err}") if err
      console.log("MongoBackbone: Successfully indexed '#{field_name}' on #{table_name}")
