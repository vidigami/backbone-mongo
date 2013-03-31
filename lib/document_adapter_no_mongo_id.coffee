json_utils = require './json_utils'

module.exports = class DocumentAdapter_NoMongoId

  @idAttribute = 'id'

  @modelFindQuery: (model) -> return {id: model.get('id')}

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
      attributes[key] = json_utils.JSONToValue(value)
    delete attributes._id
    return attributes

  @attributesToDoc: (attributes) ->
    return {} unless attributes
    doc = {}
    for key, value of attributes
      doc[key] = json_utils.valueToJSON(value)
    delete doc._id
    return doc