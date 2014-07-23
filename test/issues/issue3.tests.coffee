util = require 'util'
assert = require 'assert'
BackboneORM = require 'backbone-orm'
{_, Backbone, Queue, Utils} = BackboneORM

_.each BackboneORM.TestUtils.optionSets(), exports = (options) ->
  options = _.extend({}, options, __test__parameters) if __test__parameters?

  DATABASE_URL = options.database_url or ''
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync

  describe "Fetching embedded model #{options.$parameter_tags or ''}#{options.$tags}", ->
    InnerModel = OuterModel = null
    before ->
      BackboneORM.configure {model_cache: {enabled: !!options.cache, max: 100}}

      class InnerModel extends Backbone.Model
        model_name: 'InnerModel'
        sync: BackboneORM.sync(InnerModel)

      class OuterModel extends Backbone.Model
        url: "#{DATABASE_URL}/outer_models"
        schema:
          inner_model: ['belongsTo', InnerModel, {embed: true}]
        sync: SYNC(OuterModel)

    after (callback) -> Utils.resetSchemas [InnerModel, OuterModel], callback
    beforeEach (callback) -> Utils.resetSchemas [InnerModel, OuterModel], callback

    it 'should fetch embedded model', (done) ->

      om = new OuterModel({foo: 'bar', inner_model: new InnerModel({bar: 'baz'})})
      om.save (err, om) ->
        assert(!err)
        om2 = new OuterModel({id: om.id})
        om2.fetch (err, om2) ->
          assert.deepEqual(om2.get('inner_model').attributes, om.get('inner_model').attributes)

          OuterModel.findOne om.id, (err, om3) ->
            assert.deepEqual(om3.get('inner_model').attributes, om.get('inner_model').attributes)
            done()
