###
  backbone-mongo.js 0.5.6
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-mongo
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

JSONUtils = require 'backbone-orm/lib/json_utils'

module.exports = class DocumentAdapter_NoMongoId

  @id_attribute = 'id'

  @findId: (id) -> return id
  @modelFindQuery: (model) -> return {id: model.id}

  @nativeToAttributes: (doc) ->
    return {} unless doc
    delete doc._id
    return doc

  @attributesToNative: (attributes) -> return attributes
