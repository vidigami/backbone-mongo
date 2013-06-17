util = require 'util'
_ = require 'underscore'
Backbone = require 'backbone'
Queue = require 'queue-async'

JSONUtils = require 'backbone-orm/lib/json_utils'
Fabricator = require 'backbone-orm/fabricator'

module.exports = class Album extends Backbone.Model
  url: "#{require('../config/database')['test']}/albums"
  sync: require('../../backbone_sync')(Album, true)

test_parameters =
  model_type: Album
  route: 'albums'
  beforeEach: (callback) ->
    queue = new Queue(1)
    queue.defer (callback) -> Album.destroy callback
    queue.defer (callback) -> Fabricator.create(Album, 10, {
      name: Fabricator.uniqueId('album_')
      created_at: Fabricator.date
      updated_at: Fabricator.date
    }, callback)
    queue.await (err) -> callback(null, _.map(_.toArray(arguments).pop(), (test) -> JSONUtils.valueToJSON(test.toJSON())))

require('backbone-orm/lib/test_generators/all_flat')(test_parameters)
require('backbone-rest/lib/test_generators/all')(test_parameters)
