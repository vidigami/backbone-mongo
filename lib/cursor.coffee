util = require 'util'
_ = require 'underscore'
JSONUtils = require './json_utils'

module.exports = class Cursor
  constructor: (@backbone_sync, query) ->
    @backbone_adapter = @backbone_sync.backbone_adapter
    @model_type = @backbone_sync.model_type

    if _.isObject(query)
      @_find = @_parseFindQuery(query)
      @_cursor = @_parseCursorQuery(query)
    else
      @_find = {id: query}
      @_cursor = {$one: true}

  offset: (offset) -> @_cursor.$offset = offset; return @
  limit: (limit) -> @_cursor.$limit = limit; return @

  whiteList: (keys) ->
    keys = [keys] unless _.isArray(keys)
    @_cursor.$white_list = if @_cursor.$white_list then _.intersection(@_cursor.$white_list, keys) else keys
    return @

  select: (keys) ->
    keys = [keys] unless _.isArray(keys)
    @_cursor.$select = if @_cursor.$select then _.intersection(@_cursor.$select, keys) else keys
    return @

  values: (keys) ->
    keys = [keys] unless _.isArray(keys)
    @_cursor.$values = if @_cursor.$values then _.intersection(@_cursor.$values, keys) else keys
    return @

  ##############################################
  # Execution of the Query
  ##############################################

  toJSON: (callback) ->
    @_buildCursor (err, cursor) =>
      return callback(err) if err
      return cursor.count(callback) if @_cursor.$count

      cursor.toArray (err, docs) =>
        return callback(err) if err
        return callback(null, if docs.length then @backbone_adapter.docToAttributes(docs[0]) else null) if @_cursor.$one
        json = _.map(docs, (doc) => @backbone_adapter.docToAttributes(doc))

        # TODO: OPTIMIZE TO REMOVE 'id' and '_rev' if needed
        if @_cursor.$values
          $values = if @_cursor.$white_list then _.intersection(@_cursor.$values, @_cursor.$white_list) else @_cursor.$values
          json = (((item[key] for key in $values when item.hasOwnProperty(key))) for item in json)
        else if @_cursor.$select
          $select = if @_cursor.$white_list then _.intersection(@_cursor.$select, @_cursor.$white_list) else @_cursor.$select
          json = _.map(json, (item) => _.pick(item, $select))
        else if @_cursor.$white_list
          json = _.map(json, (item) => _.pick(item, @_cursor.$white_list))
        callback(null, json)
    return # terminating

  toModels: (callback) ->
    @toJSON (err, json) =>
      return callback(err) if err
      return callback(new Error "Cannot call toModels on cursor with values. Values: #{util.inspect(@_cursor.$values)}") if @_cursor.$values
      return callback(null, if json then (new @model_type(@model_type::parse(json))) else null) if @_cursor.$one
      callback(null, (new @model_type(@model_type::parse(attributes)) for attributes in json))
    return # terminating

  value: (callback) ->
    if @_cursor.$one
      @toModels(callback)
    else if @_cursor.$count
      @_buildCursor (err, cursor) =>
        return callback(err) if err
        cursor.count(callback)
     else
       callback(new Error "Cursor does not refer to a single value")
    return # terminating

  count: (callback) ->
    @_buildCursor (err, cursor) =>
      return callback(err) if err
      cursor.count(callback)
    return # terminating

  ##############################################
  # Intervals
  ##############################################
  intervalIterator: (key, callback) ->
    return callback(new Error("missing find time key")) unless @_find.hasOwnProperty(key)

    try
      return callback(null, new IntervalIterator({interval_type: @_cursor.$interval_type, interval_length: @_cursor.$interval_length, key: key, range_query: @_find[key], model_type: @model_type}))
    catch err
      return callback err

  ##############################################
  # Query Parsing
  ##############################################
  _parseFindQuery: (raw_query) ->
    find = {}
    for key, value of raw_query
      if key[0] isnt '$'
        find[key] = JSONUtils.JSONToValue(value)
      else if key is '$ids'
        ids = @_parseArray(value)
        if ids
          find._id = {$in: _.map(ids, (id) -> new ObjectID("#{id}"))}
        else
          console.log("Failed to parse $ids: #{value}")

    return find

  _parseCursorQuery: (raw_query) ->
    cursor = {}
    for key, value of raw_query
      continue if key[0] isnt '$' or key is '$ids'

      switch key
        when '$limit' then cursor.$limit = parseInt(value, 10)
        when '$offset' then cursor.$offset = parseInt(value, 10)
        when '$count' then cursor.$count = true
        when '$select', '$values'
          if _.isString(value) and value.length and value[0] is '['
            cursor[key] = @_parseArray(value)
            console.log("Failed to parse $select: #{value}") unless cursor.$select
          else
            cursor[key] = JSONUtils.JSONToValue(value)
            cursor[key] = [cursor[key]] unless _.isArray(cursor[key])

        # parse even if you don't recognize it so others can use it
        else
          cursor[key] = JSONUtils.JSONToValue(value)

    return cursor

  _parseArray: (value) ->
    try (array = JSON.parse(value)) catch e
    return if array and _.isArray(array) then array else undefined

  _buildCursor: (callback) ->
    # build the cursor
    @backbone_sync._collection (err, collection) =>
      return callback(err) if err
      args = [@backbone_adapter.attributesToDoc(@_find)]

      # only select specific fields
      if @_cursor.$values
        $fields = if @_cursor.$white_list then _.intersection(@_cursor.$values, @_cursor.$white_list) else @_cursor.$values
      else if @_cursor.$select
        $fields = if @_cursor.$white_list then _.intersection(@_cursor.$select, @_cursor.$white_list) else @_cursor.$select
      else if @_cursor.$white_list
        $fields = @_cursor.$white_list
      args.push($fields) if $fields

      # add callback and call
      args.push (err, cursor) =>
        return callback(err) if err
        cursor = cursor.sort(@_cursor.$sort) if @_cursor.$sort
        cursor = cursor.skip(@_cursor.$offset) if @_cursor.$offset
        cursor = cursor.limit(@_cursor.$limit) if @_cursor.$limit
        callback(null, cursor)
      collection.find.apply(collection, args)


  # toResponse: (results) ->
  #   if @_cursor.$count
  #     return 0 unless results
  #     return results if _.isNumber(results)
  #     return results.length if _.isArray(results)
  #     return 1

  #   if @_cursor.$limit is 1
  #     if @_cursor.$select
  #       return _.map(@_cursor.$select, (key) -> results[key]) if @_cursor.$select.length > 1
  #       return results[@_cursor.$select[0]] if @_cursor.$select[0]
  #   else
  #     if @_cursor.$select
  #       return _.map(results, (value) => _.map(@_cursor.$select, (key) -> value[key])) if @_cursor.$select.length > 1
  #       return _.pluck(results, @_cursor.$select[0]) if @_cursor.$select[0]
  #   return results

  # @_parseQueries: (query) ->
  #   unless _.isObject(query)
  #     single_item = true
  #     query = {id: query}

  #   queries = {find: {}, cursor: {}}
  #   for key, value of query
  #     if key[0] is '$'
  #       if key is '$select' or key is '$values'
  #         queries.cursor[key] = if _.isArray(value) then value else [value]
  #       else
  #         queries.cursor[key] = value
  #     else
  #       queries.find[key] = value
  #   return queries