EventEmitter = require('events').EventEmitter
Queue = require 'queue-async'

Query = require './query'

DEFAULT_LIMIT = 1500
PARALLEL_COUNT = 100

module.exports = class BatchUtils
  @processModels: (model_type, callback, fn, limit=DEFAULT_LIMIT, parallel_count=PARALLEL_COUNT) ->
    event_emitter = new EventEmitter()

    runBatch = (query, callback) ->
      db_query = new Query(model_type, query)
      db_query.toModels (err, models) ->
        return callback(new Error("Failed to get models")) if err or !models
        return callback(null) unless models.length
        event_emitter.emit 'progress', "Start batch length: #{models.length}"

        # closure
        doActionFn = (model) ->
          return (callback) -> fn(model, callback)

        # batch operations on each
        queue = new Queue(parallel_count)
        queue.defer doActionFn(model) for model in models
        queue.await (err) ->
          return callback(err) if err
          query.$offset += query.$limit
          runBatch(query, callback)

    query = {
      $limit: DEFAULT_LIMIT
      $offset: 0
      $sort: [['id', 'asc']]
    }
    runBatch(query, callback)
    return event_emitter