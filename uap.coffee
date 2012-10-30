_ = require "underscore"

methods = [
	"select", "filter"
	"find"
	"map", "detect"
]

for method in methods
	Array.prototype[method] = -> _[method] @, arguments...