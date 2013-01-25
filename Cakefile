# BPD-CDMS
# Author: Gautham Badhrinathan - b.gautham@gmail.com, fb.com/GotEmB

{spawn} = require "child_process"

spawnProcess = (prc, args, verbose = true, callback) ->
	isWin = process.platform.match(/^win/)?
	callback ?= (result) -> console.log if result then "Task completed" else "Task failed"
	cp = spawn "#{prc}#{if isWin then ".cmd" else ""}", args, if verbose then stdio: "inherit" else null
	std = out: "", err: ""
	unless verbose
		cp.stdout.on "data", (data) ->
			std.out += data.toString()
		cp.stderr.on "data", (data) ->
			std.err += data.toString()
	cp.on "exit", (code) ->
		if code isnt 0 and !verbose
			process.stdout.write std.out
			process.stderr.write std.err
		callback code is 0

task "run", "build and run 'iced web.coffee'", ->
	spawnProcess "iced", ["web.coffee"], true, (result) ->
		process.exit if result then 0 else 1

task "debug", "run 'iced --nodejs --debug-brk web.coffee", ->
	spawnProcess "foreman", ["start", "-f", "debug"]

task "start", "run 'foreman start'", ->
	spawnProcess "foreman", ["start"]