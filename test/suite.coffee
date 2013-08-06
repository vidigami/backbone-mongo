Queue = require 'queue-async'

queue = new Queue(1)
queue.defer (callback) -> require('./unit/backbone_orm')({}, callback) # TODO
queue.defer (callback) -> require('./unit/backbone_rest')({}, callback) # TODO
queue.defer (callback) -> require('./unit/ids')({}, callback)
queue.defer (callback) -> require('./unit/dynamic_attributes')({}, callback)
queue.await (err) -> console.log "Backbone Mongo: Completed tests"
