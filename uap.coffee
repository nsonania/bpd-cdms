# BPD-CDMS
# Author: Gautham Badhrinathan - b.gautham@gmail.com, fb.com/GotEmB

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
	"sortBy"
]

for method in methods then do (method) ->
	Array.prototype["_#{method}"] = -> _[method] @, arguments...