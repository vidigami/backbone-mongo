util = require 'util'
_ = require 'underscore'
moment = require 'moment'
Queue = require 'queue-async'

MongoCursor = require './lib/mongo_cursor'
Schema = require 'backbone-orm/lib/schema'
Connection = require './lib/connection'
Utils = require 'backbone-orm/lib/utils'

module.exports = class MongoSync

  constructor: (@model_type) ->
    @schema = new Schema(@model_type)
    @backbone_adapter = @model_type.backbone_adapter = @_selectAdapter()

  initialize: (model) ->
    return if @is_initialized; @is_initialized = true

    throw new Error("Missing url for model") unless url = _.result(@model_type.prototype, 'url')

    # publish methods and sync on model
    @model_type.model_name = Utils.parseUrl(url).model_name unless @model_type.model_name # model_name can be manually set
    throw new Error('Missing model_name for model') unless @model_type.model_name

    @connect(url)

    @schema.initialize()

  ###################################
  # Classic Backbone Sync
  ###################################
  read: (model, options) ->
    # a collection
    if model.models
      @cursor().toJSON (err, json) ->
        return options.error(err) if err
        options.success?(json)

    # a model
    else
      @cursor(model.id).toJSON (err, json) ->
        return options.error(err) if err
        return options.error(new Error "Model not found. Id #{model.id}") unless json
        options.success?(json)

  create: (model, options) ->
    return options.error(new Error("Missing manual id for create: #{util.inspect(model.attributes)}")) if @manual_id and not model.id

    @connection.collection (err, collection) =>
      return options.error(err) if err
      return options.error(new Error('new document has a non-empty revision')) if model.get('_rev')
      doc = @backbone_adapter.attributesToNative(model.toJSON()); doc._rev = 1 # start revisions
      collection.insert doc, (err, docs) =>
        return options.error(new Error("Failed to create model")) if err or not docs or docs.length isnt 1
        options.success?(@backbone_adapter.nativeToAttributes(docs[0]))

  update: (model, options) ->
    return @create(model, options) unless model.get('_rev') # no revision, create - in the case we manually set an id and are saving for the first time
    return options.error(new Error("Missing manual id for create: #{util.inspect(model.attributes)}")) if @manual_id and not model.id

    @connection.collection (err, collection) =>
      return options.error(err) if err

      json = @backbone_adapter.attributesToNative(model.toJSON())
      delete json._id if @backbone_adapter.id_attribute is '_id'
      find_query = @backbone_adapter.modelFindQuery(model)
      find_query._rev = json._rev
      json._rev++ # increment revisions

      modifications = {$set: json}
      if changes = model.changedAttributes() # look for unset things
        keys_to_delete = []
        keys_to_delete.push(key) for key, value of changes when _.isUndefined(value)
        if keys_to_delete.length
          modifications.$unset = {}
          modifications.$unset[key] = '' for key in keys_to_delete

      # update the record
      collection.findAndModify find_query, [[@backbone_adapter.id_attribute, 'asc']], modifications, {new: true}, (err, doc) =>
        return options.error(new Error("Failed to update model. Doc: #{!!doc}. Error: #{err}")) if err or not doc
        return options.error(new Error("Failed to update revision. Is: #{doc._rev} expecting: #{json._rev}")) if doc._rev isnt json._rev
        return options.success?(@backbone_adapter.nativeToAttributes(doc))

  delete: (model, options) ->
    @destroy model.id, (err) ->
      return options.error(model, err, options) if err
      options.success?(model, {}, options)

  ###################################
  # Backbone ORM - Class Extensions
  ###################################
  resetSchema: (options, callback) ->
    queue = new Queue()

    queue.defer (callback) => @collection (err, collection) ->
      return callback(err) if err
      collection.remove (err) ->
        if options.verbose
          if err
            console.log "Failed to reset collection: #{collection.collectionName}. Error: #{err}"
          else
            console.log "Reset collection: #{collection.collectionName}"
        callback(err)

    queue.defer (callback) =>
      schema = @model_type.schema()
      for key, relation of schema.relations
        if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
          do (relation) -> queue.defer (callback) -> Utils.createJoinTableModel(relation).resetSchema(callback)
      callback()

    queue.await callback

  cursor: (query={}) -> return new MongoCursor(query, _.pick(@, ['model_type', 'connection', 'backbone_adapter']))

  destroy: (query, callback) ->
    @connection.collection (err, collection) =>
      return callback(err) if err
      query = {id: query} unless _.isObject(query)
      collection.remove @backbone_adapter.attributesToNative(query), callback


  ###################################
  # Backbone Mongo - Extensions
  ###################################
  connect: (url) ->
    return if @connection and @connection.url is url
    @connection.destroy() if @connection
    @connection = new Connection(url, @schema)

  collection: (callback) -> @connection.collection(callback)

  ###################################
  # Internal
  ###################################
  _selectAdapter: ->
    schema = _.result(@model_type, 'schema') or {}
    for field_name, field_info of schema
      continue if (field_name isnt 'id') or not _.isArray(field_info)
      for info in field_info
        if info.manual_id
          @manual_id = true
          return require './lib/document_adapter_no_mongo_id'
    return require './lib/document_adapter_mongo_id' # default is using the mongodb's ids


module.exports = (model_type) ->
  sync = new MongoSync(model_type)

  model_type::sync = sync_fn = (method, model, options={}) -> # save for access by model extensions
    sync.initialize()
    return module.exports.apply(null, Array::slice.call(arguments, 1)) if method is 'createSync' # create a new sync
    return sync if method is 'sync'
    return sync.schema if method is 'schema'
    if sync[method] then sync[method].apply(sync, Array::slice.call(arguments, 1)) else return undefined

  require('backbone-orm/lib/model_extensions')(model_type) # mixin extensions
  return require('backbone-orm/lib/cache').configureSync(model_type, sync_fn)
