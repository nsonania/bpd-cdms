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

	socket.on "getCourses", (callback) ->
		callback false unless socket.auth?
		console.log "Fetching Courses"
		db.Course.find({}).lean().exec (err, courses) -> callback courses

	socket.on "commitCourses", (courses, callback) ->
		callback false unless socket.auth?
		console.log "Committing Courses"
		core.commitCourses courses, callback

	socket.on "importCourses", (courses, callback) ->
		callback false unless socket.auth?
		console.log "Importing Courses"
		core.importCourses courses, callback

	socket.on "deleteAllCourses", (callback) ->
		callback false unless socket.auth?
		console.log "Delete All Courses"
		core.deleteAllCourses callback

	socket.on "getStudents", (callback) ->
		callback false unless socket.auth?
		console.log "Fetching Students"
		db.Student.find({}).lean().exec (err, students) -> callback students

	socket.on "commitStudents", (students, callback) ->
		callback false unless socket.auth?
		console.log "Committing Students"
		core.commitStudents students, callback

	socket.on "importStudents", (students, callback) ->
		callback false unless socket.auth?
		console.log "Importing Students"
		core.importStudents students, callback

	socket.on "deleteAllStudents", (callback) ->
		callback false unless socket.auth?
		console.log "Delete All Students"
		core.deleteAllStudents callback

	socket.on "getSemester", (callback) ->
		callback false unless socket.auth?
		console.log "Fetching Semester Details"
		db.Misc.findOne(desc: "Semester Details").lean().exec (err, semester) -> callback semester

	socket.on "commitSemester", (semester, callback) ->
		callback false unless socket.auth?
		console.log "Committing Semester"
		core.commitSemester semester, callback

	socket.on "login", (accessCode, authText, callback) ->
		socket.auth = true
		console.log "Login"
		callback do ->
			if accessCode is process.env.ACCESSCODE and authText is process.env.AUTHTEXT
				true
			else
				false

	socket.on "logout", (callback) ->
		console.log "Logout"
		delete socket.auth
		callback true

server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"