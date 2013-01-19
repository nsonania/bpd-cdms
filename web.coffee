envimport = require "./envimport"
express = require "express"
http = require "http"
socket_io = require "socket.io"
socket_io_client = require "socket.io-client"
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

	socket.on "login", (accessCode, callback) ->
		console.log "Login"
		if accessCode is process.env.ACCESSCODE
			io.sockets.clients()._filter((x) -> x.auth)._each (x) -> x.emit "destroySession"
			socket.auth = true
			callback true
		else
			callback false

	socket.on "getCourses", (callback) ->
		return callback false unless socket.auth?
		console.log "Fetching Courses"
		db.Course.find({}).lean().exec (err, courses) -> callback courses

	socket.on "commitCourses", (courses, callback) ->
		return callback false unless socket.auth?
		console.log "Committing Courses"
		core.commitCourses courses, callback
		ipc?.emit "broadcast", "updatedCourses"

	socket.on "importCourses", (courses, callback) ->
		return callback false unless socket.auth?
		console.log "Importing Courses"
		core.importCourses courses, callback
		ipc?.emit "broadcast", "updatedCourses"

	socket.on "deleteAllCourses", (callback) ->
		return callback false unless socket.auth?
		console.log "Delete All Courses"
		core.deleteAllCourses callback
		ipc?.emit "broadcast", "updatedCourses"

	socket.on "getStudents", (callback) ->
		return callback false unless socket.auth?
		console.log "Fetching Students"
		db.Student.find({}).lean().exec (err, students) -> callback students

	socket.on "commitStudents", (students, callback) ->
		return callback false unless socket.auth?
		console.log "Committing Students"
		core.commitStudents students, callback
		ipc?.emit "broadcast", "updatedStudents"

	socket.on "importStudents", (students, callback) ->
		return callback false unless socket.auth?
		console.log "Importing Students"
		core.importStudents students, callback
		ipc?.emit "broadcast", "updatedStudents"

	socket.on "deleteAllStudents", (callback) ->
		return callback false unless socket.auth?
		console.log "Delete All Students"
		core.deleteAllStudents callback
		ipc?.emit "broadcast", "updatedStudents"

	socket.on "getValidators", (callback) ->
		return callback false unless socket.auth?
		console.log "Fetching Validators"
		db.Validator.find({}).lean().exec (err, validators) -> callback validators

	socket.on "commitValidators", (validators, callback) ->
		return callback false unless socket.auth?
		console.log "Committing Validators"
		core.commitValidators validators, callback
		ipc?.emit "broadcast", "updatedValidators"

	socket.on "importValidators", (validators, callback) ->
		return callback false unless socket.auth?
		console.log "Importing Validators"
		core.importValidators validators, callback
		ipc?.emit "broadcast", "updatedValidators"

	socket.on "deleteAllValidators", (callback) ->
		return callback false unless socket.auth?
		console.log "Delete All Validators"
		core.deleteAllValidators callback
		ipc?.emit "broadcast", "updatedValidators"

	socket.on "getSemester", (callback) ->
		return callback false unless socket.auth?
		console.log "Fetching Semester Details"
		db.Misc.findOne(desc: "Semester Details").lean().exec (err, semester) -> callback semester

	socket.on "commitSemester", (semester, callback) ->
		return callback false unless socket.auth?
		console.log "Committing Semester"
		core.commitSemester semester, callback
		ipc?.emit "broadcast", "updatedSemester"

	socket.on "logout", (callback) ->
		console.log "Logout"
		delete socket.auth
		callback true

ipc = socket_io_client.connect "http://localhost:#{process.env.IPC_PORT}"
ipc.on "connect", ->

	ipc.on "broadcast", (message, data) ->
		# On Broadcast...

server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"