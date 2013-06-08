util = require 'util'
assert = require 'assert'
_ = require 'underscore'
Backbone = require 'backbone'

Helpers = require 'backbone-node/lib/test_helpers'
adapters = Helpers.adapters

class IndexedModel extends Backbone.Model
  @schema:
    _id: [indexed: true]
  url: "#{require('../config/test_database')['test']}/indexed_models"
  sync: require('../../backbone_sync')(IndexedModel)

class CustomIndexModel extends Backbone.Model
  @schema:
    id: [indexed: true, manual_id: true]
  url: "#{require('../config/test_database')['test']}/indexed_models"
  sync: require('../../backbone_sync')(CustomIndexModel)


describe 'ID Functionality', ->

  ######################################
  # Indexing
  ######################################

  describe 'indexing', ->
    it 'should ensure indexes', (done) ->

      # indexing is async so need to poll
      checkIndexes = ->
        IndexedModel._sync.connection.collection (err, collection) ->
          assert.ok(!err, 'no errors')

          collection.indexExists '_id_', (err, exists) ->
            assert.ok(!err, 'no errors')
            return done() if exists
            _.delay checkIndexes, 50

      checkIndexes()

  ######################################
  # Custom Ids
  ######################################

  describe 'manual_id', ->
    it 'should fail to save if you do not provide an id', (done) ->
      model = new CustomIndexModel({name: 'Bob'})

      try
        model.save {}, adapters.bbCallback (err) ->
          assert.ok(false, 'Failed to throw for missing id when using a manual id')
          done()
      catch err
        assert.ok(err, 'Expecting throw if missing id')
        done()

    it 'should save if provide an id', (done) ->
      model = new CustomIndexModel({id: _.uniqueId(), name: 'Bob'})
      model.save {}, adapters.bbCallback (err) ->
        assert.ok(!err, 'no errors')
        done()

    it 'should fail to save if you delete the id after saving', (done) ->
      model = new CustomIndexModel({id: _.uniqueId(), name: 'Bob'})

      model.save {}, adapters.bbCallback (err) ->
        assert.ok(!err, 'no errors')
        try
          model.save {id: null}, adapters.bbCallback (err) ->
            assert.ok(false, 'Failed to throw for missing id when using a manual id')
            done()
        catch err
          assert.ok(err, 'Expecting throw if missing id')
          done()

