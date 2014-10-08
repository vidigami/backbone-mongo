Please refer to the following release notes when upgrading your version of BackboneORM.

### 0.6.6
* $unique does not work properly with $page: https://github.com/vidigami/backbone-mongo/issues/14

### 0.6.5
* Upgrade to BackboneORM 0.7.x

### 0.6.4
* Better errors for failed connections

### 0.6.3
* Bug fix for join tables

### 0.6.2
* Added dynamic and manual_ids capabilities

### 0.6.1
* Added unique capability

### 0.6.0
* Upgraded to BackboneORM 0.6.x
* See [upgrade notes](https://github.com/vidigami/backbone-mongo/blob/master/UPGRADING.md) for upgrading pointers from 0.5.x
* BREAKING: moved connection_options to a configure function

### 0.5.9
* Added database indexing through database tools (Model.db().ensureSchema(callback) or Model.db().resetSchema(callback))

### 0.5.8
* Update dependencies

### 0.5.7
* Bug fix for RegEx

### 0.5.6
* Added support for Mongo's '$or', '$nor', '$and'. Currently, backbone-mongo-only

### 0.5.5
* Bug fix for multiple unset: https://github.com/vidigami/backbone-mongo/issues/7
* Bug fix for sort on id: https://github.com/vidigami/backbone-mongo/issues/8

### 0.5.4
* Compatability fix for Backbone 1.1.1

### 0.5.3
* Lock Backbone.js to 1.1.0 until new release compatibility issues fixed

### 0.5.2
* Added handling of $one and $values
* Added handling of all operators for ids

### 0.5.1
* Added handling of $nin
* Added a more robust reconnection scheme

### 0.5.0
* Initial release

