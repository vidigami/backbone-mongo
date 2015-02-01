###
  backbone-sql.js 0.5.7
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-sql
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

{_, Queue} = require 'backbone-orm'

module.exports = class DatabaseTools

  constructor: (@sync, options={}) ->
    @schema = @sync.schema

  resetSchema: (options, callback) ->
    [callback, options] = [options, {}] if arguments.length is 1
    return callback() if @resetting
    @resetting = true

    queue = new Queue()

    queue.defer (callback) => @dropTable(options, callback)
    queue.defer (callback) =>
      join_queue = new Queue(1)
      for join_table in @schema.joinTables()
        do (join_table) => join_queue.defer (callback) => join_table.db().resetSchema(callback)
      join_queue.await callback

    queue.await (err) =>
      @resetting = false; return callback(err) if err
      @ensureSchema(options, callback)

  # Ensure that the schema is reflected correctly in the database
  # Will create a table and index columns
  ensureSchema: (options, callback) =>
    [callback, options] = [options, {}] if arguments.length is 1

    return callback() if @ensuring
    @ensuring = true

    queue = new Queue(1)
    queue.defer (callback) => @createOrUpdateTable(options, callback)
    queue.defer (callback) =>
      join_queue = new Queue(1)
      for join_table in @schema.joinTables()
        do (join_table) => join_queue.defer (callback) => join_table.db().ensureSchema(callback)
      join_queue.await callback

    queue.await (err) => @ensuring = false; callback(err)

  createOrUpdateTable: (options, callback) =>
    @sync.collection (err, collection) =>
      return callback(err) if err
      console.log "Ensuring table: #{collection.collectionName} with fields: '#{_.keys(@schema.fields).join(', ')}' and relations: '#{_.keys(@schema.relations).join(', ')}'" if options.verbose

      # ensure indexes asyncronously
      queue = new Queue()
      queue.defer (callback) => @ensureIndex(@sync.backbone_adapter.id_attribute, options, callback)

      for key, field of @schema.fields when field.indexed
        do (key) => queue.defer (callback) => @ensureIndex(key, options, callback)

      for key, relation of @schema.relations when (relation.type is 'belongsTo') and not relation.isVirtual() and not relation.isEmbedded()
        do (key, relation) => queue.defer (callback) => @ensureIndex(relation.foreign_key, options, callback)

      queue.await callback
    return

  dropTable: (options, callback) =>
    [callback, options] = [options, {}] if arguments.length is 1

    @sync.collection (err, collection) =>
      return callback(err) if err
      collection.remove {}, (err) =>
        if err
          console.log "Failed to reset collection: #{collection.collectionName}. Error: #{err}" if options.verbose
        else
          console.log "Reset collection: #{collection.collectionName}" if options.verbose
        callback(err)

  ensureIndex: (field_name, options, callback) =>
    [callback, options] = [options, {}] if arguments.length is 2

    index_info = {}; index_info[field_name] = 1

    @sync.collection (err, collection) =>
      return callback(err) if err
      collection.ensureIndex index_info, {background: true}, (err) =>
        return callback(new Error("MongoBackbone: Failed to indexed '#{field_name}' on #{collection.collectionName}. Reason: #{err}")) if err
        console.log("MongoBackbone: Successfully indexed '#{field_name}' on #{collection.collectionName}") if options.verbose
        callback()
