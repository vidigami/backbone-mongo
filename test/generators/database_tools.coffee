util = require 'util'
assert = require 'assert'

BackboneORM = require 'backbone-orm'
{_, Backbone, Queue} = BackboneORM

module.exports = (options, callback) ->
  DATABASE_URL = options.database_url or ''
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync

  class Flat extends Backbone.Model
    urlRoot: "#{DATABASE_URL}/flats"
    schema: _.extend BASE_SCHEMA,
      a_string: 'String'
    sync: SYNC(Flat)

  class Reverse extends Backbone.Model
    urlRoot: "#{DATABASE_URL}/reverses"
    schema: _.defaults({
      owner: -> ['belongsTo', Owner]
      another_owner: -> ['belongsTo', Owner, as: 'more_reverses']
      many_owners: -> ['hasMany', Owner, as: 'many_reverses']
    }, BASE_SCHEMA)
    sync: SYNC(Reverse)

  class Owner extends Backbone.Model
    urlRoot: "#{DATABASE_URL}/owners"
    schema: _.defaults({
      a_string: 'String'
      flats: -> ['hasMany', Flat]
      reverses: -> ['hasMany', Reverse]
      more_reverses: -> ['hasMany', Reverse, as: 'another_owner']
      many_reverses: -> ['hasMany', Reverse, as: 'many_owners']
    }, BASE_SCHEMA)
    sync: SYNC(Owner)

  describe "Sql db tools", ->

    before (done) -> return done() unless options.before; options.before([Flat], done)
    after (done) -> callback(); done()
    beforeEach (done) ->
      queue = new Queue(1)
      for model_type in [Flat, Reverse, Owner]
        do (model_type) -> queue.defer (callback) -> model_type.db().dropTable callback
      queue.await done

    it 'Can ensure many to many models schemas', (done) ->
      reverse_db = Reverse.db()
      owner_db = Owner.db()

      drop_queue = new Queue(1)

      drop_queue.defer (callback) ->
        reverse_db.dropTable (err) ->
          assert.ok(!err, "No errors: #{err}")
          callback()

      drop_queue.defer (callback) ->
        owner_db.dropTable (err) ->
          assert.ok(!err, "No errors: #{err}")
          callback()

      drop_queue.await (err) ->
        assert.ok(!err, "No errors: #{err}")

        queue = new Queue(1)

        queue.defer (callback) ->
          reverse_db.ensureSchema (err) ->
            assert.ok(!err, "No errors: #{err}")
            callback()

        queue.defer (callback) ->
          owner_db.ensureSchema (err) ->
            assert.ok(!err, "No errors: #{err}")
            callback()

        queue.await (err) ->
          assert.ok(!err, "No errors: #{err}")
          # owner_db.hasColumn 'a_string', (err, has_column) ->
          #   assert.ok(!err, "No errors: #{err}")
          #   assert.ok(has_column, "Has the test column: #{has_column}")
          done()
