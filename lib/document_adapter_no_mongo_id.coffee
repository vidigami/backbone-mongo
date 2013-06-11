util = require 'util'

JSONUtils = require 'backbone-node/lib/json_utils'
BackboneRelationalUtils = require 'backbone-node/lib/backbone_relational_utils'

module.exports = class DocumentAdapter_NoMongoId

  @idAttribute = 'id'

  @modelFindQuery: (model) -> return {id: model.get('id')}

  @nativeToModel: (doc, model_type) ->
    return null unless doc

    # work around for Backbone Relational
    return BackboneRelationalUtils.findOrCreate(model_type, model_type::parse(@nativeToAttributes(doc)))

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