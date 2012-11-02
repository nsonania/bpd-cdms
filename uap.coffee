_ = require "underscore"

methods = [
	"select", "filter"
	"find", "detect"
	"map", "detect"
	"any", "all"
	"union", "intersection", "difference"
]

for method in methods
	Array.prototype[method] = -> _[method] @, arguments...