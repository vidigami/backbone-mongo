_ = require 'underscore'
Backbone = require 'backbone'

class Album extends Backbone.Model
  updateCoverPhoto: ->
    @set({cover_photo: (if @get('photos').length then @get('photos').models[0] else null)})
    return @

  updateFeaturedPhotos: ->
    sorted_photos = _.sortBy(@get('photos').models, (test) -> -test.get('created_at').valueOf())
    @set({featured_photos: sorted_photos.splice(0, 8)}) # maximum number featured photos
    return @

module.exports = class ServerAlbum extends Album
  url: "#{require('../config/database')['test']}/albums"
  sync: require('../../backbone_sync')(ServerAlbum)
