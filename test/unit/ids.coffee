util = require 'util'
assert = require 'assert'
_ = require 'underscore'
Backbone = require 'backbone'
Queue = require 'backbone-orm/lib/queue'

ModelCache = require('backbone-orm/lib/cache/singletons').ModelCache

module.exports = (options, callback) ->
  ModelCache.configure({enabled: !!options.cache, max: 100}) # configure caching

  class IndexedModel extends Backbone.Model
    schema:
      _id: [indexed: true]
    url: "#{require('../config/database')['test']}/indexed_models"
    sync: require('../../lib/sync')(IndexedModel)

  class ManualIdModel extends Backbone.Model
    schema:
      id: [indexed: true, manual_id: true]
    url: "#{require('../config/database')['test']}/indexed_models"
    sync: require('../../lib/sync')(ManualIdModel)


  describe 'Id Functionality', ->

    before (done) -> return done() unless options.before; options.before([IndexedModel, ManualIdModel], done)
    after (done) -> callback(); done()
    beforeEach (done) ->
      queue = new Queue(1)
      queue.defer (callback) -> IndexedModel.resetSchema(callback)
      queue.defer (callback) -> ManualIdModel.resetSchema(callback)
      queue.await done

    ######################################
    # Indexing
    ######################################

    describe 'indexing', ->
      it 'should ensure indexes', (done) ->

        # indexing is async so need to poll
        checkIndexes = ->
          IndexedModel::sync 'collection', (err, collection) ->
            console.log "collection"

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
