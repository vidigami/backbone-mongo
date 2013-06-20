test_parameters =
  database_url: require('../config/database')['test']
  schema: {}
  sync: require('../../backbone_sync')
  embed: true

require('backbone-rest/test/generators/all')(test_parameters)
