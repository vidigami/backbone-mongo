util = require 'util'
assert = require 'assert'

BackboneORM = require 'backbone-orm'
{_, Backbone, Queue, Utils} = BackboneORM

option_sets = require('backbone-orm/test/option_sets')
parameters = __test__parameters if __test__parameters?
parameters or= {}; parameters.sync or= require '../..'
_.each option_sets, exports = (options) ->
  options = _.extend({}, options, parameters) if parameters

  DATABASE_URL = options.database_url or ''
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync

  describe "Id Functionality #{options.$tags}", ->
    IndexedModel = ManualIdModel = null
    before ->
      BackboneORM.configure {model_cache: {enabled: !!options.cache, max: 100}}

      class IndexedModel extends Backbone.Model
        schema:
          _id: [indexed: true]
        url: "#{DATABASE_URL}/indexed_models"
        sync: SYNC(IndexedModel)

      class ManualIdModel extends Backbone.Model
        schema:
          id: [indexed: true, manual_id: true]
        url: "#{DATABASE_URL}/manual_id_models"
        sync: SYNC(ManualIdModel)

    after (callback) -> Utils.resetSchemas [IndexedModel, ManualIdModel], callback
    beforeEach (callback) -> Utils.resetSchemas [IndexedModel, ManualIdModel], callback

    ######################################
    # Indexing
    ######################################

    describe 'indexing', ->
      it 'should ensure indexes', (done) ->

        # indexing is async so need to poll
        checkIndexes = ->
          IndexedModel::sync 'collection', (err, collection) ->
            assert.ok(!err, "No errors: #{err}")

            collection.indexExists '_id_', (err, exists) ->
              assert.ok(!err, "No errors: #{err}")
              return done() if exists
              _.delay checkIndexes, 50

        checkIndexes()

    ######################################
    # Custom Ids
    ######################################

    describe 'manual_id', ->
      it 'should fail to save if you do not provide an id', (done) ->
        model = new ManualIdModel({name: 'Bob'})
        model.save (err) ->
          assert.ok(err, 'should not save if missing an id')
          done()

      it 'should save if provide an id', (done) ->
        model = new ManualIdModel({id: _.uniqueId(), name: 'Bob'})
        model.save (err) ->
          assert.ok(!err, "No errors: #{err}")
          done()

      it 'should fail to save if you delete the id after saving', (done) ->
        model = new ManualIdModel({id: _.uniqueId(), name: 'Bob'})
        model.save (err) ->
          assert.ok(!err, "No errors: #{err}")
          model.save {id: null}, (err) ->
            assert.ok(err, 'should not save if missing an id')
            done()

    ######################################
    # Sort by Id
    ######################################

    describe 'sorting', ->
      it 'should sort by _id', (done) ->
        (new IndexedModel({name: 'Bob'})).save (err) ->
          assert.ok(!err, "No errors: #{err}")

          (new IndexedModel({name: 'Fred'})).save (err) ->
            assert.ok(!err, "No errors: #{err}")
            IndexedModel.cursor().sort('id').toModels (err, models) ->
              assert.ok(!err, "No errors: #{err}")

              ids = (model.id for model in models)
              sorted_ids = _.clone(ids).sort()
              assert.deepEqual(ids, sorted_ids, "Models were returned in sorted order")
              done()

      it 'should sort by id', (done) ->
        (new ManualIdModel({id: 3, name: 'Bob'})).save (err) ->
          assert.ok(!err, "No errors: #{err}")

          (new ManualIdModel({id: 1, name: 'Bob'})).save (err) ->
            assert.ok(!err, "No errors: #{err}")

            ManualIdModel.cursor().sort('id').toModels (err, models) ->
              assert.ok(!err, "No errors: #{err}")
              ids = (model.id for model in models)
              sorted_ids = _.clone(ids).sort()
              assert.deepEqual(ids, sorted_ids, "Models were returned in sorted order")
              done()
