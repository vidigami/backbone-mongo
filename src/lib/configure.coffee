{_} = BackboneORM = require 'backbone-orm'
BackboneMongo = require '../core'

# set up defaults
BackboneMongo.connection_options = {}

module.exports = (options) ->
  _.extend(BackboneMongo.connection_options, options.connection_options) if options.connection_options
  BackboneORM.configure(_.omit(options, 'connection_options'))
