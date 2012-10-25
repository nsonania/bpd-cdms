express = require "express"
http = require "http"
socket_io = require "socket.io"
md5 = require "MD5"
{spawn} = require "child_process"
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

	socket.on "login", (data, callback) ->
		db.Student.findOne studentId: data.studentId.toUpperCase(), password: data.password, (err, student) ->
			return callback success: false unless student?
			socket.set "studentId", student.get("studentId"), (err) ->
				callback
					success: true
					student:
						studentId: student.get "studentId"
						name: student.get "name"

	socket.on "initializeSectionsScreen", (callback) ->
		socket.get "studentId", (err, studentId) ->
			return callback success: false unless studentId?
			db.Student.findOne studentId: studentId, (err, student) ->
				db.Course.find().where("_id").in(x.course for x in student.get("selectedcourses")).lean().exec (err, selectedcourses) ->
					callback
						success: true
						selectedcourses:
							for course in selectedcourses
								compcode: course.compcode
								number: course.number
								name: course.name
								isProject: course.isProject
								hasLectures: course.hasLectures
								hasLab: course.hasLab
								lectureSections: if course.hasLectures then number: section.number, instructor: section.instructor for section in course.lectureSections
								labSections: if course.hasLab then number: section.number, instructor: section.instructor for section in course.labSections
								selectedLectureSection: course.selectedLectureSection
								selectedLabSection: course.selectedLabSection
								supervisor: course.supervisor
								reserved: course.reserved


server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"