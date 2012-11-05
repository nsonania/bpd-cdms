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
		db.Student.findOne(studentId: data.studentId.toUpperCase(), password: data.password).lean().exec (err, student) ->
			return callback success: false unless student?
			return callback success: true, registered: true if student.registered
			socket.set "studentId", student.studentId, (err) ->
				callback
					success: true
					student:
						studentId: student.studentId
						name: student.name

	socket.on "initializeSectionsScreen", (callback) ->
		socket.get "studentId", (err, studentId) ->
			return callback success: false unless studentId?
			db.Student.findOne studentId: studentId, (err, student) ->
				db.Course.find().where("_id").in(x.course_id for x in student.get("selectedcourses")).lean().exec (err, selectedcourses) ->
					core.generateSchedule student._id, (scheduleconflicts) ->
						callback
							success: true
							selectedcourses:
								for course in selectedcourses
									selcourse = student.get("selectedcourses")._find (x) -> x.course_id.equals course._id
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
									selectedLectureSection: selcourse.selectedLectureSection
									selectedLabSection: selcourse.selectedLabSection
									supervisor: selcourse.supervisor
							schedule: scheduleconflicts.schedule
							conflicts: scheduleconflicts.conflicts

	socket.on "chooseSection", (sectionInfo, callback) ->
		socket.get "studentId", (err, studentId) ->
			return callback success: false unless studentId?
			db.Student.findOne studentId: studentId, (err, student) ->
				db.Course.find(_id: $in: student.get("selectedcourses")._map((x) -> db.toObjectId x.course_id)).lean().exec (err, courses) ->
					thisCourse = courses._find (x) -> x.compcode is sectionInfo.course_compcode
					thisCourse.sections = if sectionInfo.isLectureSection then thisCourse.lectureSections else if sectionInfo.isLabSection then thisCourse.labSections
					stringifiedTimeslots = JSON.stringify thisCourse.sections._find((x) -> x.number is sectionInfo.section_number).timeslots
					slotsFull = student.get("selectedcourses")
						._select((x) -> x.selectedLabSection? or x.selectedLectureSection?)
						._map((x) -> lecture: x.selectedLectureSection, lab: x.selectedLabSection, course: courses._find (y) -> y._id.equals x.course_id)
						._any (x) ->
							if x.lecture?
								return false if x.course._id.equals(thisCourse._id) and sectionInfo.isLectureSection
								return true if x.course.lectureSections._find((y) -> y.number is x.lecture).timeslots._map((y) -> JSON.stringify y)._intersection(stringifiedTimeslots).length > 0
							if x.lab?
								return false if x.course._id.equals(thisCourse._id) and sectionInfo isLabSection
								return true if x.course.labSections._find((y) -> y.number is x.lab).timeslots._map((y) -> JSON.stringify y)._intersection(stringifiedTimeslots).length > 0
					core.sectionStatus course_id: thisCourse._id, section_number: sectionInfo.section_number, isLectureSection: sectionInfo.isLectureSection, isLabSection:sectionInfo.isLabSection, (data) ->
						selectedSection = if sectionInfo.isLectureSection then "selectedLectureSection" else if sectionInfo.isLabSection then "selectedLabSection"
						student.get("selectedcourses")._find((x) -> x.course_id.equals thisCourse._id)[selectedSection] = sectionInfo.section_number
						student.markModified "selectedcourses"
						student.save ->
							core.generateSchedule student._id, (scheduleconflicts) ->
								callback
									success: true
									status: if slotsFull or data.isFull then false else if data.lessThan5 then "yellow" else true
									schedule: scheduleconflicts.schedule
									conflicts: scheduleconflicts.conflicts

	socket.on "confirmRegistration", (callback) ->
		socket.get "studentId", (err, studentId) ->
			return callback success: false unless studentId?
			db.Student.findOne studentId: studentId, (err, student) ->
				student.set "registered", true
				student.markModified "registered"
				student.save ->
					callback success: true

server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"