moment = require 'moment'
Backbone = require 'backbone'

class Photo extends Backbone.Model
  defaults: ->
    return {
      created_at: moment.utc().toDate()
    }

module.exports = class ServerPhoto extends Photo
  url: "#{require('../config/database')['test']}/photos"
  sync: require('../../backbone_sync')(ServerPhoto)
