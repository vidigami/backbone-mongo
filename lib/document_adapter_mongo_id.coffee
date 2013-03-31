ObjectID =  require('mongodb').ObjectID
json_utils = require './json_utils'

module.exports = class DocumentAdapter_MongoId

  @idAttribute = '_id'

  @modelFindQuery: (model) -> return {_id: new ObjectID("#{model.get('id')}")}

  @docToModel: (doc, model_type) ->
    return null unless doc
    model = new model_type()
    model.set(model.parse(@docToAttributes(doc)))
    return model

  @modelToDoc: (model) ->
    return @attributesToDoc(model.toJSON())

  @docToAttributes: (doc) ->
    return {} unless doc
    attributes = {}
    for key, value of doc
      if key is '_id'
        attributes.id = doc._id.toString()
      else
        attributes[key] = json_utils.JSONToValue(value)
    return attributes

  @attributesToDoc: (attributes) ->
    return {} unless attributes
    doc = {}
    for key, value of attributes
      if key is 'id'
        doc._id = new ObjectID("#{value}")
      else
        doc[key] = json_utils.valueToJSON(value)
    return doc