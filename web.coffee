envimport = require "./envimport"
express = require "express"
http = require "http"
socket_io = require "socket.io"
md5 = require "MD5"
{spawn} = require "child_process"
db = require "./db"
core = require "./core"

cp = spawn "cake", ["build"]
await cp.on "exit", defer code
return console.log "Build failed with code #{code}! Run 'cake build' to display build errors." if code isnt 0

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

	socket.on "login", ({studentId, password}, callback) ->
		await db.Misc.findOne desc: "Semester Details", defer err, semester
		startTime = new Date semester.get "startTime"
		return callback success: false, reason: "notOpen" if startTime > new Date()
		db.Student.findOne studentId: studentId.toUpperCase(), password: password, (err, student) ->
			return callback success: false, reason: "authFailure" unless student?
			socket.student_id = student.get "_id"
			callback
				success: true
				student:
					studentId: student.get "studentId"
					name: student.get "name"
					status: if student.get("validated") then "validated" else if student.get("registered") then "registered" else if student.get("difficultTimetable") then "difficultTimetable" else "not registered"

	socket.on "getCourses", (callback) ->
		await db.Student.findById socket.student_id, defer err, student
		return callback success: false unless student?
		bc = student.get("bc") ? []
		psc = student.get("psc") ? []
		el = student.get("el") ? []
		db.Course.find {_id: $in: (student.get("bc") ? [])._union (student.get("psc") ? [])._union (student.get("el") ? [])}, (err, courses) ->
			el =
				for x in el
					c = courses._find (y) -> y.get("_id").equals x
					lecturesCapacity = if c.get("hasLectureSections")? then (c.get("lectureSections") ? [])._reduce ((sum, y) -> sum + y.capacity), 0
					labsCapacity = if c.get("hasLabSections")? then (c.get("labSections") ? [])._reduce ((sum, y) -> sum + y.capacity), 0
					totalCapacity = Math.max lecturesCapacity, labsCapacity
					await db.Student.count {$or: [{bc: c.get "_id"}, {psc: c.get "_id"}, {selectedcourses: $elemMatch: course_id: c.get "_id"}]}, defer err, count
					leftCapacity = totalCapacity - count
					_id: c.get "_id"
					compcode: c.get "compcode"
					number: c.get "number"
					name: c.get "name"
					leftCapacity: leftCapacity
					selected: student.get("selectedcourses")._any (y) -> x.equals y.course_id
			callback
				bc:
					for x in bc when (c = courses._find (y) -> y.get("_id").equals x)?
						_id: c.get "_id"
						compcode: c.get "compcode"
						number: c.get "number"
						name: c.get "name"
						selected: student.get("selectedcourses")._any (y) -> x.equals y.course_id
				psc:
					for x in psc when (c = courses._find (y) -> y.get("_id").equals x)?
						_id: c.get "_id"
						compcode: c.get "compcode"
						number: c.get "number"
						name: c.get "name"
						selected: student.get("selectedcourses")._any (y) -> x.equals y.course_id
				el: el
				reqEl: student.get("reqEl") ? 0

	socket.on "saveCourses", (data, callback) ->
		await db.Student.findById socket.student_id, defer err, student
		return callback success: false unless student?
		selectedcourses = student.get("selectedcourses") ? []
		allC = [data.bc, data.psc, data.el]._flatten()
		selectedcourses = selectedcourses._filter (x) -> x.course_id.toString() in allC._filter((y) -> y.selected)._map (y) -> y.course_id
		selectedcourses = selectedcourses.concat allC._filter((x) -> x.selected and x.course_id not in selectedcourses._map (y) -> y.course_id.toString())._map (x) -> course_id: db.toObjectId x.course_id
		student.set "selectedcourses", selectedcourses
		student.markModified "selectedcourses"
		student.save ->
			callback true

	socket.on "initializeSectionsScreen", (callback) ->
		await db.Student.findById socket.student_id, defer err, student
		return callback success: false unless student?
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
							hasLectures: course.hasLectureSections
							hasLab: course.hasLabSections
							lectureSections: if course.hasLectureSections then for section in course.lectureSections
								await core.sectionStatus course_id: course._id, section_number: section.number, isLectureSection: true, defer status
								number: section.number
								instructor: section.instructor
								status: status
							labSections: if course.hasLabSections then for section in course.labSections
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
		await db.Student.findById socket.student_id, defer err, student
		return callback success: false unless student?
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
		await db.Student.findById socket.student_id, defer err, student
		return callback success: false unless student?
		for selectedcourse in student.get "selectedcourses"
			if selectedcourse.selectedLectureSection?
				await core.sectionStatus course_id: selectedcourse.course_id, section_number: selectedcourse.selectedLectureSection, isLectureSection: true, defer result
				return callback success: false, invalidRegistration: true if result.isFull?
			if selectedcourse.selectedLabSection?
				await core.sectionStatus course_id: selectedcourse.course_id, section_number: selectedcourse.selectedLabSection, isLabSection: true, defer result
				return callback success: false, invalidRegistration: true if result.isFull?
		student.set "registered", true
		student.markModified "registered"
		student.save ->
			callback success: true
		db.Course.find({_id: $in: student.get("selectedcourses")._map((x) -> x.course_id)}, "_id compcode").lean().exec (err, courses) ->
			for course in student.get("selectedcourses") then do (course) ->
				if course.selectedLectureSection?
					core.sectionStatus course_id: course.course_id, section_number: course.selectedLectureSection, isLectureSection: true, (data) ->
						db.Student.find(_id: $in: io.sockets.clients().map((x) -> x.student_id?)._filter((x) -> x?)).lean().exec (err, students) ->
							stds = students._filter((x) -> x.selectedcourses._any((y) -> y.course_id is course.course_id and y.selectedLectureSection is course.selectedLectureSection)).map (x) -> x._id.toString()
							io.sockets.clients()._filter((x) -> x.toString() in stds)._each (x) -> x.emit "sectionUpdate", course.compcode, courses._find((x) -> x._id.equals course.course_id).compcode, sectionType: "lecture", sectionNumber: course.selectedLectureSection, status: data
				if course.selectedLabSection?
					core.sectionStatus course_id: course.course_id, section_number: course.selectedLabSection, isLabSection: true, (data) ->
						db.Student.find(_id: $in: io.sockets.clients().map((x) -> x.student_id?)._filter((x) -> x?)).lean().exec (err, students) ->
							stds = students._filter((x) -> x.selectedcourses._any((y) -> y.course_id is course.course_id and y.selectedLabSection is course.selectedLabSection)).map (x) -> x._id.toString()
							io.sockets.clients()._filter((x) -> x.toString() in stds)._each (x) -> x.emit "sectionUpdate", course.compcode, courses._find((x) -> x._id.equals course.course_id).compcode, sectionType: "lab", sectionNumber: course.selectedLabSection, status: data

	socket.on "getSemesterDetails", (callback) ->
		db.Misc.findOne desc: "Semester Details", (err, semester) ->
			callback
				semesterTitle: semester.get "title"
				startTime: semester.get "startTime"

	socket.on "difficultTimetable", (callback) ->
		await db.Student.findById socket.student_id, defer err, student
		return callback success: false unless student?
		student.set "difficultTimetable", true
		student.markModified "difficultTimetable"
		student.save ->
			callback true

	socket.on "logout", (callback) ->
		await db.Student.findById socket.student_id, defer err, student
		return callback success: false unless student?
		if not student.get("registered") and not student.get("difficultTimetable")
			student.get("selectedcourses")._each (x) ->
				delete x.selectedLectureSection
				delete x.selectedLabSection
			student.markModified "selectedcourses"
			student.save -> callback true
		else
			callback true
		delete socket.student_id

	socket.on "disconnect", ->
		if socket.student_id?
			await db.Student.findById socket.student_id, defer err, student
			if not student.get("registered") and not student.get("difficultTimetable")
				student.get("selectedcourses")._each (x) ->
					delete x.selectedLectureSection
					delete x.selectedLabSection
				student.markModified "selectedcourses"
				student.save()

server.listen (port = process.env.PORT ? 5000), -> console.log "worker #{process.pid}: Listening on port #{port}"