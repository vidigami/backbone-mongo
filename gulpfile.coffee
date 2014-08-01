_ = require 'underscore'
es = require 'event-stream'

gulp = require 'gulp'
gutil = require 'gulp-util'
coffee = require 'gulp-coffee'
mocha = require 'gulp-mocha'

gulp.task 'build', buildLibraries = ->
  return gulp.src('./src/**/*.coffee')
    .pipe(coffee({header: true})).on('error', gutil.log)
    .pipe(gulp.dest('./lib'))

gulp.task 'watch', ['build'], (callback) ->
  return gulp.watch './src/**/*.coffee', -> buildLibraries()

gulp.task 'test', ['build'], (callback) ->
  tags = ("@#{tag.replace(/^[-]+/, '')}" for tag in process.argv.slice(3)).join(' ')
  gutil.log "Running Node.js tests #{tags}"

  global.__test__parameters = require './test/parameters' # ensure that globals for the target backend are loaded
  global.__test__app_framework = {factory: (require 'backbone-rest/test/parameters_express4'), name: 'express4'}
  files = [
    "{node_modules/backbone-#{if tags.indexOf('@quick') >= 0 then 'orm' else '{orm,rest}'}/,}test/{issues,spec/sync}/**/*.tests.coffee"
    "test/**/*.tests.coffee"
  ]
  gulp.src(files)
    .pipe(mocha({reporter: 'dot', grep: tags}))
    .pipe es.writeArray (err) ->
      delete global.__test__parameters # cleanup globals
      callback(err)
      process.exit(0|(!!err))
  return # promises workaround: https://github.com/gulpjs/gulp/issues/455

# gulp.task 'benchmark', ['build'], (callback) ->
#   (require './test/lib/run_benchmarks')(callback)
#   return # promises workaround: https://github.com/gulpjs/gulp/issues/455
