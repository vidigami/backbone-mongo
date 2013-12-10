###
  backbone-mongo.js 0.5.0
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-mongo
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

util = require 'util'
_ = require 'underscore'
Queue = require 'backbone-orm/lib/queue'

MemoryCursor = require 'backbone-orm/lib/memory/cursor'

_sortArgsToMongo = (args) ->
  args = if _.isArray(args) then args else [args]
  sorters = {}
  for sort_part in args
    sort_part = sort_part.trim()
    if sort_part[0] is '-'
      key = sort_part.substring(1).trim()
      sorters[key] = -1
    else
      sorters[sort_part] = 1
  return sorters

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
        if id.$in
          args[0][@backbone_adapter.id_attribute] = {$in: _.map(id.$in, @backbone_adapter.findId)}
        if id.$nin
          args[0][@backbone_adapter.id_attribute] = {$nin: _.map(id.$nin, @backbone_adapter.findId)}
        else if id.$ne
          args[0][@backbone_adapter.id_attribute] = {$ne: @backbone_adapter.findId(id.$ne)}
        else
          args[0][@backbone_adapter.id_attribute] = @backbone_adapter.findId(id)
      args[0][@backbone_adapter.id_attribute] = {$in: _.map(@_cursor.$ids, @backbone_adapter.findId)} if @_cursor.$ids

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
          cursor = cursor.sort(_sortArgsToMongo(@_cursor.$sort))

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
            return callback(null, if json.length then json[0] else null) if @_cursor.$one

            json = @selectResults(json)
            if @hasCursorQuery('$page')
              cursor.count (err, count) =>
                return callback(err) if err
                callback(null, {
                  offset: @_cursor.$offset or 0
                  total_rows: count
                  rows: json
                })
            else
              callback(null, json)

      @connection.collection (err, collection) =>
        return callback(err) if err
        collection.find.apply(collection, args)
