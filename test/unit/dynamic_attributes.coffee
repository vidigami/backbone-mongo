util = require 'util'
assert = require 'assert'
_ = require 'underscore'
Backbone = require 'backbone'
Queue = require 'queue-async'

Utils = require 'backbone-orm/lib/utils'

runTests = (options, cache, callback) ->
  require('backbone-orm/lib/cache').configure(if cache then {max: 100} else null) # configure caching

  class MongoModel extends Backbone.Model
    url: "#{require('../config/database')['test']}/mongo_model"
    sync: require('../../sync')(MongoModel)

  describe 'Dynamic Attributes Functionality', ->

    before (done) -> return done() unless options.before; options.before([MongoModel], done)
    after (done) -> callback(); done()
    describe 'unset', ->
      it 'should unset an attribute', (done) ->
        model = new MongoModel({name: 'Bob', type: 'thing'})
        model.save {}, Utils.bbCallback (err) ->
          assert.ok(!err, "No errors: #{err}")

          MongoModel.findOne model.id, (err, saved_model) ->
            assert.ok(!err, "No errors: #{err}")
            assert.ok(!!saved_model, "Found model: #{model.id}")
            assert.deepEqual(model.toJSON(), saved_model.toJSON(), "1 Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")

            # unset and confirm different instances
            model.unset('type')
            assert.ok(_.isUndefined(model.get('type')), "Attribute was unset")
            if cache
              assert.deepEqual(model.toJSON(), saved_model.toJSON(), "2 Not Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")
            else
              assert.notDeepEqual(model.toJSON(), saved_model.toJSON(), "2 Not Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")
            model.save {}, Utils.bbCallback (err) ->
              assert.ok(!err, "No errors: #{err}")
              assert.ok(_.isUndefined(model.get('type')), "Attribute is still unset")

              MongoModel.findOne model.id, (err, saved_model) ->
                assert.ok(!err, "No errors: #{err}")
                assert.ok(!!saved_model, "Found model: #{model.id}")
                assert.ok(_.isUndefined(saved_model.get('type')), "Attribute was unset")

                assert.deepEqual(model.toJSON(), saved_model.toJSON(), "3 Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")

                # try resetting
                model.set({type: 'dynamic'})
                assert.ok(!_.isUndefined(model.get('type')), "Attribute was set")
                if cache
                  assert.deepEqual(model.toJSON(), saved_model.toJSON(), "4 Not Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")
                else
                  assert.notDeepEqual(model.toJSON(), saved_model.toJSON(), "4 Not Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")
                model.save {}, Utils.bbCallback (err) ->
                  assert.ok(!err, "No errors: #{err}")
                  assert.ok(!_.isUndefined(model.get('type')), "Attribute is still set")

                  MongoModel.findOne model.id, (err, saved_model) ->
                    assert.ok(!err, "No errors: #{err}")
                    assert.ok(!!saved_model, "Found model: #{model.id}")
                    assert.ok(!_.isUndefined(saved_model.get('type')), "Attribute was set")

                    assert.deepEqual(model.toJSON(), saved_model.toJSON(), "5 Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")

                    done()

module.exports = (options, callback) ->
  queue = new Queue(1)
  queue.defer (callback) -> runTests(options, false, callback)
  queue.defer (callback) -> runTests(options, true, callback)
  queue.await callback
