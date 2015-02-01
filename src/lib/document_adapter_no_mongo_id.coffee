###
  backbone-mongo.js 0.6.8
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-mongo
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

{JSONUtils} = require 'backbone-orm'

module.exports = class DocumentAdapter_NoMongoId

  @id_attribute = 'id'

  @findId: (id) -> return id
  @modelFindQuery: (model) -> return {id: model.id}

  @nativeToAttributes: (doc) ->
    return {} unless doc
    delete doc._id
    return doc

  @attributesToNative: (attributes) -> return attributes
