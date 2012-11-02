express = require "express"
http = require "http"
socket_io = require "socket.io"
md5 = require "MD5"
{spawn} = require "child_process"
db = require "./db"
core = require "./core"

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
				db.Course.find().where("_id").in(x.course_id for x in student.get("selectedcourses")).lean().exec (err, selectedcourses) -> #redo
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
								lectureSections: if course.hasLectures then for section in course.lectureSections
									await core.sectionStatus course_id: course._id, section_number: section.number, isLectureSection: true, defer status
									number: section.number
									instructor: section.instructor
									status: status
								labSections: if course.hasLab then for section in course.labSections
									await core.sectionStatus course_id: course._id, section_number: section.number, isLabSection: true, defer status
									number: section.number
									instructor: section.instructor
									status: status
								selectedLectureSection: course.selectedLectureSection
								selectedLabSection: course.selectedLabSection
								supervisor: course.supervisor
								reserved: course.reserved

	socket.on "chooseSection", (sectionInfo, callback) ->
		socket.get "studentId", (err, studentId) ->
			return callback success: false unless studentId?
			db.Student.findOne(studentId: studentId).lean().exec (err, student) ->
				db.Course.find(_id: $in: student.selectedcourses._map((x) -> db.toObjectId x.course_id)).lean().exec (err, courses) ->
					thisCourse = courses._find (x) -> x.compcode is sectionInfo.course_compcode
					thisCourse.sections = if sectionInfo.isLectureSection then thisCourse.lectureSections else if sectionInfo.isLabSection then thisCourse.labSections
					stringifiedTimeslots = JSON.stringify thisCourse.sections._find((x) -> x.number is sectionInfo.section_number).timeslots
					slotsFull = student.selectedcourses
						._select((x) -> x.selectedLabSection? or x.selectedLectureSection?)
						._map((x) -> lecture: x.selectedLectureSection, lab: x.selectedLabSection, course: courses._find (y) -> y._id is x.course_id)
						._any (x) ->
							if x.lecture?
								return true if x.course.lectureSections._find((y) -> y.number is x.lecture).timeslots._map((y) -> JSON.stringify y).intersection(stringifiedTimeslots).length > 0
							if x.lab?
								return true if x.course.labSections._find((y) -> y.number is x.lab).timeslots._map((y) -> JSON.stringify y).intersection(stringifiedTimeslots).length > 0
					core.sectionStatus course_id: thisCourse._id, section_number: sectionInfo.section_number, isLectureSection: sectionInfo.isLectureSection, isLabSection:sectionInfo.isLabSection, (data) ->
						callback
							success: true
							status: if slotsFull then false else if data.lessThan5 then "yellow" else true


server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"