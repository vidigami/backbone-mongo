###
  backbone-mongo.js 0.5.6
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-mongo
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

util = require 'util'
_ = require 'underscore'
Queue = require 'backbone-orm/lib/queue'

MemoryCursor = require 'backbone-orm/lib/memory/cursor'

ARRAY_QUERIES = ['$or', '$nor', '$and']

_sortArgsToMongo = (args, backbone_adapter) ->
  args = if _.isArray(args) then args else [args]
  sorters = {}
  for sort_part in args
    key = sort_part.trim(); value = 1
    (key = key.substring(1).trim(); value = -1) if key[0] is '-'
    sorters[if key is 'id' then backbone_adapter.id_attribute else key] = value
  return sorters

_adaptIds = (query, backbone_adapter) ->
  if _.isString(query)
    try return backbone_adapter.findId(query) catch e then return query
  else if _.isObject(query)
    result = {}
    result[key] = _adaptIds(value, backbone_adapter) for key, value of query
    return result
  else if _.isArray(query)
    return (_adaptIds(value, backbone_adapter) for value in query)
  return query

module.exports = class MongoCursor extends MemoryCursor
  ##############################################
  # Execution of the Query
  ##############################################
  queryToJSON: (callback) ->
    return callback(null, if @hasCursorQuery('$one') then null else []) if @hasCursorQuery('$zero')
    exists = @hasCursorQuery('$exists')

    @buildFindQuery (err, find_query) =>
      return callback(err) if err

      args = [find_query]

      if id = args[0].id
        delete args[0].id
        args[0][@backbone_adapter.id_attribute] = _adaptIds(id, @backbone_adapter)
      if @_cursor.$ids
        args[0][@backbone_adapter.id_attribute] = {$in: _.map(@_cursor.$ids, @backbone_adapter.findId)}
      args[0][key] = _adaptIds(@_cursor[key], @backbone_adapter) for key in ARRAY_QUERIES when @_cursor[key]

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
        if @_cursor.$sort
          @_cursor.$sort = [@_cursor.$sort] unless _.isArray(@_cursor.$sort)
          cursor = cursor.sort(_sortArgsToMongo(@_cursor.$sort, @backbone_adapter))

        cursor = cursor.skip(@_cursor.$offset) if @_cursor.$offset

        if @_cursor.$one or exists
          cursor = cursor.limit(1)
        else if @_cursor.$limit
          cursor = cursor.limit(@_cursor.$limit)

        return cursor.count(callback) if @hasCursorQuery('$count') # only the count
        return cursor.count((err, count) -> callback(err, !!count)) if exists # only if exists

        cursor.toArray (err, docs) =>
          return callback(err) if err
          json = _.map(docs, (doc) => @backbone_adapter.nativeToAttributes(doc))

          @fetchIncludes json, (err) =>
            return callback(err) if err
            if @hasCursorQuery('$page')
              cursor.count (err, count) =>
                return callback(err) if err
                callback(null, {
                  offset: @_cursor.$offset or 0
                  total_rows: count
                  rows: @selectResults(json)
                })
            else
              callback(null, @selectResults(json))

      @connection.collection (err, collection) =>
        return callback(err) if err
        collection.find.apply(collection, args)
