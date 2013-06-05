EventEmitter = require('events').EventEmitter
Queue = require 'queue-async'

Query = require './query'

module.exports = class BatchUtils
  @processModels: (model_type, options={}, callback, per_model_fn) ->
    event_emitter = new EventEmitter()

    parallelism = options.parallelism or 1
    total_processed = 0
    is_done = false

    query = {$offset: 0, $sort: [['id', 'asc']]}
    (query[key] = value if key[0] is '$') for key, value of options
    limit = query.$limit or -1 # limit is for total number of items
    query.$limit = options.batch_size or Math.max(parallelism, 1) # batch size is per iteration

    runBatch = (query, callback) ->

      db_query = new Query(model_type, query)
      db_query.toModels (err, models) ->
        return callback(new Error("Failed to get models")) if err or !models
        (is_done = true; return callback()) unless models.length

        # batch operations on each
        queue = new Queue(parallelism)

        for model in models
          (is_done = true; return callback()) if limit >= 0 and (total_processed >= limit) # done
          total_processed++
          do (model) -> queue.defer (callback) -> per_model_fn(model, callback)

        queue.await (err) ->
          return callback(err) if err
          return callback(null, total_processed) if is_done
          query.$offset += total_processed
          runBatch(query, callback)

    runBatch(query, callback)
    return event_emitter