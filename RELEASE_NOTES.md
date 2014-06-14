Please refer to the following release notes when upgrading your version of BackboneORM.

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

