assert = require 'assert'

Backbone = require 'backbone'
Query = require '../../query'

class QueryThing extends Backbone.Model
  sync: require('../../backbone_sync')(QueryThing)
  url: require('../config/databases/query_things')['test']

describe 'Query', ->

  # TODO: before delete the collection

  it 'finds an object', (done) ->
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