_ = require 'underscore'
CollectionQuery = require './collection_query'

HTTP_ERRORS =
  INTERNAL_SERVER: 500

module.exports = class BackboneRESTMongo

  # params
  #  route
  #  collection
  @bindControllers: (app, bind_options, collection_info) ->
    route = collection_info.route
    model_type = collection_info.model

    # index
    app.get route, (req, res) ->
      # TODO: sanitize query - white list
      db_query = new CollectionQuery(model_type, model_type.parseRequestQuery(req))
      db_query.toJSON (err, json) ->
        return res.status(HTTP_ERRORS.INTERNAL_SERVER).send() if err
        res.json(json)

    # create
    app.post route, (req, res) ->
      model = new model_type()
      model.set(_.defaults(model.parse(req.body)))

      bind_options.create?(model) # customization hooks
      model.save({}, {
        success: -> res.json(model.toJSON())
        error: -> res.status(HTTP_ERRORS.INTERNAL_SERVER).send()
      })

    # show
    app.get "#{route}/:id", (req, res) ->
      model_type.findOne {id: req.params.id}, (err, model) ->
        return res.status(HTTP_ERRORS.INTERNAL_SERVER).send() if err

        bind_options.show?(model) # customization hooks
        res.json(model.toJSON())

    # update
    app.put "#{route}/:id", (req, res) ->
      model_type.findOne {id: req.params.id}, (err, model) ->
        return res.status(HTTP_ERRORS.INTERNAL_SERVER).send() if err

        bind_options.update?(model) # customization hooks
        model.save(model.parse(req.body), {
          success: -> res.json(model.toJSON())
          error: -> res.status(HTTP_ERRORS.INTERNAL_SERVER).send()
        })

    # delete
    app.del "#{route}/:id", (req, res) ->
      model_type.findOne {id: req.params.id}, (err, model) ->
        return res.status(HTTP_ERRORS.INTERNAL_SERVER).send() if err

        id = model.get('id')
        bind_options.delete?(model) # customization hooks
        model.destroy({
          success: -> res.json({ok: true, id: id})
          error: -> res.status(HTTP_ERRORS.INTERNAL_SERVER).send()
        })

    # allow cross-origin
    app.all route, (req, res, next) ->
      res.set('Access-Control-Allow-Origin', bind_options.origins)
      res.set('Access-Control-Allow-Headers', 'X-Requested-With,CONTENT-TYPE')
      res.set('Access-Control-Allow-Methods', 'GET,POST,PUT')
      next()
    app.all "#{route}/:id", (req, res, next) ->
      res.set('Access-Control-Allow-Origin', bind_options.origins)
      res.set('Access-Control-Allow-Headers', 'X-Requested-With,CONTENT-TYPE')
      res.set('Access-Control-Allow-Methods', 'GET,PUT,DELETE')
      next()
