# BPD-CDMS
# Author: Gautham Badhrinathan - b.gautham@gmail.com, fb.com/GotEmB

envimport = require "./envimport"
express = require "express"
http = require "http"
socket_io = require "socket.io"
socket_io_client = require "socket.io-client"
md5 = require "MD5"
{spawn} = require "child_process"
core = require "./core"
db = require "./db"

expressServer = express()
expressServer.configure ->

	expressServer.use express.bodyParser()
	expressServer.use (req, res, next) ->
		req.url = "/page.html" if req.url is "/"
		next()
	expressServer.use express.static "#{__dirname}/lib", maxAge: 31557600000, (err) -> console.log "Static: #{err}"
	expressServer.use expressServer.router

expressServer.get "/students.csv", (req, res, next) ->
	core.exportStudentsSelections req.query.cat, (body) ->
		res.setHeader "Content-Type", "text/csv"
		res.setHeader "Content-Length", body.length
		res.setHeader "Content-Disposition", "attachment;filename=students.csv"
		res.setHeader "Cache-Control", "no-cache"
		res.end body

expressServer.get "/course.csv", (req, res, next) ->
	core.exportCourse req.query.compcode, (body) ->
		res.setHeader "Content-Type", "text/csv"
		res.setHeader "Content-Length", body.length
		res.setHeader "Content-Disposition", "attachment;filename=course.csv"
		res.setHeader "Cache-Control", "no-cache"
		res.end body

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

	socket.on "getCourses", (query, callback) ->
		return callback false unless socket.auth?
		return callback [] if query in ["", null, undefined]
		db.Course.find(titles: $elemMatch: $or: [{compcode: Number query}, {number: $regex: new RegExp(query, "i")}, {name: $regex: new RegExp(query, "i")}]).limit(20).lean().exec (err, courses) -> callback courses

	socket.on "getCoursesAll", (studentId, cat, query, callback) ->
		return callback false unless socket.auth?
		q1 = []
		switch cat
			when 0
				q1 = []
			when 1
				await db.Student.findOne studentId: studentId, defer err, student
				q1 = [student.get("bc") ? [], student.get("psc") ? [], student.get("el") ? []]._flatten(1)
			when 2
				await db.Student.findOne studentId: studentId, defer err, student
				q1 = (student.get("selectedcourses") ? [])._map (x) -> x.compcode
		db.Course.find(titles: $elemMatch: $or: [{compcode: Number query}, {number: $regex: new RegExp(query, "i")}, {name: $regex: new RegExp(query, "i")}]).lean().exec (err, courses) ->
			callback courses._filter((x) -> x.titles._any (y) -> y.compcode in q1 or cat is 0)._take(20)

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

	socket.on "getStudents", (filter, query, callback) ->
		return callback false unless socket.auth?
		return callback [] if query in ["", null, undefined] and filter is 0
		query = ".*" if query in ["", null, undefined]
		$or = [
			{studentId: $regex: new RegExp(query, "i")}
			{name: $regex: new RegExp(query, "i")}
		]
		mq = 
			switch filter
				when 0 then db.Student.find $or: $or
				when 1 then db.Student.find $or: $or, registered: $ne: true
				when 2 then db.Student.find $or: $or, registered: true, validated: $ne: true
				when 3 then db.Student.find $or: $or, validated: true
				when 4 then db.Student.find $or: $or, difficultTimetable: true
		mq.sort("studentId").limit(20).lean().exec (err, students) -> callback students

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

	socket.on "getValidators", (query, callback) ->
		return callback false unless socket.auth?
		return callback [] if query in ["", null, undefined]
		db.Validator.find($or: [{username: $regex: new RegExp(query, "i")}, {name: $regex: new RegExp(query, "i")}]).sort("username").limit(20).lean().exec (err, validators) -> callback validators

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

	socket.on "getStats", (callback) ->
		return callback false unless socket.auth?
		core.getStats callback

	socket.on "logout", (callback) ->
		console.log "Logout"
		delete socket.auth
		callback true

ipc = socket_io_client.connect "http://localhost:#{process.env.IPC_PORT}"
ipc.on "connect", ->

	ipc.on "broadcast", (message, data) ->
		# On Broadcast...

server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"