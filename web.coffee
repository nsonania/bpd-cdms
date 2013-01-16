envimport = require "./envimport"
express = require "express"
http = require "http"
socket_io = require "socket.io"
md5 = require "MD5"
{spawn} = require "child_process"
core = require "./core"
db = require "./db"

cp = spawn "cake", ["build"]
await cp.on "exit", defer code
return console.log "Build failed! Run 'cake build' to display build errors." if code isnt 0

expressServer = express()
expressServer.configure ->

	expressServer.use express.bodyParser()
	expressServer.use (req, res, next) ->
		req.url = "/page.html" if req.url is "/"
		next()
	expressServer.use express.static "#{__dirname}/lib", maxAge: 31557600000, (err) -> console.log "Static: #{err}"
	expressServer.use expressServer.router

server = http.createServer expressServer

io = socket_io.listen server
io.set "log level", 0
io.sockets.on "connection", (socket) ->

	socket.on "getStudents", (callback) ->
		return callback false unless socket.auth?
		console.log "Fetching Students for #{socket.auth.username}."
		db.Student.find({}).lean().exec (err, students) -> callback students

	socket.on "login", (username, password, callback) ->
		db.Validator.findOne username: username, password: md5(password), (err, authInfo) ->
			return callback false unless authInfo?
			io.sockets.clients()._filter((x) -> x.auth is socket.auth and x isnt socket)._each (x) ->
				console.console.log "#{x.auth} remotely logged out."
				x.emit "destroySession"
				delete x.auth
			socket.auth =
				_id: authInfo.get "_id"
				username: authInfo.get "username"
			console.log "#{socket.auth.username} logged in."
			callback true

	socket.on "logout", (callback) ->
		console.log "#{socket.auth.username} logged out."
		delete socket.auth
		callback true

	socket.on "validate", (student_id, callback) ->
		return callback false unless socket.auth?
		db.Student.findById student_id, (err, student) ->
			return callback false unless student?
			return callback false if student.get "validated"
			console.log "#{student.get("name")} validated by #{socket.auth.username}."
			student.set "validated", true
			student.set "validatedBy", socket.auth._id
			student.markModified "validated"
			student.markModified "validatedBy"
			student.save()
			callback true

server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"