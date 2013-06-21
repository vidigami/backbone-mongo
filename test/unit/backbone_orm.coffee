test_parameters =
  database_url: require('../config/database')['test']
  schema: {}
  sync: require('../../sync')
  embed: true

require('backbone-orm/test/generators/all')(test_parameters)
