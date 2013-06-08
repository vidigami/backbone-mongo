util = require 'util'
_ = require 'underscore'

Cursor = require 'backbone-node/cursor'

module.exports = class MongoCursor extends Cursor
  ##############################################
  # Execution of the Query
  ##############################################
  toJSON: (callback, count) ->
    @connection.collection (err, collection) =>
      return callback(err) if err
      args = [@backbone_adapter.attributesToNative(@_find)]
      args._id = {$in: _.map(ids, (id) -> new ObjectID("#{id}"))} if @_cursor.$ids

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
        if @_cursor.$one
          cursor = cursor.limit(1)
        else if @_cursor.$limit
          cursor = cursor.limit(@_cursor.$limit)

        # only the count
        return cursor.count(callback) if count or @_cursor.$count

        cursor.toArray (err, docs) =>
          return callback(err) if err
          return callback(null, if docs.length then @backbone_adapter.nativeToAttributes(docs[0]) else null) if @_cursor.$one
          json = _.map(docs, (doc) => @backbone_adapter.nativeToAttributes(doc))

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

      collection.find.apply(collection, args)

  # ##############################################
  # # Intervals
  # ##############################################
  # intervalIterator: (key, callback) ->
  #   return callback(new Error("missing find time key")) unless @_find.hasOwnProperty(key)

  #   try
  #     return callback(null, new IntervalIterator({interval_type: @_cursor.$interval_type, interval_length: @_cursor.$interval_length, key: key, range_query: @_find[key], model_type: @model_type}))
  #   catch err
  #     return callback err

