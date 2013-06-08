_ = require 'underscore'
Queue = require 'queue-async'

testGenerator = require 'backbone-rest/test/lib/test_generator'

Album = require '../models/album'
AlbumsFabricator = require '../fabricators/albums'
ALBUM_COUNT = 20

testGenerator {
  model_type: Album
  route: 'albums'
  beforeEach: (callback) ->
    queue = new Queue(1)
    queue.defer (callback) -> Album.destroy {}, callback
    queue.defer (callback) -> AlbumsFabricator.create ALBUM_COUNT, callback
    queue.await (err) ->
      return callback(err) if err
      Album.all (err, albums) ->
        return callback(err) if err
        callback(null, _.map(albums, (test)-> test.toJSON()))
}