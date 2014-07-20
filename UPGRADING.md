### From 0.5.x to 0.6.0

1. All references to require('backbone-mongo').connection_options should be replaced with configure.

```
# change
_.extend(require('backbone-mongo').connection_options, options)

# to
require('backbone-mongo').configure(options)
```
