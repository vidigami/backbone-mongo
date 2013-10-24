Queue = require 'queue-async'

option_sets = require('backbone-orm/test/option_sets')

test_queue = new Queue(1)
for options in option_sets
  do (options) -> test_queue.defer (callback) ->
    console.log '\nBackbone Mongo: Running tests with options:\n', options
    queue = new Queue(1)
    queue.defer (callback) -> require('./unit/backbone_orm')({}, callback)
    queue.defer (callback) -> require('./unit/backbone_rest')({}, callback)
    queue.defer (callback) -> require('./unit/ids')({}, callback)
    queue.defer (callback) -> require('./unit/dynamic_attributes')({}, callback)
    queue.await callback
test_queue.await (err) -> console.log 'Backbone Mongo: Completed tests'
