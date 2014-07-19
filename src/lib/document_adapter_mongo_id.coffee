###
  backbone-mongo.js 0.5.9
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-mongo
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

{ObjectID} =  require 'mongodb'
{JSONUtils} = require 'backbone-orm'

module.exports = class DocumentAdapter_MongoId

  @id_attribute = '_id'

  @findId: (id) -> try return new ObjectID("#{id}") catch err then console.log "BackboneMongo: invalid id", id, err; return null
  @modelFindQuery: (model) -> try return {_id: new ObjectID("#{model.id}")} catch err then console.log "BackboneMongo: invalid id", id, err; return {_id: null}
  @nativeToAttributes: (doc) ->
    return {} unless doc
    if doc._id
      doc.id = doc._id.toString()
      delete doc._id
    return doc

  @attributesToNative: (attributes) ->
    return {} unless attributes
    if attributes.id
      attributes._id = new ObjectID("#{attributes.id}")
      delete attributes.id
    return attributes
