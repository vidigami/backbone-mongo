_ = require 'underscore'
moment = require 'moment'
Queue = require 'queue-async'

Connection = require './lib/connection'

module.exports = class BackboneSync

  constructor: (options={}) ->
    @connection = new Connection(options.database_config, options.collection, { indices: options.indices })
    @model_type = options.model

    @backbone_adapter = require(if options.manual_id then './lib/document_adapter_no_mongo_id' else './lib/document_adapter_mongo_id')
    @model_type.backbone_adapter = @backbone_adapter

    @model_type.parseRequestQuery = (req) =>
      query = if req.query then _.clone(req.query) else {}
      (query[key] = JSON.parse(value) for key, value of query) if _.isObject(query)
      return query

    @model_type.findOne = (query, callback) =>
      @connection.collection (err, collection) =>
        return callback(err) if err
        collection.findOne @backbone_adapter.attributesToDoc(query), (err, doc) =>
          if err then callback(err) else callback(null, @backbone_adapter.docToModel(doc, @model_type))

    @model_type.find = (query_args_callback) =>
      # convert the query argument to a document
      query_arguments = Array.prototype.slice.call(arguments)
      query_arguments[0] = @backbone_adapter.attributesToDoc(query_arguments[0])
      callback = query_arguments.pop()
      @connection.collection (err, collection) =>
        return callback(err) if err
        collection.find.apply(collection, query_arguments).toArray (err, docs) =>
          if err then callback?(err) else callback(null, _.map(docs, (doc) => @backbone_adapter.docToModel(doc, @model_type)))

    @model_type.findDocs = (query_args_callback) =>
      # convert the query argument to a document
      query_arguments = Array.prototype.slice.call(arguments)
      query_arguments[0] = @backbone_adapter.attributesToDoc(query_arguments[0])
      callback = query_arguments.pop()

      @connection.collection (err, collection) =>
        return callback(err) if err
        collection.find.apply(collection, query_arguments).toArray(callback)

    @model_type.findCursor = (query_args_callback) =>
      # convert the query argument to a document
      query_arguments = Array.prototype.slice.call(arguments)
      query_arguments[0] = @backbone_adapter.attributesToDoc(query_arguments[0])
      callback = query_arguments.pop()

      @connection.collection (err, collection) =>
        return callback(err) if err
        callback(null, collection.find.apply(collection, query_arguments))

    # options:
    #  @key: default 'created_at'
    #  @reverse: default false
    #  @date: default now
    #  @query: default none
    @model_type.findOneNearDate = (options, callback) =>
      key = options.key or 'created_at'
      date = options.date or moment.utc().toDate()
      query = _.clone(options.query or {})

      findForward = (callback) =>
        query[key] = {$lte: date.toISOString()}
        @model_type.findCursor query, (err, cursor) =>
          return callback(err) if err

          cursor.limit(1).sort([[key, 'desc']]).toArray (err, docs) =>
            return callback(err) if err
            return callback(null, null) unless docs.length

            callback(null, @model_type.docsToModels(docs)[0])

      findReverse = (callback) =>
        query[key] = {$gte: date.toISOString()}
        @model_type.findCursor query, (err, cursor) =>
          return callback(err) if err

          cursor.limit(1).sort([[key, 'asc']]).toArray (err, docs) =>
            return callback(err) if err
            return callback(null, null) unless docs.length

            callback(null, @model_type.docsToModels(docs)[0])

      if options.reverse
        findReverse (err, model) =>
          return callback(err) if err
          return callback(null, model) if model
          findForward callback
      else
        findForward (err, model) =>
          return callback(err) if err
          return callback(null, model) if model
          findReverse callback

    @model_type.docToModel = (doc) => @backbone_adapter.docToModel(doc, @model_type)
    @model_type.docsToModels = (docs) => _.map(docs, (doc) => @backbone_adapter.docToModel(doc, @model_type))
    @model_type.collection = (callback) => @connection.collection callback

  read: (model, options) ->
    @connection.collection (err, collection) =>
      return options.error?(err) if err

      # a collection
      if model.models
        collection.find().toArray (err, docs) =>
          if err then options.error?(err) else options.success?(_.map(docs, @backbone_adapter.docToAttributes))

      # a model
      else
        collection.findOne @backbone_adapter.modelFindQuery(model), (err, doc) =>
          if err then options.error?(err) else options.success?(@backbone_adapter.docToAttributes(doc))

  create: (model, options) ->
    @connection.collection (err, collection) =>
      return options.error?(err) if err
      return options.error?(new Error("new document has a non-empty revision")) if model.get('_rev')
      doc = @backbone_adapter.modelToDoc(model); doc._rev = 1 # start revisions
      collection.insert doc, (err, docs) =>
        return options.error?(new Error("Failed to create model")) if err or not docs or docs.length isnt 1
        options.success?(@backbone_adapter.docToAttributes(docs[0]))

  update: (model, options) ->
    return @create(model, options) unless model.get('_rev') # no revision, create - in the case we manually set an id and are saving for the first time

    @connection.collection (err, collection) =>
      return options.error?(err) if err
      json = @backbone_adapter.modelToDoc(model)
      delete json._id if @backbone_adapter.idAttribute is '_id'
      find_query = @backbone_adapter.modelFindQuery(model)
      find_query._rev = json._rev
      json._rev++ # increment revisions

      # update the record
      collection.findAndModify find_query, [[@backbone_adapter.idAttribute,'asc']], {$set: json}, {new: true}, (err, doc) =>
        return options.error?(new Error("Failed to update model")) if err or not doc
        return options.error?(new Error("Failed to update revision. Is: #{doc._rev} expecting: #{json._rev}")) if doc._rev isnt json._rev

        # look for removed attributes that need to be deleted
        expected_keys = _.keys(json); expected_keys.push('_id'); saved_keys = _.keys(doc)
        keys_to_delete = _.difference(saved_keys, expected_keys)
        return options.success?(@backbone_adapter.docToAttributes(doc)) unless keys_to_delete.length

        # delete/unset attributes and update the revision
        find_query._rev = json._rev
        json._rev++ # increment revisions
        keys = {}
        keys[key] = '' for key in keys_to_delete
        collection.findAndModify find_query, [[@backbone_adapter.idAttribute,'asc']], {$unset: keys, $set: {_rev: json._rev}}, {new: true}, (err, doc) =>
          return options.error?(new Error("Failed to update model")) if err or not doc
          return options.error?(new Error("Failed to update revision. Is: #{doc._rev} expecting: #{json._rev}")) if doc._rev isnt json._rev
          options.success?(@backbone_adapter.docToAttributes(doc))

  delete: (model, options) ->
    @connection.collection (err, collection) =>
      return options.error?(err) if err
      collection.remove @backbone_adapter.modelFindQuery(model), (err, doc) =>
        if err then options.error?(model, err, options) else options.success?(model, {}, options)

# options
#   database_config - the database config
#   collection - the collection to use for models
#   model - the model that will be used to add query functions to
module.exports = (options) ->
  sync = new BackboneSync(options)
  return (method, model, options={}) -> sync[method](model, options)