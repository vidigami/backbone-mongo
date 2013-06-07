_ = require 'underscore'
Queue = require 'queue-async'

Photo = require '../models/photo'

adapters =
  bbCallback: (callback) -> return {success: ((model) -> callback(null, model)), error: (-> callback(new Error("failed")))}

module.exports = class PhotosFabricator
  @create: (count, callback) ->
    queue = new Queue()
    while(count-- > 0)
      do -> queue.defer (callback) -> (new Photo({name: _.uniqueId('photo_')})).save {}, adapters.bbCallback callback
    queue.await callback
