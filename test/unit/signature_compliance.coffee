util = require 'util'
_ = require 'underscore'
Queue = require 'queue-async'

JSONUtils = require 'backbone-node/json_utils'
Fabricator = require 'backbone-node/fabricator'
Album = require '../models/album'

test_parameters =
  model_type: Album
  route: 'albums'
  beforeEach: (callback) ->
    queue = new Queue(1)
    queue.defer (callback) -> Album.destroy {}, callback
    queue.defer (callback) -> Fabricator.create(Album, 3, {name: Fabricator.uniqueId('album_'), created_at: Fabricator.dateString, updated_at: Fabricator.dateString}, callback)
    queue.await (err) -> callback(null, _.map(_.toArray(arguments).pop(), (test) -> JSONUtils.valueToJSON(test.toJSON())))

# require('backbone-node/lib/test_generators/server_model')(test_parameters)
require('backbone-rest/lib/test_generators/backbone_rest')(test_parameters)
