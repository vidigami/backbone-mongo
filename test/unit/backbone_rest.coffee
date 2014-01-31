express = require 'express'

module.exports = (options, callback) ->
  test_parameters =
    database_url: require('../config/database')['test']
    schema: {}
    sync: require('../../lib/sync')
    embed: true
    app_factory: -> app = express(); app.use(express.bodyParser()); app

  require('backbone-rest/test/generators/all')(test_parameters, callback)
