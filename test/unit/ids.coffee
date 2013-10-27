util = require 'util'
assert = require 'assert'
_ = require 'underscore'
Backbone = require 'backbone'
Queue = require 'backbone-orm/lib/queue'

ModelCache = require('backbone-orm/lib/cache/singletons').ModelCache
Utils = require 'backbone-orm/lib/utils'

module.exports = (options, callback) ->
  ModelCache.configure(if options.cache then {max: 100} else null) # configure caching

  class IndexedModel extends Backbone.Model
    @schema:
      _id: [indexed: true]
    url: "#{require('../config/database')['test']}/indexed_models"
    sync: require('../../src/sync')(IndexedModel)

  class ManualIdModel extends Backbone.Model
    @schema:
      id: [indexed: true, manual_id: true]
    url: "#{require('../config/database')['test']}/indexed_models"
    sync: require('../../src/sync')(ManualIdModel)


  describe 'ID Functionality', ->

    before (done) -> return done() unless options.before; options.before([IndexedModel, ManualIdModel], done)
    after (done) -> callback(); done()

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
        model.save {}, Utils.bbCallback (err) ->
          assert.ok(err, 'should not save if missing an id')
          done()

      it 'should save if provide an id', (done) ->
        model = new ManualIdModel({id: _.uniqueId(), name: 'Bob'})
        model.save {}, Utils.bbCallback (err) ->
          assert.ok(!err, "No errors: #{err}")
          done()

      it 'should fail to save if you delete the id after saving', (done) ->
        model = new ManualIdModel({id: _.uniqueId(), name: 'Bob'})
        model.save {}, Utils.bbCallback (err) ->
          assert.ok(!err, "No errors: #{err}")
          model.save {id: null}, Utils.bbCallback (err) ->
            assert.ok(err, 'should not save if missing an id')
            done()
