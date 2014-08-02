###
  backbone-mongo.js 0.6.2
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-mongo
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

{_, Backbone} = BackboneORM = require 'backbone-orm'

module.exports = BackboneMongo = require './core' # avoid circular dependencies
publish =
  configure: require './lib/configure'
  sync: require './sync'

  _: _
  Backbone: Backbone
_.extend(BackboneMongo, publish)

# re-expose modules
BackboneMongo.modules = {'backbone-orm': BackboneORM}
BackboneMongo.modules[key] = value for key, value of BackboneORM.modules
