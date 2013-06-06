assert = require 'assert'

Backbone = require 'backbone'
backboneSync = require '../../backbone_sync'
Query = require '../../query'

class QueryThing extends Backbone.Model
  sync: backboneSync(QueryThing)
  url: require('../config/databases/query_things')['test']
  @schema:
    id: [indexed: true]

describe "Query", ->

  # TODO: before delete the collection

  it "finds an object", (done) ->
    thing = new QueryThing({name: 'Bob'})
    thing.save {}, {
      success: ->
        query = new Query(QueryThing, {name: 'Bob'})
        query.toModels (err, models) ->
          assert.ok(!err, 'no errors')
          assert.ok(models.length, 'found models')
          assert.equal(models[0].get('name'), 'Bob', 'model is Bob')

          done()
    }