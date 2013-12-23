util = require 'util'
assert = require 'assert'
Backbone = require 'backbone'

module.exports = (options, callback) ->
  describe 'Fetching embedded model', ->

    after (done) -> callback(); done()

    it 'should fetch embedded model', (done) ->

      class InnerModel extends Backbone.Model
        urlRoot: '/inner_models'
        sync: require('backbone-orm').sync(InnerModel)

      class OuterModel extends Backbone.Model
        urlRoot: 'mongodb://localhost:27017/outer_models',
        schema:
          inner_model: ['belongsTo', InnerModel, {embed: true}]
        sync: require('../../lib/index').sync(OuterModel)

      om = new OuterModel({foo: 'bar', inner_model: new InnerModel({bar: 'baz'})})
      om.save (err, om) ->
        assert(!err)
        om2 = new OuterModel({id: om.id})
        om2.fetch (err, om2) ->
          assert.deepEqual(om2.get('inner_model').attributes, om.get('inner_model').attributes)

          OuterModel.findOne om.id, (err, om3) ->
            assert.deepEqual(om3.get('inner_model').attributes, om.get('inner_model').attributes)
            done()
