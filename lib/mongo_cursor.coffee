util = require 'util'
_ = require 'underscore'
Queue = require 'queue-async'

Cursor = require 'backbone-orm/lib/cursor'

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

module.exports = class MongoCursor extends Cursor
  ##############################################
  # Execution of the Query
  ##############################################
  toJSON: (callback, options) ->
    count = (@_cursor.$count or (options and options.$count))
    exists = @_cursor.$exists or (options and options.$exists)

    @connection.collection (err, collection) =>
      return callback(err) if err
      @_buildFindQuery (err, find_query) =>
        args = [find_query]

        if id = args[0].id
          delete args[0].id
          if id.$in
            args[0][@backbone_adapter.id_attribute] = {$in: _.map(id.$in, @backbone_adapter.findId)}
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

          # only the count
          return cursor.count(callback) if count
          if exists # exists
            return cursor.count (err, count) -> callback(err, !!count)

          cursor.toArray (err, docs) =>

            return callback(err) if err
            json = _.map(docs, (doc) => @backbone_adapter.nativeToAttributes(doc))

            queue = new Queue(1)

            # TODO: $select/$values = 'relation.field'
            if @_cursor.$include
              queue.defer (callback) =>
                load_queue = new Queue(1)

                $include_keys = if _.isArray(@_cursor.$include) then @_cursor.$include else [@_cursor.$include]
                for key in $include_keys
                  continue if @model_type.relationIsEmbedded(key)
                  return callback(new Error "Included relation '#{key}' is not a relation") unless relation = @model_type.relation(key)

                  # Load the included models
                  for model_json in json
                    do (key, model_json) => load_queue.defer (callback) =>
                      relation.cursor(model_json, key).toJSON (err, related_json) ->
                        return calback(err) if err
                        # console.log "\nmodel_json: #{util.inspect(model_json)}\nrelated_json: #{util.inspect(related_json)}"
                        delete model_json[relation.foriegn_key]
                        model_json[key] = related_json
                        callback()

                load_queue.await callback

            queue.defer (callback) =>

              # TODO: OPTIMIZE TO REMOVE 'id' and '_rev' if needed
              if @_cursor.$values
                $values = if @_cursor.$white_list then _.intersection(@_cursor.$values, @_cursor.$white_list) else @_cursor.$values
                if @_cursor.$values.length is 1
                  key = @_cursor.$values[0]
                  json = if $values.length then ((if item.hasOwnProperty(key) then item[key] else null) for item in json) else _.map(json, -> null)
                else
                  json = (((item[key] for key in $values when item.hasOwnProperty(key))) for item in json)
              else if @_cursor.$select
                $select = if @_cursor.$white_list then _.intersection(@_cursor.$select, @_cursor.$white_list) else @_cursor.$select
                json = _.map(json, (item) => _.pick(item, $select))

              else if @_cursor.$white_list
                json = _.map(json, (item) => _.pick(item, @_cursor.$white_list))
              callback()

            queue.await (err) =>
              return callback(err) if err
              return callback(null, if json.length then json[0] else null) if @_cursor.$one

              if @_cursor.$page or @_cursor.$page is ''
                cursor.count (err, count) =>
                  return callback(err) if err
                  json =
                    offset: @_cursor.$offset
                    total_rows: count
                    rows: json
                  callback(null, json)
              else
                callback(null, json)

        collection.find.apply(collection, args)

  _buildFindQuery: (callback) ->
    queue = new Queue()

    find_query = {}
    for key, value of @_find
      (find_query[key] = value; continue) if (key.indexOf('.') < 0)

      [relation_key, value_key] = key.split('.')
      (find_query[key] = value; continue) if @model_type.relationIsEmbedded(relation_key) # embedded so a nested query is possible in mongo

      # do a join or lookup
      do (relation_key, value_key, value) => queue.defer (callback) =>
        relation = @model_type.relation(relation_key)
        if not relation.join_table and (value_key is 'id')
          find_query["#{relation_key}_#{value_key}"] = value
          callback()

        # TODO: optimize with a one-step join?
        else if relation.join_table or (relation.type is 'belongsTo')
          (related_query = {$values: 'id'})[value_key] = value
          relation.reverse_relation.model_type.cursor(related_query).toJSON (err, related_ids) =>
            return callback(err) if err
            if relation.join_table
              (join_query = {})[relation.foreign_key] = {$in: related_ids}
              join_query.$values = relation.reverse_relation.foriegn_key
              relation.join_table.cursor(join_query).toJSON (err, model_ids) =>
                return callback(err) if err
                find_query.id = {$in: model_ids}
                callback()
            else
              find_query[relation.foreign_key] = {$in: related_ids}
              callback()

        # foreign key is on the model
        else
          (related_query = {})[value_key] = value
          related_query.$values = relation.foreign_key
          relation.reverse_relation.model_type.cursor(related_query).toJSON (err, model_ids) =>
            return callback(err) if err
            find_query.id = {$in: model_ids}
            callback()

    queue.await (err) =>
      # console.log "find_query: #{util.inspect(find_query)}"
      callback(err, find_query)
