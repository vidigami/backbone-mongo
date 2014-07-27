[![Build Status](https://travis-ci.org/vidigami/backbone-mongo.svg?branch=develop)](https://travis-ci.org/vidigami/backbone-mongo#master)

![logo](https://github.com/vidigami/backbone-mongo/raw/master/media/logo.png)

BackboneMongo provides MongoDB storage for BackboneORM.

Because BackboneORM's query language is based on MongoDB's query language, many queries just work! With a twist...Backbone.ORM provides cross-collection relationships and embedded data for MongoDB.

In addition, BackboneMongo using CouchDB-style '_rev' versioning to ensure coherency of data.

#### Examples (CoffeeScript)

```coffeescript
class Change extends Backbone.Model
  model_name: 'Change'
  sync: require('backbone-orm').sync(Change)

class Task extends Backbone.Model
  urlRoot: 'mongodb://localhost:27017/tasks'
  schema:
    project: -> ['belongsTo', Project]
    changes: -> ['hasMany', Change, embed: true]
  sync: require('backbone-mongo').sync(Task)

class Project extends Backbone.Model
  urlRoot: 'mongodb://localhost:27017/projects'
  schema:
    tasks: -> ['hasMany', Task]
    changes: -> ['hasMany', Change, embed: true]
  sync: require('backbone-mongo').sync(Project)
```

#### Examples (JavaScript)

```javascript
var Change = Backbone.Model.extend({
  model_name: 'Change',
});
Task.prototype.sync = require('backbone-orm').sync(Change);

var Task = Backbone.Model.extend({
  urlRoot: 'mongodb://localhost:27017/tasks',
  schema: {
    project: function() { return ['belongsTo', Project]; }
    changes: function() { return ['hasMany', Change, {embed: true}]; }
  }
});
Task.prototype.sync = require('backbone-mongo').sync(Task);

var Project = Backbone.Model.extend({
  urlRoot: 'mongodb://localhost:27017/projects',
  schema: {
    tasks: function() { return ['hasMany', Task]; }
    changes: function() { return ['hasMany', Change, {embed: true}]; }
  }
});
Project.prototype.sync = require('backbone-mongo').sync(Project);
```

Please [checkout the website](http://vidigami.github.io/backbone-orm/backbone-mongo.html) for installation instructions, examples, documentation, and community!


### For Contributors

To build the library for Node.js:

```
$ gulp build
```

Please run tests before submitting a pull request:

```
$ gulp test --quick
```

and eventually all tests:

```
$ npm test
```
