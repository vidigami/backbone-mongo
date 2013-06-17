util = require 'util'

JSONUtils = require 'backbone-orm/lib/json_utils'

module.exports = class DocumentAdapter_NoMongoId

  @idAttribute = 'id'

  @modelFindQuery: (model) -> return {id: model.get('id')}

  @nativeToAttributes: (doc) ->
    return {} unless doc
    doc[key] = JSONUtils.JSONToValue(value) for key, value of doc
    delete doc._id
    return doc

  @attributesToNative: (attributes) ->
    return {} unless attributes
    attributes[key] = JSONUtils.valueToJSON(value) for key, value of attributes
    delete attributes._id
    return attributes