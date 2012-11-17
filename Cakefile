{spawn} = require "child_process"

spawnProcess = (prc, args, verbose = true, callback) ->
	callback ?= (result) -> console.log if result then "Task completed" else "Task failed"
	cp = spawn prc, args, if verbose then stdio: "inherit" else null
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

task "run", "run 'iced web.coffee'", ->
	spawnProcess "iced", ["web.coffee"]

task "debug", "run 'iced --nodejs --debug-brk web.coffee", ->
	spawnProcess "iced", ["--nodejs", "--debug-brk", "web.coffee"]

task "start", "run 'foreman start'", ->
	spawnProcess "foreman", ["start"]