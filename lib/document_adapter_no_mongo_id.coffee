util = require 'util'

JSONUtils = require 'backbone-orm/lib/json_utils'

module.exports = class DocumentAdapter_NoMongoId

  @idAttribute = 'id'

  @findId: (id) -> return id
  @modelFindQuery: (model) -> return {id: model.id}

  @nativeToAttributes: (doc) ->
    return {} unless doc
    delete doc._id
    return doc

  @attributesToNative: (attributes) -> return attributes
