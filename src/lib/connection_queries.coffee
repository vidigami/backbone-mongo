###
  backbone-mongo.js 0.6.5
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-mongo
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

module.exports = [
  'slaveOk', 'slave_ok'
  'maxPoolSize', 'poolSize'
  'autoReconnect', 'auto_reconnect'
  'ssl'
  'replicaSet', 'rs_name'
  'reconnectWait'
  'retries'
  'readSecondary', 'read_secondary'
  'fsync'
  'journal'
  'safe'
  'nativeParser', 'native_parser'
  'connectTimeoutMS', 'socketTimeoutMS'
  'w'
  'authSource'
  'wtimeoutMS'
  'readPreference'
  'readPreferenceTags'

  # unsupported
  # 'minPoolSize', 'maxIdleTimeMS', 'waitQueueMultiple', 'waitQueueTimeoutMS', 'uuidRepresentation'
]
