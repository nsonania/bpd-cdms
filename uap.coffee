_ = require "underscore"

methods = [
	"select", "filter"
	"find", "detect"
	"map"
	"any", "all", "contains"
	"union", "intersection", "difference"
	"uniq"
	"flatten", "groupBy"
	"each"
]

for method in methods then do (method) ->
	Array.prototype["_#{method}"] = -> _[method] @, arguments...