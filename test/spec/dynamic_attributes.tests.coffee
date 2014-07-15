util = require 'util'
assert = require 'assert'
_ = require 'underscore'
Backbone = require 'backbone'

BackboneORM = require('backbone-orm')
{Queue, Utils} = BackboneORM
{ModelCache} = BackboneORM.CacheSingletons

option_sets = require('backbone-orm/test/option_sets')
parameters = __test__parameters if __test__parameters?
parameters or= {}; parameters.sync or= require '../..'
_.each option_sets, exports = (options) ->
  options = _.extend({}, options, parameters) if parameters

  DATABASE_URL = options.database_url or ''
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync

  class MongoModel extends Backbone.Model
    url: "#{DATABASE_URL}/mongo_model"
    sync: SYNC(MongoModel)

  describe "Dynamic Attributes Functionality #{options.$tags}", ->

    before (done) -> return done() unless options.before; options.before([MongoModel], done)
    after (done) ->
      queue = new Queue()
      queue.defer (callback) -> ModelCache.reset(callback)
      queue.defer (callback) -> Utils.resetSchemas [MongoModel], callback
      queue.await done

    beforeEach (done) ->
      queue = new Queue(1)
      queue.defer (callback) -> ModelCache.configure({enabled: !!options.cache, max: 100}, callback)
      queue.defer (callback) -> Utils.resetSchemas [MongoModel], callback
      queue.await done

    # TODO: these fail when the model cache is enabled
    describe 'unset', ->
      it 'should unset an attribute', (done) ->
        model = new MongoModel({name: 'Bob', type: 'thing'})
        model.save (err) ->
          assert.ok(!err, "No errors: #{err}")

          MongoModel.findOne model.id, (err, saved_model) ->
            assert.ok(!err, "No errors: #{err}")
            assert.ok(!!saved_model, "Found model: #{model.id}")
            assert.deepEqual(model.toJSON(), saved_model.toJSON(), "1 Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")

            # unset and confirm different instances
            model.unset('type')
            assert.ok(_.isUndefined(model.get('type')), "Attribute was unset")
            if options.cache
              assert.deepEqual(model.toJSON(), saved_model.toJSON(), "2 Not Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")
            else
              assert.notDeepEqual(model.toJSON(), saved_model.toJSON(), "2 Not Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")
            model.save (err) ->
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
                if options.cache
                  assert.deepEqual(model.toJSON(), saved_model.toJSON(), "4 Not Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")
                else
                  assert.notDeepEqual(model.toJSON(), saved_model.toJSON(), "4 Not Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")
                model.save (err) ->
                  assert.ok(!err, "No errors: #{err}")
                  assert.ok(!_.isUndefined(model.get('type')), "Attribute is still set")

                  MongoModel.findOne model.id, (err, saved_model) ->
                    assert.ok(!err, "No errors: #{err}")
                    assert.ok(!!saved_model, "Found model: #{model.id}")
                    assert.ok(!_.isUndefined(saved_model.get('type')), "Attribute was set")

                    assert.deepEqual(model.toJSON(), saved_model.toJSON(), "5 Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")

                    done()

      it 'should unset two attributes', (done) ->
        model = new MongoModel({name: 'Bob', type: 'thing', direction: 'north'})
        model.save (err) ->
          assert.ok(!err, "No errors: #{err}")

          MongoModel.findOne model.id, (err, saved_model) ->
            assert.ok(!err, "No errors: #{err}")
            assert.ok(!!saved_model, "Found model: #{model.id}")
            assert.deepEqual(model.toJSON(), saved_model.toJSON(), "1 Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")

            # unset and confirm different instances
            model.unset('type')
            model.unset('direction')
            assert.ok(_.isUndefined(model.get('type')), "Attribute was unset")
            assert.ok(_.isUndefined(model.get('direction')), "Attribute was unset")
            if options.cache
              assert.deepEqual(model.toJSON(), saved_model.toJSON(), "2 Not Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")
            else
              assert.notDeepEqual(model.toJSON(), saved_model.toJSON(), "2 Not Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")
            model.save (err) ->
              assert.ok(!err, "No errors: #{err}")
              assert.ok(_.isUndefined(model.get('type')), "Attribute 'type' is still unset")
              assert.ok(_.isUndefined(model.get('direction')), "Attribute 'direction' is still unset")

              MongoModel.findOne model.id, (err, saved_model) ->
                assert.ok(!err, "No errors: #{err}")
                assert.ok(!!saved_model, "Found model: #{model.id}")
                assert.ok(_.isUndefined(saved_model.get('type')), "Attribute was unset")
                assert.ok(_.isUndefined(saved_model.get('direction')), "Attribute was unset")

                assert.deepEqual(model.toJSON(), saved_model.toJSON(), "3 Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")

                # try resetting
                model.set({type: 'dynamic', direction: 'south'})
                assert.ok(!_.isUndefined(model.get('type')), "Attribute was set")
                assert.ok(!_.isUndefined(model.get('direction')), "Attribute was set")
                if options.cache
                  assert.deepEqual(model.toJSON(), saved_model.toJSON(), "4 Not Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")
                else
                  assert.notDeepEqual(model.toJSON(), saved_model.toJSON(), "4 Not Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")
                model.save (err) ->
                  assert.ok(!err, "No errors: #{err}")
                  assert.ok(!_.isUndefined(model.get('type')), "Attribute is still set")
                  assert.ok(!_.isUndefined(model.get('direction')), "Attribute is still set")

                  MongoModel.findOne model.id, (err, saved_model) ->
                    assert.ok(!err, "No errors: #{err}")
                    assert.ok(!!saved_model, "Found model: #{model.id}")
                    assert.ok(!_.isUndefined(saved_model.get('type')), "Attribute 'type' was set")
                    assert.ok(!_.isUndefined(saved_model.get('direction')), "Attribute 'direction' was set")

                    assert.deepEqual(model.toJSON(), saved_model.toJSON(), "5 Expected: #{util.inspect(model.toJSON())}. Actual: #{util.inspect(saved_model.toJSON())}")

                    done()
