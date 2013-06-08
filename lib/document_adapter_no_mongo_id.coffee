JSONUtils = require './json_utils'
Store = require './store'

module.exports = class DocumentAdapter_NoMongoId

  @idAttribute = 'id'

  @modelFindQuery: (model) -> return {id: model.get('id')}

  @docToModel: (doc, model_type) ->
    return null unless doc

    # work around for Backbone Relational
    return Store.findOrCreate(model_type, (new model_type()).parse(@docToAttributes(doc)))

  @docToAttributes: (doc) ->
    return {} unless doc
    doc[key] = JSONUtils.JSONToValue(value) for key, value of doc
    delete doc._id
    return doc

  @attributesToDoc: (attributes) ->
    return {} unless attributes
    attributes[key] = JSONUtils.valueToJSON(value) for key, value of attributes
    delete attributes._id
    return attributes