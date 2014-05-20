util = require 'util'
assert = require 'assert'
_ = require 'underscore'
Backbone = require 'backbone'
Queue = require 'backbone-orm/lib/queue'

ModelCache = require('backbone-orm/lib/cache/singletons').ModelCache

module.exports = (options, callback) ->
  ModelCache.configure({enabled: !!options.cache, max: 100}) # configure caching

  class FirstModel extends Backbone.Model
    schema:
      seconds: -> ['hasMany', SecondModel]
    url: "#{require('../config/database')['test']}/firsts"
    sync: require('../../lib/sync')(FirstModel)

  class SecondModel extends Backbone.Model
    schema:
      firsts: -> ['hasMany', FirstModel]
    url: "#{require('../config/database')['test']}/seconds"
    sync: require('../../lib/sync')(SecondModel)


  first_id = null
  second_ids = []
  describe 'Join Table Functionality', ->

    before (done) -> return done() unless options.before; options.before([IndexedModel, ManualIdModel], done)
    after (done) -> callback(); done()
    beforeEach (done) ->
      queue = new Queue(1)
      queue.defer (callback) -> FirstModel.resetSchema(callback)
      queue.defer (callback) -> SecondModel.resetSchema(callback)
      queue.defer (callback) ->
        models = []
        models.push new FirstModel()
        models.push new FirstModel()
        models.push new SecondModel({firsts: [models[0]]})
        models.push new SecondModel({firsts: [models[1]]})

        model_queue = new Queue(1)
        for model in models
          do (model) -> model_queue.defer (callback) ->
            model.save callback

        model_queue.await (err) ->
          first_id = models[1].id
          second_ids.push(models[i].id) for i in [2..3]
          callback()


      queue.await done

    ######################################
    # Join Table
    ######################################

    describe 'scope by second model', ->
      it 'it should return only requested model', (done) ->

        console.log 'First Model ID', first_id, 'Second Model IDs', second_ids
        FirstModel.find {id: first_id, 'seconds.id': {$in: second_ids}}, (err, firsts) ->
          assert.ok(!err, "No errors: #{err}")
          console.log 'Returned First Model IDs', _.pluck(firsts, 'id')
          assert.ok(firsts.length is 1, "Length should be 1: #{firsts.length}")
          done()
