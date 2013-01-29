# BPD-CDMS
# Author: Gautham Badhrinathan - b.gautham@gmail.com, fb.com/GotEmB

envimport = require "./envimport"
express = require "express"
http = require "http"
socket_io = require "socket.io"
socket_io_client = require "socket.io-client"
md5 = require "MD5"
{spawn} = require "child_process"
db = require "./db"
pdfExport = require "./pdfExport"

expressServer = express()
expressServer.configure ->

	expressServer.use express.bodyParser()
	expressServer.use (req, res, next) ->
		req.url = "/page.html" if req.url is "/"
		next()
	expressServer.use expressServer.router
	expressServer.use express.static "#{__dirname}/lib", maxAge: 31557600000, (err) -> console.log "Static: #{err}"

expressServer.get "/rc/:studentId", (req, res, next) ->
	nxt = =>
		req.url = "/rc_#{req.params.studentId}.pdf"
		next()
	return nxt() if req.headers.range?
	pdfRC req.params.studentId, (err) =>
		if err?
			res.send "404", err
		else
			nxt()

server = http.createServer expressServer

pdfRC = (studentId, callback) ->
	db.Misc.findOne desc: "Semester Details", (err, semester) ->
		return callback("Semester Not Open") unless semester?
		db.Student.findOne studentId: studentId, (err, student) ->
			return callback("Student not found or student not registered yet") unless student?
			db.Course.find titles: $elemMatch: compcode: $in: (student.get("selectedcourses") ? [])._map((x) -> x.compcode), (err, courses) ->
				data =
					studentId: student.get "studentId"
					studentName: student.get "name"
					semesterTitle: semester.get "title"
					registeredDate: student.get "registeredOn"
					courses: (student.get("selectedcourses") ? [])._map (selcourse) ->
						compcode: selcourse.compcode
						number: courses?._map((x) -> x.get "titles")._flatten(1)._find((x) -> x.compcode is selcourse.compcode)?.number
						name: courses?._map((x) -> x.get "titles")._flatten(1)._find((x) -> x.compcode is selcourse.compcode)?.name
						lecture: selcourse.selectedLectureSection
						lab: selcourse.selectedLabSection
						type:
							if student.get("bc")?.indexOf(selcourse.compcode) >= 0
								"BC"
							else if student.get("psc")?.indexOf(selcourse.compcode) >= 0
								"PSC"
							else
								"EL"
				pdfExport.generateRC data, callback

io = socket_io.listen server
io.set "log level", 0
io.sockets.on "connection", (socket) ->

	socket.on "getStudents", (query, callback) ->
		return callback false unless socket.auth?
		return callback [] if query in ["", null, undefined]
		db.Student.find($or: [{studentId: $regex: new RegExp(query, "i")}, {name: $regex: new RegExp(query, "i")}]).limit(30).lean().exec (err, students) -> callback students

	socket.on "login", (username, password, callback) ->
		db.Validator.findOne username: username, password: password, (err, authInfo) ->
			return callback false unless authInfo?
			io.sockets.clients()._filter((x) -> x isnt socket and x.auth? and x.auth._id.equals authInfo.get("_id"))._each (x) ->
				console.log "#{x.auth} remotely logged out."
				x.emit "destroySession"
				delete x.auth
			socket.auth =
				_id: authInfo.get "_id"
				username: authInfo.get "username"
			console.log "#{socket.auth.username} logged in."
			callback
				username: authInfo.get "username"
				name: authInfo.get "name"

	socket.on "logout", (callback) ->
		return callback false unless socket.auth?
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
			io.sockets.clients()._filter((x) -> x isnt socket).emit "studentStatusChanged", student_id, "validated", true
			ipc?.emit "broadcast", "studentStatusChanged", [student_id, "validated", true]

ipc = socket_io_client.connect "http://localhost:#{process.env.IPC_PORT}"
ipc.on "connect", ->

	ipc.on "broadcast", (message, data) ->
		if message is "studentStatusChanged"
			io.sockets.emit "studentStatusChanged", data...

server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"

setInterval ->
	db.Misc.findOneAndUpdate desc: "Stats", {currentValidators: io.sockets.clients()._filter((x) -> x.auth).length}, {upsert: true}, (err) ->
, 1000
