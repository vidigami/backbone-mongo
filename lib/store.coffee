Backbone = require 'backbone-relational'

module.exports = class Store
  @find: (model_type, id) ->
    return model if (model_type instanceof Backbone.RelationalModel) and id and (model = Backbone.Relational.store.find(model_type, id))
    return null

  @findOrCreate: (model_type, attrs) ->
    model = new model_type if !((model_type instanceof Backbone.RelationalModel) and attrs.id and (model = Backbone.Relational.store.find(model_type, attrs.id)))
    model.set(attrs)
    return model