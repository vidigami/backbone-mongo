assert = require 'assert'
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

describe 'Syntatic sugar', ->

  beforeEach (done) ->
    queue = new Queue(1)
    queue.defer (callback) -> Album.destroy {}, callback
    queue.defer (callback) -> AlbumsFabricator.create ALBUM_COUNT, callback
    queue.await done

  it 'Handles a count query', (done) ->
    Album.count (err, count) ->
      assert.ok(!err, 'no errors')
      assert.equal(count, ALBUM_COUNT, 'counted expected number of albums')
      done()


  it 'Handles an all query', (done) ->
    Album.all (err, models) ->
      assert.ok(!err, 'no errors')
      assert.equal(models.length, ALBUM_COUNT, 'counted expected number of albums')
      done()

