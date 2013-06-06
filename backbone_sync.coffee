util = require 'util'
_ = require 'underscore'
moment = require 'moment'
Queue = require 'queue-async'

Connection = require './lib/connection'

_extractQueryArgs = (args, query_optional) ->
  return [[{}], args[0]] if query_optional and args.length is 1
  query_args = Array.prototype.slice.call(args)
  query_args[0] = @backbone_adapter.attributesToDoc(query_args[0])
  return [query_args, query_args.pop()]

CLASS_METHODS = [
  'count', 'destroy', 'findOne', 'find', 'findDocs', 'findCursor', 'findOneNearDate'
  'parseRequestQuery'
  'docToModel', 'docsToModels', 'collection'
  'initialize'
]

module.exports = class BackboneSync

  constructor: (@model_type) ->

    # publish methods on the model class
    @model_type[fn] = _.bind(@[fn], @) for fn in CLASS_METHODS

    # configure the adapter for converting between types and ids
    schema = _.result(@model_type, 'schema') or {}
    for field_name, field_info of schema
      continue if (field_name isnt 'id') or not _.isArray(field_info)
      for info in field_info
        if info.manual_id
          @backbone_adapter = require './lib/document_adapter_no_mongo_id'
          break
      break
    @backbone_adapter = require './lib/document_adapter_mongo_id' if not @backbone_adapter # default is using the mongodb adapter
    @model_type.backbone_adapter = @backbone_adapter

  initialize: (model) ->
    return if @connection
    model or= (new @model_type()) # dummy model to retrieve the url on collection functions
    return callback(new Error "Missing url for model") unless url = _.result(model, 'url')

    schema = _.result(@model_type, 'schema') or {}
    @connection = new Connection(url, schema)

  ###################################
  # Classic Backbone Sync
  ###################################
  read: (model, options) ->
    @_collection model, (err, collection) =>
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
    @_collection model, (err, collection) =>
      return options.error?(err) if err
      return options.error?(new Error("new document has a non-empty revision")) if model.get('_rev')
      doc = @backbone_adapter.modelToDoc(model); doc._rev = 1 # start revisions
      collection.insert doc, (err, docs) =>
        return options.error?(new Error("Failed to create model")) if err or not docs or docs.length isnt 1
        options.success?(@backbone_adapter.docToAttributes(docs[0]))

  update: (model, options) ->
    return @create(model, options) unless model.get('_rev') # no revision, create - in the case we manually set an id and are saving for the first time

    @_collection model, (err, collection) =>
      return options.error?(err) if err
      json = @backbone_adapter.modelToDoc(model)
      delete json._id if @backbone_adapter.idAttribute is '_id'
      find_query = @backbone_adapter.modelFindQuery(model)
      find_query._rev = json._rev
      json._rev++ # increment revisions

      # update the record
      collection.findAndModify find_query, [[@backbone_adapter.idAttribute,'asc']], {$set: json}, {new: true}, (err, doc) =>
        return options.error?(new Error("Failed to update model. #{err}")) if err or not doc
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
          return options.error?(new Error("Failed to update model. #{err}")) if err or not doc
          return options.error?(new Error("Failed to update revision. Is: #{doc._rev} expecting: #{json._rev}")) if doc._rev isnt json._rev
          options.success?(@backbone_adapter.docToAttributes(doc))

  delete: (model, options) ->
    @_collection model, (err, collection) =>
      return options.error?(err) if err
      collection.remove @backbone_adapter.modelFindQuery(model), (err, doc) =>
        if err then options.error?(model, err, options) else options.success?(model, {}, options)

  ###################################
  # Collection Extensions
  ###################################
  count: (optional_query, callback) ->
    [query_args, callback] = _extractQueryArgs.call(this, arguments, true)

    @_collection (err, collection) =>
      return callback(err) if err
      query_args.push (err, cursor) =>
        return callback(err) if err
        cursor.count callback
      collection.find.apply(collection, query_args)

  destroy: (optional_query, callback) ->
    [query_args, callback] = _extractQueryArgs.call(this, arguments, true)
    query_args.push(callback)

    @_collection (err, collection) =>
      return callback(err) if err
      collection.remove.apply(collection, query_args)

  findOne: (query, callback) ->
    @_collection (err, collection) =>
      return callback(err) if err
      collection.findOne @backbone_adapter.attributesToDoc(query), (err, doc) =>
        if err then callback(err) else callback(null, @backbone_adapter.docToModel(doc, @model_type))

  find: (query_args_callback) ->
    [query_args, callback] = _extractQueryArgs.call(this, arguments)

    @_collection (err, collection) =>
      return callback(err) if err
      collection.find.apply(collection, query_args).toArray (err, docs) =>
        if err then callback?(err) else callback(null, _.map(docs, (doc) => @backbone_adapter.docToModel(doc, @model_type)))

  findDocs: (query_args_callback) ->
    [query_args, callback] = _extractQueryArgs.call(this, arguments)

    @_collection (err, collection) =>
      return callback(err) if err
      collection.find.apply(collection, query_args).toArray(callback)

  findCursor: (query_args_callback) ->
    [query_args, callback] = _extractQueryArgs.call(this, arguments, true)

    @_collection (err, collection) =>
      return callback(err) if err
      callback(null, collection.find.apply(collection, query_args))

  parseRequestQuery: (req) ->
    query = if req.query then _.clone(req.query) else {}
    (query[key] = JSON.parse(value) for key, value of query) if _.isObject(query)
    return query

  # options:
  #  @key: default 'created_at'
  #  @reverse: default false
  #  @date: default now
  #  @query: default none
  findOneNearDate: (options, callback) ->
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

  docToModel: (doc) -> @backbone_adapter.docToModel(doc, @model_type)
  docsToModels: (docs) -> _.map(docs, (doc) => @backbone_adapter.docToModel(doc, @model_type))
  collection: (callback) -> @_collection(callback)

  ###################################

  _collection: (model, callback) ->
    (callback = model; model = null) if arguments.length is 1
    @initialize(model) unless @connection
    @connection.collection(callback)

# options
#   model_type - the model that will be used to add query functions to
module.exports = (model_type) ->
  sync = new BackboneSync(model_type)
  return (method, model, options={}) -> sync[method](model, options)
