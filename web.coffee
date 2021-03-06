envimport = require "./envimport"
express = require "express"
http = require "http"
socket_io = require "socket.io"
md5 = require "MD5"
{spawn} = require "child_process"
db = require "./db"
core = require "./core"
fs = require "fs"

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

	socket.on "login", ([{studentId, password}]..., callback) ->
		await db.Misc.findOne desc: "Semester Details", defer err, semester
		return callback? success: false, reason: "notOpen" unless semester?
		startTime = new Date semester.get "startTime"
		return callback? success: false, reason: "notOpen" if startTime > new Date()
		db.Student.findOne studentId: studentId.toUpperCase(), password: password, (err, student) ->
			return callback? success: false, reason: "authFailure" unless student?
			io.sockets.clients()._filter((x) -> x.student_id? and x.student_id.equals(student._id) and x isnt socket)._each (x) -> x.emit "destroySession"
			socket.student_id = student.get "_id"
			callback? do =>
				success: true
				student:
					studentId: student.get "studentId"
					name: student.get "name"
					status: if student.get("validated") then "validated" else if student.get("registered") then "registered" else if student.get("difficultTimetable") then "difficultTimetable" else "not registered"

	socket.on "getCourses", (callback) ->
		await db.Student.findById socket.student_id, defer err, student
		return callback? success: false unless student?
		bc = student.get("bc") ? []
		psc = student.get("psc") ? []
		el = student.get("el") ? []
		db.Course.find {titles: $elemMatch: compcode: $in: (student.get("bc") ? [])._union (student.get("psc") ? [])._union (student.get("el") ? [])}, (err, courses) ->
			el =
				for x in el
					continue unless c = courses._find (y) -> y.get("titles")._any (z) -> z.compcode is x
					lecturesCapacity = if c.get("hasLectureSections")? then (c.get("lectureSections") ? [])._reduce ((sum, y) -> sum + y.capacity), 0
					labsCapacity = if c.get("hasLabSections")? then (c.get("labSections") ? [])._reduce ((sum, y) -> sum + y.capacity), 0
					totalCapacity = Math.max lecturesCapacity, labsCapacity
					await db.Student.count {$or: [{bc: x}, {psc: x}, {selectedcourses: $elemMatch: compcode: x}]}, defer err, count
					leftCapacity = totalCapacity - count
					compcode: x
					number: c.get("titles")._find((y) -> y.compcode is x).number
					name: c.get("titles")._find((y) -> y.compcode is x).name
					leftCapacity: leftCapacity
					selected: (student.get("selectedcourses") ? [])._any (y) -> x is y.compcode
					otherDates: c.get "otherDates"
			callback? do =>
				bc:
					for x in bc when (c = courses._find (y) -> y.get("titles")._any (z) -> z.compcode is x)?
						compcode: x
						number: c.get("titles")._find((y) -> y.compcode is x).number
						name: c.get("titles")._find((y) -> y.compcode is x).name
						selected: (student.get("selectedcourses") ? [])._any (y) -> x is y.compcode
						otherDates: c.get "otherDates"
				psc:
					for x in psc when (c = courses._find (y) -> y.get("titles")._any (z) -> z.compcode is x)?
						compcode: x
						number: c.get("titles")._find((y) -> y.compcode is x).number
						name: c.get("titles")._find((y) -> y.compcode is x).name
						selected: (student.get("selectedcourses") ? [])._any (y) -> x is y.compcode
						otherDates: c.get "otherDates"
				el: el
				reqEl: student.get("reqEl") ? 0
				groups: student.get("groups") ? []

	socket.on "saveCourses", ([data]..., callback) ->
		await db.Student.findById socket.student_id, defer err, student
		return callback? success: false unless student? and data? and not student.get "registered"
		selectedcourses = student.get("selectedcourses") ? []
		allC = [data.bc, data.psc, data.el]._flatten()
		selectedcourses = selectedcourses._filter (x) -> x.compcode in allC._filter((y) -> y.selected)._map (y) -> y.compcode
		selectedcourses = selectedcourses.concat allC._filter((x) -> x.selected and x.compcode not in selectedcourses._map (y) -> y.compcode)._map (x) -> compcode: x.compcode
		student.set "selectedcourses", selectedcourses
		student.markModified "selectedcourses"
		student.save -> callback? true

	socket.on "initializeSectionsScreen", (callback) ->
		await db.Student.findById socket.student_id, defer err, student
		return callback? success: false unless student?
		db.Course.find(titles: $elemMatch: compcode: $in: (x.compcode for x in student.get "selectedcourses")).lean().exec (err, selectedcourses) ->
			db.Validator.findById student.get("validatedBy"), (err, validator) ->
				core.generateSchedule student._id, (scheduleconflicts) ->
					ret =
						success: true
						selectedcourses:
							for selcourse in student.get("selectedcourses")
								continue unless selectedcourses?._any((x) -> x.titles._any (y) -> y.compcode is selcourse.compcode)
								title = selectedcourses._map((x) -> x.titles)._flatten()._find (x) -> x.compcode is selcourse.compcode
								course = selectedcourses._find (x) -> x.titles._any (y) -> y.compcode is selcourse.compcode
								compcode: title.compcode
								number: title.number
								name: title.name
								hasLectures: course?.hasLectureSections
								hasLab: course?.hasLabSections
								lectureSections: if course?.hasLectureSections then for section in course?.lectureSections
									await core.sectionStatus compcode: selcourse.compcode, section_number: section.number, isLectureSection: true, defer status
									number: section.number
									instructor: section.instructor
									status: status
								labSections: if course?.hasLabSections then for section in course?.labSections
									await core.sectionStatus compcode: selcourse.compcode, section_number: section.number, isLabSection: true, defer status
									number: section.number
									instructor: section.instructor
									status: status
								selectedLectureSection: selcourse.selectedLectureSection
								selectedLabSection: selcourse.selectedLabSection
								otherDates: course?.otherDates
						schedule: scheduleconflicts.schedule
						registeredOn: student.get("registeredOn")?.toString()
						validatedOn: student.get("validatedOn")?.toString()
						validatedBy: validator?.get "name"
					callback? ret

	socket.on "chooseSection", ([sectionInfo]..., callback) ->
		await db.Student.findById socket.student_id, defer err, student
		return callback? success: false unless student? and sectionInfo? and not student.get "registered"
		db.Course.find(titles: $elemMatch: compcode: $in: student.get("selectedcourses")._map((x) -> x.compcode)).lean().exec (err, courses) ->
			thisCourse = courses._find (x) -> x.titles._any (y) -> y.compcode is sectionInfo.compcode
			return callback? success: false unless thisCourse?
			thisCourse.sections = (if sectionInfo.isLectureSection then thisCourse?.lectureSections else if sectionInfo.isLabSection then thisCourse?.labSections) ? []
			stringifiedTimeslots = (JSON.stringify thisCourse?.sections._find((x) -> x.number is sectionInfo.section_number).timeslots) ? []
			slotsFull = student.get("selectedcourses")
				._select((x) -> x.selectedLabSection? or x.selectedLectureSection?)
				._map((x) -> lecture: x.selectedLectureSection, lab: x.selectedLabSection, course: courses._find (y) -> y.titles._any (z) -> z.compcode is x.compcode)
				._any (x) ->
					if x.lecture?
						return false if x.course.titles._any((y) -> y.compcode is sectionInfo.compcode) and sectionInfo.isLectureSection
						return true if x.course.lectureSections._find((y) -> y.number is x.lecture).timeslots._map((y) -> JSON.stringify y)._intersection(stringifiedTimeslots).length > 0
					if x.lab?
						return false if x.course.titles._any((y) -> y.compcode is sectionInfo.compcode) and sectionInfo.isLabSection
						return true if x.course.labSections._find((y) -> y.number is x.lab).timeslots._map((y) -> JSON.stringify y)._intersection(stringifiedTimeslots).length > 0
			core.sectionStatus compcode: sectionInfo.compcode, section_number: sectionInfo.section_number, isLectureSection: sectionInfo.isLectureSection, isLabSection:sectionInfo.isLabSection, (data) ->
				updateQuery =
					if sectionInfo.isLectureSection
						"selectedcourses.$.selectedLectureSection": sectionInfo.section_number
					else if sectionInfo.isLabSection
						"selectedcourses.$.selectedLabSection": sectionInfo.section_number
				db.Student.update _id: socket.student_id, registered: {$ne: true}, "selectedcourses.compcode": sectionInfo.compcode, updateQuery, (err, nA) ->
					return callback? success: false if nA isnt 1
					core.generateSchedule student._id, (scheduleconflicts) ->
						callback? do =>
							success: true
							status: data
							schedule: scheduleconflicts.schedule

	socket.on "confirmRegistration", (callback) ->
		await db.Student.findById socket.student_id, defer err, student
		return callback? success: false unless student?
		for selectedcourse in student.get "selectedcourses"
			if selectedcourse.selectedLectureSection?
				await core.sectionStatus compcode: selectedcourse.compcode, section_number: selectedcourse.selectedLectureSection, isLectureSection: true, defer result
				return callback? success: false, invalidRegistration: true if result.isFull?
			if selectedcourse.selectedLabSection?
				await core.sectionStatus compcode: selectedcourse.compcode, section_number: selectedcourse.selectedLabSection, isLabSection: true, defer result
				return callback? success: false, invalidRegistration: true if result.isFull?
		db.Student.update {_id: socket.student_id, selectedcourses: student.get("selectedcourses")}, registered: true, registeredOn: new Date, (err, nA) ->
			return callback? success: false, invalidRegistration: true if nA isnt 1
			callback? success: true
			db.Course.find({titles: $elemMatch: compcode: $in: student.get("selectedcourses")._map((x) -> x.compcode)}, "compcode").lean().exec (err, courses) ->
				for course in student.get("selectedcourses") then do (course) ->
					if course.selectedLectureSection?
						core.sectionStatus compcode: course.compcode, section_number: course.selectedLectureSection, isLectureSection: true, (data) ->
							db.Student.find(_id: $in: io.sockets.clients().map((x) -> x.student_id)._filter((x) -> x?)).lean().exec (err, students) ->
								db.Course.findOne titles: $elemMatch: compcode: course.compcode, (err, sharedCourses) ->
									stds = students._filter((x) -> x.selectedcourses?._any((y) -> sharedCourses.get("titles")._any (z) -> z.compcode is course.compcode)).map (x) -> x._id.toString()
									io.sockets.clients()._filter((x) -> x.student_id? and x.student_id.toString() in stds)._each (x) -> x.emit "sectionUpdate", course.compcode, sectionType: "lecture", sectionNumber: course.selectedLectureSection, status: data
					if course.selectedLabSection?
						core.sectionStatus compcode: course.compcode, section_number: course.selectedLabSection, isLabSection: true, (data) ->
							db.Student.find(_id: $in: io.sockets.clients().map((x) -> x.student_id)._filter((x) -> x?)).lean().exec (err, students) ->
								db.Course.findOne titles: $elemMatch: compcode: course.compcode, (err, sharedCourses) ->
									stds = students._filter((x) -> x.selectedcourses?._any((y) -> sharedCourses.get("titles")._any (z) -> z.compcode is course.compcode)).map (x) -> x._id.toString()
									io.sockets.clients()._filter((x) -> x.student_id? and x.student_id.toString() in stds)._each (x) -> x.emit "sectionUpdate", course.compcode, sectionType: "lab", sectionNumber: course.selectedLabSection, status: data

	socket.on "getSemesterDetails", (callback) ->
		db.Misc.findOne desc: "Semester Details", (err, semester) ->
			return callback? success: false, reason: "notSetup" unless semester?
			callback? do =>
				success: true
				semesterTitle: semester.get "title"
				startTime: semester.get "startTime"

	socket.on "difficultTimetable", (callback) ->
		await db.Student.findById socket.student_id, defer err, student
		return callback? success: false unless student?
		student.set "difficultTimetable", true
		student.markModified "difficultTimetable"
		student.save -> callback? true

	socket.on "logout", (callback) ->
		await db.Student.findById socket.student_id, defer err, student
		return callback? success: false unless student?
		if not student.get("registered") and not student.get("difficultTimetable") and student.get("selectedcourses")?
			student.set "selectedcourses", []
			student.markModified "selectedcourses"
			student.save -> callback? true
		else
			callback? true
		delete socket.student_id

	socket.on "disconnect", ->
		if socket.student_id?
			await db.Student.findById socket.student_id, defer err, student
			if not student.get("registered") and not student.get("difficultTimetable") and student.get("selectedcourses")?
				student.set "selectedcourses", []
				student.markModified "selectedcourses"
				student.save()

server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"

setInterval ->
	db.Misc.findOneAndUpdate desc: "Stats", {currentStudents: io.sockets.clients()._filter((x) -> x.student_id?).length}, {upsert: true}, (err) ->
, 1000
