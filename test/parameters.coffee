global.__test__parameters = module.exports =
  database_url: require('./config/database')['test']
  sync: require('../').sync
  $parameter_tags: '@mongo_sync '
  dummy_id: '000000000000000000000000'
  dummy_id_2: '000000000000000000000001'
