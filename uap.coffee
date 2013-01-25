# BPD-CDMS
# Author: Gautham Badhrinathan - b.gautham@gmail.com, fb.com/GotEmB

_ = require "underscore"

methods = [
	"select", "filter"
	"find", "detect"
	"map"
	"any", "all"
	"union", "intersection", "difference"
	"uniq"
	"flatten"
	"each"
	"reduce"
	"first", "last"
]

for method in methods then do (method) ->
	Array.prototype["_#{method}"] = -> _[method] @, arguments...