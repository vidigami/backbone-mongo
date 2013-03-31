assert = require 'assert'

Backbone = require 'backbone'
BackboneSync = require '../../backbone_sync'

module.exports = class Thing extends Backbone.Model
  sync: new BackboneSync({database_config: require('../config/database')['test'], collection: 'things', model: Thing})

describe "BackboneSync", ->

  # TODO: before delete the collection

  describe "save a model", ->
    it "assign an id", (done) ->
      thing = new Thing({name: 'Bob'})

      assert.equal(thing.get('name'), 'Bob', 'name before save is Bob')
      assert.ok(!thing.get('id'), 'id before save doesn\'t exist')

      thing.save {}, {
        success: ->
          assert.equal(thing.get('name'), 'Bob', 'name after save is Bob')
          assert.ok(!!thing.get('id'), 'id after save is assigned')
          done()
      }

  # sync: new BackboneSync({database_config: require('../config/database'), collection: 'things', model: Thing, manual_id: true, indices: {id: 1}})
  # TODO: describe "use a manual id", ->
  #   it "assign an id", (done) ->

  # TODO: describe "add an index", ->
