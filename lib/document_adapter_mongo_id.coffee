ObjectID =  require('mongodb').ObjectID
JSONUtils = require './json_utils'
BackboneRelational = require './backbone_relational'

module.exports = class DocumentAdapter_MongoId

  @idAttribute = '_id'

  @modelFindQuery: (model) -> return {_id: new ObjectID("#{model.get('id')}")}

  @nativeToModel: (doc, model_type) ->
    return null unless doc

    # work around for Backbone Relational
    return BackboneRelational.findOrCreate(model_type, model_type::parse(@nativeToAttributes(doc)))

  @nativeToAttributes: (doc) ->
    return {} unless doc
    for key, value of doc
      if key is '_id'
        doc.id = doc['_id'].toString()
        delete doc._id
      else
        doc[key] = JSONUtils.JSONToValue(value)
    return doc

  @attributesToNative: (attributes) ->
    return {} unless attributes
    for key, value of attributes
      if key is 'id'
        attributes['_id'] = new ObjectID("#{value}")
        delete attributes.id
      else
        attributes[key] = JSONUtils.valueToJSON(value)
    return attributes