_ = require 'underscore'
Query = require './query'

HTTP_ERRORS =
  INTERNAL_SERVER: 500

bindRoute = (app, url, bind_options={}) ->
  app.all url, (req, res, next) ->
    res.set 'Access-Control-Allow-Origin', bind_options.origins if bind_options.origins
    res.header 'Access-Control-Allow-Headers', 'X-Requested-With,Content-Disposition,Content-Type,Content-Description,Content-Range'
    res.header 'Access-Control-Allow-Methods', 'HEAD, GET, POST, PUT, DELETE, OPTIONS'
    res.header('Access-Control-Allow-Credentials', 'true')

    # TODO: why did options return 404 when switched to express 3.1.0 from 3.0.0rc1
    return res.send(200) if req.method.toLowerCase() is 'options'

    next()

module.exports = class RESTController

  # params
  #  route
  #  collection
  @bind: (app, bind_options, collection_info) ->
    route = collection_info.route
    model_type = collection_info.model

    bindRoute(app, url, bind_options) for url in [route, "#{route}/:id"]

    # index
    app.get route, (req, res) ->
      # TODO: sanitize query - white list
      db_query = new Query(model_type, model_type.parseRequestQuery(req))
      db_query.toJSON (err, json) ->
        return res.status(HTTP_ERRORS.INTERNAL_SERVER).send() if err
        res.json(json)

    # create
    app.post route, (req, res) ->

      model = new model_type()
      model.set(model.parse(req.body))

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