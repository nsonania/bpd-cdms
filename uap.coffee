_ = require "underscore"

methods = [
	"select", "filter"
	"find", "detect"
	"map"
	"any", "all"
	"union", "intersection", "difference"
]

for method in methods then do (method) ->
	Array.prototype["_#{method}"] = -> _[method] @, arguments...