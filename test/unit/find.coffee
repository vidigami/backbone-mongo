util = require 'util'
assert = require 'assert'
_ = require 'underscore'
Backbone = require 'backbone'
Queue = require 'queue-async'

Album = require '../models/album'
AlbumsFabricator = require '../fabricators/albums'
ALBUM_COUNT = 20

adapters =
  bbCallback: (callback) -> return {success: ((model) -> callback(null, model)), error: (-> callback(new Error("failed")))}

getAt = (model_type, index, callback) ->
  model_type.cursor().offset(index).limit(1).toModels (err, models) ->
    return callback(err) if err
    return callback(null, if (models.length is 1) then models[0] else null)

setAllNames = (model_type, name, callback) ->
  model_type.all (err, all_models) ->
    return callback(err) if err
    queue = new Queue()
    for album in all_models
      do (album) -> queue.defer (callback) -> album.save {name: name}, adapters.bbCallback callback
    queue.await callback

describe 'Model.find', ->

  beforeEach (done) ->
    queue = new Queue(1)
    queue.defer (callback) -> Album.destroy {}, callback
    queue.defer (callback) -> AlbumsFabricator.create ALBUM_COUNT, callback
    queue.await done

  it 'Handles a limit query', (done) ->
    Album.find {$limit: 3}, (err, models) ->
      assert.ok(!err, 'no errors')
      assert.equal(models.length, 3, 'found the right number of models')
      done()

  it 'Handles a find id query', (done) ->
    getAt Album, 0, (err, test_model) ->
      assert.ok(!err, 'no errors')
      assert.ok(test_model, 'found model')
      Album.find test_model.get('id'), (err, model) ->
        assert.ok(!err, 'no errors')
        assert.ok(model, 'gets a model')
        assert.equal(model.get('id'), test_model.get('id'), 'model has the correct id')
        done()


  it 'Handles another find id query', (done) ->
    getAt Album, 1, (err, test_model) ->
      assert.ok(!err, 'no errors')
      assert.ok(test_model, 'found model')

      Album.find test_model.get('id'), (err, model) ->
        assert.ok(!err, 'no errors')
        assert.ok(model, 'gets a model')
        assert.equal(model.get('id'), test_model.get('id'), 'model has the correct id')
        done()


  it 'Handles a find by query id', (done) ->
    getAt Album, 0, (err, test_model) ->
      assert.ok(!err, 'no errors')
      assert.ok(test_model, 'found model')

      Album.find {id: test_model.get('id')}, (err, models) ->
        assert.ok(!err, 'no errors')
        assert.equal(models.length, 1, 'finds the model')
        assert.equal(models[0].get('id'), test_model.get('id'), 'model has the correct id')
        done()


  it 'Handles a name find query', (done) ->
    getAt Album, 1, (err, test_model) ->
      assert.ok(!err, 'no errors')
      assert.ok(test_model, 'found model')

      Album.find {name: test_model.get('name')}, (err, models) ->
        assert.ok(!err, 'no errors')
        assert.ok(models.length, 'gets models')
        for model in models
          assert.equal(model.get('name'), test_model.get('name'), 'model has the correct name')
        done()


  it 'Handles a select fields query', (done) ->
    FIELD_NAMES = ['id', 'name', 'description']
    Album.find {$select: FIELD_NAMES}, (err, models) ->
      assert.ok(!err, 'no errors')
      assert.ok(models, 'gets models')
      assert.equal(models.length, ALBUM_COUNT, 'gets all models')
      for model in models
        assert.equal(_.size(model.attributes), FIELD_NAMES.length-1, 'gets only the requested values that exist')
      done()
