util = require 'util'
assert = require 'assert'

BackboneORM = require 'backbone-orm'
{_, Backbone, Queue, Utils} = BackboneORM

_.each BackboneORM.TestUtils.optionSets(), exports = (options) ->
  options = _.extend({}, options, __test__parameters) if __test__parameters?

  DATABASE_URL = options.database_url or ''
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync

  describe "Indexing Functionality #{options.$tags} @indexing", ->
    IndexedModel = null
    before ->
      BackboneORM.configure {model_cache: {enabled: !!options.cache, max: 100}}

      class IndexedModel extends Backbone.Model
        schema:
          id: [indexed: true]
          name: [indexed: true]
        url: "#{DATABASE_URL}/indexed_models"
        sync: SYNC(IndexedModel)

    after (callback) -> Utils.resetSchemas [IndexedModel], callback
    beforeEach (callback) -> Utils.resetSchemas [IndexedModel], callback

    it 'should ensure indexes', (done) ->

      IndexedModel::sync 'collection', (err, collection) ->
        assert.ok(!err, "No errors: #{err}")
        assert.ok(!!collection)

        # indexing is async so need to poll
        checkIndexes = (callback, name) -> fn = ->
          collection.indexExists name, (err, exists) ->
            assert.ok(!err, "No errors: #{err}")
            return callback() if exists
            _.delay fn, 50

        queue = new Queue()
        queue.defer (callback) -> checkIndexes(callback, 'id_1')()
        queue.defer (callback) -> checkIndexes(callback, 'name_1')()
        queue.await done

    it 'should sort by id', (done) ->
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
