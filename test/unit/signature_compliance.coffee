_ = require 'underscore'
Queue = require 'queue-async'

Album = require '../models/album'
AlbumsFabricator = require '../fabricators/albums'
ALBUM_COUNT = 20

test_parameters =
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

require('backbone-node/lib/test_generators/server_model')(test_parameters)
require('backbone-rest/lib/test_generators/backbone_rest')(test_parameters)
