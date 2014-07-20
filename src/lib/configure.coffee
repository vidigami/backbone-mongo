{_} = BackboneORM = require 'backbone-orm'
superConfigure = BackboneORM.configure

BackboneMongo = require '../core'

# set up defaults
BackboneMongo.connection_options = {}

module.exports = configure = (options) ->
  _.extend(BackboneMongo.connection_options, options.connection_options) if options.connection_options

  superConfigure(options)