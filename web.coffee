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
				selectedSection = if sectionInfo.isLectureSection then "selectedLectureSection" else if sectionInfo.isLabSection then "selectedLabSection"
				student.get("selectedcourses")._find((x) -> x.course_id.equals thisCourse._id)[selectedSection] = sectionInfo.section_number
				student.markModified "selectedcourses"
				student.save ->
					sectionInfos = student.selectedcourse
						._map (x) ->
							ret = []
							ret.push course_id: x.course_id, section_number: selectedLectureSection, isLectureSection: true if x.selectedLectureSection?
							ret.push course_id: x.course_id, section_number: selectedLabSection, isLabSection: true if x.selectedLabSection?
							ret
						._flatten()
					core.sectionStatuses sectionInfos, (statuses) ->
						core.generateSchedule student._id, (scheduleconflicts) ->
							callback
								success: true
								sectionStatuses: statuses
								schedule: scheduleconflicts.schedule
								conflicts: scheduleconflicts.conflicts

server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"