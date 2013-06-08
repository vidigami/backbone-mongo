_ = require 'underscore'
Queue = require 'queue-async'

Album = require '../models/album'

adapters =
  bbCallback: (callback) -> return {success: ((model) -> callback(null, model)), error: ((err)-> callback(err or new Error('Backbone operation failed')))}

module.exports = class AlbumsFabricator
  @create: (count, callback) ->
    queue = new Queue()
    while(count-- > 0)
      do -> queue.defer (callback) -> (new Album({name: _.uniqueId('album_')})).save {}, adapters.bbCallback callback
    queue.await callback
