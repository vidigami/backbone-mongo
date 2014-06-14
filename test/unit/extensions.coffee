Queue = require 'backbone-orm/lib/queue'

module.exports = (options, callback) ->
  test_parameters =
    database_url: require('../config/database')['test']
    schema: {}
    sync: require('../../lib/sync')
    embed: true

  queue = new Queue(1)
  # queue.defer (callback) -> (require '../generators/database_tools')(test_parameters, callback)
  # queue.defer (callback) -> (require '../generators/dynamic_attributes')(test_parameters, callback)
  queue.defer (callback) -> (require '../generators/ids')(test_parameters, callback)
  queue.await callback
