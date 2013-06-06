_ = require 'underscore'
moment = require 'moment'

INTERVAL_TYPES = ['seconds', 'minutes', 'hours', 'days', 'weeks', 'months', 'years']

class IntervalIterator
  constructor: (options) ->
    @[key] = value for key, value of options

    throw new Error("missing model_type") unless @model_type
    throw new Error("missing interval_type") unless @interval_type
    throw new Error("missing range_query") unless @range_query
    throw new Error("interval_type is not recognized: #{@interval_type}, #{_.contains(INTERVAL_TYPES, @interval_type)}") unless _.contains(INTERVAL_TYPES, @interval_type)

    # start
    start = @range_query.$gte if @range_query.$gte
    start = moment.utc().toDate() unless start
    @start_ms = start.getTime()

    # end
    end = @range_query.$lte if @range_query.$lte
    end = moment.utc().toDate() unless end
    @end_ms = end.getTime()

    # interval step
    @interval_length_ms = moment.duration((if _.isUndefined(@interval_length) then 1 else @interval_length), @interval_type).asMilliseconds()
    throw Error("interval_length_ms is invalid: #{@interval_length}") unless @interval_length_ms

  contains: (date) ->
    time_ms = if date.getTime then date.getTime() else date
    return time_ms >= @start_ms and time_ms <= @end_ms

  toIndex: (date) ->
    return -1 unless @contains(date)
    time_ms = if date.getTime then date.getTime() else date
    return Math.floor((time_ms - @start_ms) / @interval_length_ms)

  startIndex: -> return 0
  endIndex: ->
    return Math.floor((@end_ms - @start_ms) / @interval_length_ms)

  findStartCap: (query, callback) ->
    start = @range_query.$gte if @range_query.$gte
    start = moment.utc().toDate() unless start
    @model_type.findOneNearDate {key: @key, date: start, query: query, reverse: true}, callback

  findEndCap: (query, callback) ->
    end = @range_query.$lte if @range_query.$lte
    end = moment.utc().toDate() unless end
    @model_type.findOneNearDate {key: @key, date: end, query: query}, callback

module.exports = class Query

  constructor: (@model_type, raw_query) ->
    @backbone_adapter = @model_type.backbone_adapter
    throw Error("model type missing backbone adapter") unless @backbone_adapter

    @find = @parseFindQuery(raw_query)
    _.extend(@, @parseCursorQuery(raw_query))

  hasSingleSelect: (key) -> return @$select and @$select.length is 1 and @$select[0] is key

  ##############################################
  # Execution of the Query
  ##############################################

  toJSON: (query_args_callback) ->
    find_args = Array.prototype.slice.call(arguments)
    callback = find_args.pop()
    find_args.push (err, cursor) =>
      return callback(err) if err
      @cursorToModels cursor, (err, models) =>
        return callback(err) if err
        callback(null, @modelsToJSON(models))

    @startCursor.apply(@, find_args)

  toModels: (query_args_callback) ->
    find_args = Array.prototype.slice.call(arguments)
    callback = find_args.pop()
    find_args.push (err, cursor) =>
      return callback(err) if err
      @cursorToModels(cursor, callback)

    @startCursor.apply(@, find_args)

  startCursor: (query_args_callback) ->
    find_args = Array.prototype.slice.call(arguments)
    callback = find_args.pop()
    find_args.unshift(@backbone_adapter.attributesToDoc(@find))
    find_args.push (err, cursor) =>
      return callback(err) if err
      cursor = cursor.sort(@$sort) if @$sort
      cursor = cursor.skip(@$offset) if @$offset
      cursor = cursor.limit(@$limit) if @$limit
      callback(null, cursor)

    # build the cursor
    @model_type.findCursor.apply(null, find_args)

  cursorToModels: (cursor, callback) ->
    # resolve the cursor
    return cursor.count(callback) if @$count
    # return cursor.size(callback) if @cursor.size # not supported by native driver
    cursor.toArray (err, docs) =>
      return callback(err) if err
      callback(null, @model_type.docsToModels(docs))

  modelsToJSON: (models) ->
    return models if _.isNumber(models) or not models
    if @$limit is 1
      if _.isArray(models)
        @toResponse(if models.length then models[0].toJSON() else {})
      else
        @toResponse(models.toJSON())
    else
      @toResponse(_.map(models, (model) -> model.toJSON()))

  toResponse: (results) ->
    if @$count
      return 0 unless results
      return results if _.isNumber(results)
      return results.length if _.isArray(results)
      return 1

    if @$limit is 1
      if @$select
        return _.map(@$select, (key) -> results[key]) if @$select.length > 1
        return results[@$select[0]] if @$select[0]
    else
      if @$select
        return _.map(results, (value) => _.map(@$select, (key) -> value[key])) if @$select.length > 1
        return _.pluck(results, @$select[0]) if @$select[0]
    return results

  ##############################################
  # Intervals
  ##############################################
  intervalIterator: (key, callback) ->
    return callback(new Error("missing find time key")) unless @find.hasOwnProperty(key)

    try
      return callback(null, new IntervalIterator({interval_type: @$interval_type, interval_length: @$interval_length, key: key, range_query: @find[key], model_type: @model_type}))
    catch err
      return callback err

  ##############################################
  # Query Parsing
  ##############################################
  parseFindQuery: (raw_query) ->
    find = {}
    for key, value of raw_query
      if key[0] isnt '$'
        find[key] = @parseValue(value)
      else if key is '$ids'
        ids = @parseArray(value)
        if ids
          find._id = {$in: _.map(ids, (id) -> new ObjectID("#{id}"))}
        else
          console.log("Failed to parse $ids: #{value}")

    return find

  parseCursorQuery: (raw_query) ->
    cursor = {}
    for key, value of raw_query
      continue if key[0] isnt '$' or key is '$ids'

      switch key
        when '$limit' then cursor.$limit = parseInt(value, 10)
        when '$offset' then cursor.$offset = parseInt(value, 10)
        when '$count' then cursor.$count = true
        # when '$size' then cursor.$size = true # not supported by native driver
        when '$select'
          if _.isString(value) and value.length and value[0] is '['
            cursor.$select = @parseArray(value)
            console.log("Failed to parse $select: #{value}") unless cursor.$select
          else
            cursor.$select = @parseValue(value)
            cursor.$select = [cursor.$select] unless _.isArray(cursor.$select)

        # parse even if you don't recognize it so others can use it
        else
          cursor[key] = @parseValue(value)

    return cursor

  parseValue: (value) ->
    if _.isString(value) and value.length and value[value.length-1] is 'Z'
      date = moment(value)
      return date.toDate() if date and date.isValid()
    try (value = JSON.parse(value)) catch e
    if _.isObject(value)
      value[key] = @parseValue(value[key]) for key of value
    return value

  parseArray: (value) ->
    try (array = JSON.parse(value)) catch e
    return if array and _.isArray(array) then array else undefined