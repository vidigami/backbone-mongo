Queue = require 'backbone-orm/lib/queue'

ModelTypeID = require('backbone-orm/lib/cache/singletons').ModelTypeID
ModelTypeID.strict = false

option_sets = require('backbone-orm/test/option_sets')
# option_sets = option_sets.slice(0, 1)

test_queue = new Queue(1)
for options in option_sets
  do (options) -> test_queue.defer (callback) ->
    console.log '\nBackbone Mongo: Running tests with options:\n', options
    queue = new Queue(1)
    queue.defer (callback) -> require('./unit/backbone_orm')(options, callback)
    queue.defer (callback) -> require('./unit/backbone_rest')(options, callback)
    queue.defer (callback) -> require('./unit/ids')(options, callback)
    queue.defer (callback) -> require('./unit/dynamic_attributes')(options, callback)
    queue.await callback

# test_queue.defer (callback) -> require('./issues/issue3')({}, callback)

test_queue.await (err) -> console.log 'Backbone Mongo: Completed tests'
