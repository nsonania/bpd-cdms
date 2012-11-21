express = require "express"
http = require "http"
socket_io = require "socket.io"
md5 = require "MD5"
{spawn} = require "child_process"
db = require "./db"
core = require "./core"
cluster = require "cluster"
pubsub = require "./pubsub"
sessions = require "./sessions"

cp = spawn "cake", ["build"]
await cp.on "exit", defer code
return console.log "Build failed! Run 'cake build' to display build errors." if code isnt 0

if cluster.isMaster
	cluster.fork() for x in [1..4]
	cluster.on "exit", (worker, code, signal) -> console.log "worker #{worker.process.pid} died"
	return

console.log "worker #{process.pid} started"

expressServer = express()
expressServer.configure ->

	expressServer.use (req, res, next) ->
		console.log "worker #{process.pid}: #{req.method} #{req.url}"
		next()
	expressServer.use express.bodyParser()
	expressServer.use (req, res, next) ->
		req.url = "/page.html" if req.url is "/"
		next()
	expressServer.use express.static "#{__dirname}/lib", maxAge: 31557600000, (err) -> console.log "Static: #{err}"
	expressServer.use expressServer.router

expressServer.post "/api/login", (req, res, next) ->
	db.Student.findOne(studentId: req.body.studentId.toUpperCase(), password: req.body.password).lean().exec (err, student) ->
		return res.send success: false unless student?
		return res.send success: true, registered: true if student.registered
		sessions.createSession student._id, (hash) ->
			res.send
				success: true
				student:
					studentId: student.studentId
					name: student.name
				hash: hash

expressServer.post "/api/initializeSectionsScreen", (req, res, next) ->
	sessions.getStudent req.body.hash, (student) ->
		return res.send success: false unless student?
		db.Course.find().where("_id").in(x.course_id for x in student.get("selectedcourses")).lean().exec (err, selectedcourses) ->
			core.generateSchedule student._id, (scheduleconflicts) ->
				res.send
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

expressServer.post "/api/chooseSection", (req, res, next) ->
	sessions.getStudent req.body.hash, (student) ->
		return res.send success: false unless student?
		sectionInfo = req.body.sectionInfo
		db.Course.find(_id: $in: student.get("selectedcourses")._map((x) -> db.toObjectId x.course_id)).lean().exec (err, courses) ->
			thisCourse = courses._find (x) -> x.compcode is sectionInfo.course_compcode
			console.log req.body
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
						res.send
							success: true
							status: if slotsFull or data.isFull then false else if data.lessThan5 then "yellow" else true
							schedule: scheduleconflicts.schedule
							conflicts: scheduleconflicts.conflicts

expressServer.post "/api/confirmRegistration", (req, res, next) ->
	sessions.getStudent req.body.hash, (student) ->
		return res.send success: false unless student?
		for selectedcourse in student.get "selectedcourses"
			if selectedcourse.selectedLectureSection?
				await core.sectionStatus course_id: selectedcourse.course_id, section_number: selectedcourse.selectedLectureSection, isLectureSection: true, defer result
				return res.send success: false, invalidRegistration: true if result.isFull?
			if selectedcourse.selectedLabSection?
				await core.sectionStatus course_id: selectedcourse.course_id, section_number: selectedcourse.selectedLabSection, isLabSection: true, defer result
				return res.send success: false, invalidRegistration: true if result.isFull?
		student.set "registered", true
		student.markModified "registered"
		student.save ->
			res.send success: true
		db.Course.find({_id: $in: student.get("selectedcourses")._map((x) -> x.course_id)}, "_id compcode").lean().exec (err, courses) ->
			for course in student.get("selectedcourses") then do (course) ->
				if course.selectedLectureSection?
					core.sectionStatus course_id: course.course_id, section_number: course.selectedLectureSection, isLectureSection: true, (data) ->
						pubsub.emit "publish", courses._find((x) -> x._id.equals course.course_id).compcode, sectionType: "lecture", sectionNumber: course.selectedLectureSection, status: data
				if course.selectedLabSection?
					core.sectionStatus course_id: course.course_id, section_number: course.selectedLabSection, isLabSection: true, (data) ->
						pubsub.emit "publish", courses._find((x) -> x._id.equals course.course_id).compcode, sectionType: "lab", sectionNumber: course.selectedLabSection, status: data

server = http.createServer expressServer
server.listen (port = process.env.PORT ? 5000), -> console.log "worker #{process.pid}: Listening on port #{port}"