util = require 'util'
assert = require 'assert'
_ = require 'underscore'
Backbone = require 'backbone'
Queue = require 'backbone-orm/lib/queue'

ModelCache = require('backbone-orm/lib/cache/singletons').ModelCache

module.exports = (options, callback) ->
  DATABASE_URL = options.database_url or ''
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync

  ModelCache.configure({enabled: !!options.cache, max: 100}) # configure caching

  class MongoModel extends Backbone.Model
    url: "#{DATABASE_URL}/mongo_model"
    sync: SYNC(MongoModel)

  describe 'Dynamic Attributes Functionality', ->

    before (done) -> return done() unless options.before; options.before([MongoModel], done)
    after (done) -> callback(); done()

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
