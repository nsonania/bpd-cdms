# BPD-CDMS
# Author: Gautham Badhrinathan - b.gautham@gmail.com, fb.com/GotEmB

envimport = require "./envimport"
express = require "express"
http = require "http"
socket_io = require "socket.io"
md5 = require "MD5"
{spawn} = require "child_process"
core = require "./core"
db = require "./db"
fs = require "fs"

expressServer = express()
expressServer.configure ->

	expressServer.use express.bodyParser()
	expressServer.use (req, res, next) ->
		req.url = "/page.html" if req.url is "/"
		next()
	expressServer.use express.static "#{__dirname}/lib", maxAge: 31557600000, (err) -> console.log "Static: #{err}"
	expressServer.use expressServer.router

expressServer.get "/students.csv", (req, res, next) ->
	return res.send 400 unless Number(req.query.cat) in [0..4]
	core.exportStudentsSelections req.query.cat, (body) ->
		res.setHeader "Content-Type", "text/csv"
		res.setHeader "Content-Length", body.length
		res.setHeader "Content-Disposition", "attachment;filename=students.csv"
		res.setHeader "Cache-Control", "no-cache"
		res.end body

expressServer.get "/course.csv", (req, res, next) ->
	db.Course.findOne titles: $elemMatch: compcode: req.query.compcode, (err, course) ->
		return res.send 400 unless course?
		core.exportCourse req.query.compcode, (body) ->
			res.setHeader "Content-Type", "text/csv"
			res.setHeader "Content-Length", body.length
			res.setHeader "Content-Disposition", "attachment;filename=course.csv"
			res.setHeader "Cache-Control", "no-cache"
			res.end body

expressServer.get "/courses.zip", (req, res, next) ->
	core.exportAllCourses (data) ->
		res.setHeader "Content-Type", "application/zip"
		res.setHeader "Content-Disposition", "attachment;filename=courses.zip"
		res.setHeader "Cache-Control", "no-cache"
		res.sendfile data, -> fs.unlink data

server = http.createServer expressServer

io = socket_io.listen server
io.set "log level", 0
io.sockets.on "connection", (socket) ->

	socket.on "login", ([accessCode]..., callback) ->
		console.log "Login"
		if accessCode is process.env.ACCESSCODE
			io.sockets.clients()._filter((x) -> x.auth)._each (x) -> x.emit "destroySession"
			socket.auth = true
			callback? true
		else
			callback? false

	socket.on "getCourses", ([query]..., callback) ->
		return callback false unless socket.auth?
		return callback [] if query in ["", null, undefined]
		db.Course.find(titles: $elemMatch: $or: [{compcode: Number query}, {number: $regex: new RegExp(query, "i")}, {name: $regex: new RegExp(query, "i")}]).limit(20).lean().exec (err, courses) -> callback? courses

	socket.on "getCoursesFor", ([query]..., callback) ->
		return callback false unless socket.auth?
		db.Course.find(query).lean().exec (err, courses) -> callback? courses

	socket.on "importCourses", ([courses]..., callback) ->
		return callback false unless socket.auth?
		console.log "Importing Courses"
		core.importCourses courses, callback

	socket.on "deleteAllCourses", (callback) ->
		return callback false unless socket.auth?
		console.log "Delete All Courses"
		core.deleteAllCourses callback

	socket.on "setSectionCapacity", (course_id, number, type, capacity) ->
		return unless socket.auth?
		db.Course.findById course_id, (err, course) ->
			sections = course.get(type)
			sections._find((x) -> x.number is number).capacity = capacity
			course.markModified type
			course.save -> console.log "Modified Section Capacity"

	socket.on "getStudent", ([query]..., callback) ->
		return callback false unless socket.auth?
		db.Student.findOne(query).lean().exec (err, student) -> callback? student

	socket.on "commitStudent", ([student]..., callback) ->
		return callback false unless socket.auth?
		console.log "Committing Student: #{student.studentId}"
		db.Student.findOneAndUpdate {studentId: student.studentId}, {$set: student}, (err) -> callback? !err?

	socket.on "importStudents", ([students]..., callback) ->
		return callback false unless socket.auth?
		console.log "Importing Students"
		core.importStudents students, callback

	socket.on "deleteAllStudents", (callback) ->
		return callback false unless socket.auth?
		console.log "Delete All Students"
		core.deleteAllStudents callback

	socket.on "getValidatorById", ([query]..., callback) ->
		return callback false unless socket.auth?
		db.Validator.findById(query).lean().exec (err, validator) -> callback? validator

	socket.on "getValidators", ([query]..., callback) ->
		return callback false unless socket.auth?
		return callback [] if query in ["", null, undefined]
		db.Validator.find($or: [{username: $regex: new RegExp(query, "i")}, {name: $regex: new RegExp(query, "i")}]).sort("username").limit(20).lean().exec (err, validators) -> callback? validators

	socket.on "commitValidators", ([validators]..., callback) ->
		return callback false unless socket.auth?
		console.log "Committing Validators"
		core.commitValidators validators, callback

	socket.on "importValidators", ([validators]..., callback) ->
		return callback false unless socket.auth?
		console.log "Importing Validators"
		core.importValidators validators, callback

	socket.on "deleteAllValidators", (callback) ->
		return callback false unless socket.auth?
		console.log "Delete All Validators"
		core.deleteAllValidators callback

	socket.on "getSemester", (callback) ->
		return callback false unless socket.auth?
		console.log "Fetching Semester Details"
		db.Misc.findOne(desc: "Semester Details").lean().exec (err, semester) -> callback? semester

	socket.on "commitSemester", ([semester]..., callback) ->
		return callback false unless socket.auth?
		console.log "Committing Semester"
		core.commitSemester semester, callback

	socket.on "getStats", (callback) ->
		return callback false unless socket.auth?
		core.getStats callback

	socket.on "logout", (callback) ->
		console.log "Logout"
		delete socket.auth
		callback? true

server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"