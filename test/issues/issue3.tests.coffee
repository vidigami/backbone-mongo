util = require 'util'
assert = require 'assert'
Backbone = require 'backbone'
BackboneORM = require('backbone-orm')
{Queue, Utils} = BackboneORM
{ModelCache} = BackboneORM.CacheSingletons

SYNC = (if __test__parameters? then __test__parameters else require '../..').sync
describe 'Fetching embedded model', ->
  InnerModel = OuterModel = null
  before ->
    class InnerModel extends Backbone.Model
      urlRoot: '/inner_models'
      sync: require('backbone-orm').sync(InnerModel)

    class OuterModel extends Backbone.Model
      urlRoot: 'mongodb://localhost:27017/outer_models',
      schema:
        inner_model: ['belongsTo', InnerModel, {embed: true}]
      sync: SYNC(OuterModel)

  after (callback) ->
    queue = new Queue()
    queue.defer (callback) -> ModelCache.reset(callback)
    queue.defer (callback) -> Utils.resetSchemas [InnerModel, OuterModel], callback
    queue.await callback

  beforeEach (callback) ->
    queue = new Queue(1)
    queue.defer (callback) -> ModelCache.configure({enabled: false, max: 100}, callback)
    queue.defer (callback) -> Utils.resetSchemas [InnerModel, OuterModel], callback
    queue.await callback

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