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

testFn = (options={}) -> (callback) ->
  gutil.log 'Running Node.js tests'
  global.__test__parameters = require './test/parameters' # ensure that globals for the target backend are loaded
  global.__test__app_framework = {factory: (require 'backbone-rest/test/parameters_express4'), name: 'express4'}
  mocha_options = if options.quick then {grep: '@no_options'} else {}
  gulp.src("{node_modules/backbone-#{if options.quick then 'orm' else '{orm,rest}'}/,}test/{issues,spec/sync}/**/*.tests.coffee")
    .pipe(mocha(_.extend({reporter: 'dot'}, mocha_options)))
    .pipe es.writeArray (err) ->
      delete global.__test__parameters # cleanup globals
      callback(err)
      process.exit(0|(!!err))
  return # promises workaround: https://github.com/gulpjs/gulp/issues/455

gulp.task 'test', ['build'], testFn()
gulp.task 'test-quick', ['build'], testFn({quick: true})
gulp.task 'test-quick', [], testFn({quick: true})

# gulp.task 'benchmark', ['build'], (callback) ->
#   (require './test/lib/run_benchmarks')(callback)
#   return # promises workaround: https://github.com/gulpjs/gulp/issues/455
