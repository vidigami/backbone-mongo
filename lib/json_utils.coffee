_ = @_ or require 'underscore'
moment = @moment or require 'moment'

module.exports = class JSONUtils

  @JSONToValue: (json) ->
    return json unless json
    if _.isDate(json)
      return json
    else if _.isString(json) and (json.length > 20) and json[json.length-1] is 'Z'
      date = moment.utc(json)
      return if date and date.isValid() then date.toDate() else json
    else if _.isString(json)
      return json
    else if _.isArray(json)
      return _.map(json, (item) => @JSONToValue(item))
    else if _.isObject(json)
      result = {}
      for key, value of json
        result[key] = @JSONToValue(value)
      return result
    return json

  @valueToJSON: (value) ->
    return value unless value
    if _.isDate(value)
      return value.toISOString()
    else if _.isString(value)
      return value
    else if _.isArray(value)
      return _.map(value, (item) => @valueToJSON(item))
    else if _.isObject(value)
      json = {}
      for key, item of value
        json[key] = @valueToJSON(item)
      return json
    return value