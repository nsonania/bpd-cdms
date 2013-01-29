# BPD-CDMS
# Author: Gautham Badhrinathan - b.gautham@gmail.com, fb.com/GotEmB

md5 = require "MD5"
db = require "./db"
fs = require "fs"
uap = require "./uap"

dumpError = (err) ->
	if typeof err is "object"
		console.log "\nMessage: " + err.message  if err.message
		if err.stack
			console.log "\nStacktrace:"
			console.log "===================="
			console.log err.stack
		else
			console.log "dumpError :: argument is not an object"

exports.importCourses = (data, callback) ->
	return console.log err if err?
	course = null
	lines = data.split(/\r\n|\r|\n/)._map((x) -> x.split(',')._map (y) -> if y is "" then null else y)._filter (x) -> x? and x.length > 0
	try
		for line in lines[6..]
			if line[0] not in [null, undefined]
				console.log "Parsing #{line[0]}"
				if course?
					if lectureSections.length > 0
						course.set "hasLectureSections", true
						course.set "lectureSections", lectureSections
					if labSections.length > 0
						course.set "hasLabSections", true
						course.set "labSections", labSections
					await course.save defer err, robj
				await db.Course.remove {titles: $elemMatch: compcode: $in: line[0].split(/\ *[;,\/]\ */)._map((x) -> Number x)}, defer err, robj
				course = new db.Course
					titles:
						line[0].split(/\ *[;,\/]\ */)._map((x) -> Number x)._map (ccode, i) ->
							compcode: Number ccode
							number: line[1].split(/\ *[;,\/]\ */)._map((x) -> x)[i]
							name: line[2]
					otherDates: od for od in line[10..] when od not in [null, undefined, "*", "-", "**", "--"]
				lectureSections = []
				labSections = []
				currentSections = if line[3].indexOf("0") is 0 then labSections else lectureSections
			else
				if line[4] is "1" then currentSections = labSections
			currentSections.push
				number: currentSections.length + 1
				instructor: line[5]
				timeslots: do ->
					ts =
						for day in ("#{line[8] ? ""} #{line[9] ? ""}".match(/[a-zA-Z]+\s*\d+/g) ? [])._map((x) => x.split(" ").join(""))
							for di, dii in ["Su", "M", "T", "W", "Th", "F", "S"]
								if day[0...di.length] is di and not isNaN day[di.length..]
									hours = day[di.length..]
									break
							for hour in hours
								throw "Invalid Timeslot" if isNaN hour
								day: dii + 1
								hour: Number hour
					ts._flatten()
				capacity: Number line[6] ? 40
		if course?
			if lectureSections.length > 0
				course.set "hasLectureSections", true
				course.set "lectureSections", lectureSections
			if labSections.length > 0
				course.set "hasLabSections", true
				course.set "labSections", labSections
			await course.save defer err, robj
		db.Course.remove titles: $elemMatch: compcode: $in: ["", null], ->
			console.log "Import Courses Done."
			callback true
	catch error
		console.log "Import Courses: Error Parsing CSV file."
		dumpError error
		callback false

exports.deleteAllCourses = (callback) ->
	db.Course.find {}, (err, courses) ->
		return console.log err if err?
		for course in courses
			await course.remove defer err, robj
			await course.save defer err, robj
		callback true

exports.commitStudents = (new_students, callback) ->
	db.Student.find _id: $in: new_students._map((x) -> db.toObjectId x._id), (err, oldStudents) ->
		for student in oldStudents
			await student.remove defer err, robj
			await student.save defer err, robj
		for obj in new_students
			student = new db.Student obj
			await student.save defer err, robj
		callback true

exports.importStudents = (data, callback) ->
	db.Course.find().lean().exec (err, courses) ->
		return console.log err if err?
		db.Student.find {}, (err, oldStudents) ->
			return console.log err if err?
			lines = data.split(/\r\n|\r|\n/)._map((x) -> x.split(/,(?=(?:[^"\\]*(?:\\.|"(?:[^"\\]*\\.)*[^"\\]*"))*[^"]*$)/g)._map((y) -> y.replace /(^\")|(\"$)/g, "")._map (y) -> if y is "" then null else y)._filter (x) -> x? and x.length > 0
			try
				for line in lines[5..]
					_oic = undefined
					for oc in oldStudents when (oc?.get("studentId")?.toString?() is line[0]?.toString())
						_oic = oc?.get("_id")
						await db.Student.findOneAndRemove _id: _oic, defer err, robj
					student = new db.Student
						_id: _oic
						studentId: line[0]
						name: line[1]
						password: md5 line[3] if line[3]?
						bc: line[4].toLowerCase().split(/\ *[;,]\ */)._map((x) -> Number x)._uniq() if line[4]?
						psc: line[5].toLowerCase().split(/\ *[;,]\ */)._map((x) -> Number x)._uniq() if line[5]?
						el: line[6].toLowerCase().split(/\ *[;,]\ */)._map((x) -> Number x)._uniq() if line[6]?
						reqEl: Number line[7] ? 0
					await student.save defer err, robj
				db.Student.remove studentId: $in: ["", null], ->
					console.log "Import Students Done."
					callback true
			catch error
				console.log "Import Students: Error Parsing CSV file."
				dumpError error
				callback false

exports.deleteAllStudents = (callback) ->
	db.Student.find {}, (err, students) ->
		return console.log err if err?
		for student in students
			await student.remove defer err, robj
			await student.save defer err, robj
		callback true

exports.commitValidators = (new_validators, callback) ->
	db.Validator.find {username: $in: new_validators._map (x) -> x.username}, (err, oldValidators) ->
		for validator in oldValidators
			await validator.remove defer err, robj
			await validator.save defer err, robj
		for obj in new_validators
			validator = new db.Validator obj
			await validator.save defer err, robj
		callback true

exports.importValidators = (data, callback) ->
	db.Validator.find {}, (err, oldValidators) ->
		return console.log err if err?
		lines = data.split(/\r\n|\r|\n/)._map((x) -> x.split(/,(?=(?:[^"\\]*(?:\\.|"(?:[^"\\]*\\.)*[^"\\]*"))*[^"]*$)/g)._map((y) -> y.replace /(^\")|(\"$)/g, "")._map (y) -> if y is "" then null else y)._filter (x) -> x? and x.length > 0
		try
			for line in lines[5..]
				_oic = undefined
				for oc in oldValidators when (oc?.get("username")?.toString?() is line[0]?.toString())
					_oic = oc?.get("_id")
					await db.Validator.findOneAndRemove _id: _oic, defer err, robj
				validator = new db.Validator
					_id: _oic
					username: line[0]
					name: line[1]
					password: md5 line[2]
				await validator.save defer err, robj
			db.Validator.remove username: $in: ["", null], ->
				console.log "Import Validators Done."
				callback true
		catch error
			console.log "Import Validators: Error Parsing CSV file."
			dumpError error
			callback false

exports.deleteAllValidators = (callback) ->
	db.Validator.find {}, (err, validators) ->
		return console.log err if err?
		for validator in validators
			await validator.remove defer err, robj
			await validator.save defer err, robj
		callback true

exports.commitSemester = (semester, callback) ->
	db.Misc.findOneAndRemove desc: "Semester Details", (err, robj) ->
		obj = new db.Misc
			desc: "Semester Details"
			title: semester.title
			startTime: new Date semester.startTime
		await obj.save defer er, robj
		callback true

exports.exportStudentsSelections = (cat, callback) ->
	cats = ["All Students", "Not Registered", "Not Validated", "Validated", "Difficult Timetable"]
	str = "Students, #{cats[cat]}\n"
	query =
		switch Number cat
			when 0 then {}
			when 1 then registered: $ne: true
			when 2 then registered: true, validated: $ne: true
			when 3 then validated: true
			when 4 then difficultTimetable: true
	db.Student.find query, (err, students) ->
		students = students._sortBy (x) -> x.get "studentId"
		str += "Student Id, Comp. Code, Lecture Section, Lab Section\n"
		for student in students
			str += student.get("studentId") + "\n"
			for course in student.get "selectedcourses"
				str += "," + course.compcode + "," + (if course.selectedLectureSection? then course.selectedLectureSection else "") + "," + (if course.selectedLabSection? then course.selectedLabSection else "") + "\n"
		callback str

exports.exportCourse = (compcode, callback) ->
	db.Course.findOne titles: $elemMatch: compcode: Number compcode, (err, course) ->
		db.Student.find validated: true, selectedcourses: $elemMatch: compcode: $in: course.get("titles").map((x) -> Number x.compcode), (err, students) ->
			return callback false unless course?
			str = "By Course\n"
			for title in course.get "titles"
				str += "Compcode: #{compcode}, Course No: #{title.number}, Course Name: #{title.name}, Enrolled: #{students._filter((x) -> x.get("selectedcourses")._any (y) -> y.compcode is title.compcode).length}\n"
				str += "Student Id, Student Name\n"
				for student in students._filter((x) -> x.get("selectedcourses")._any (y) -> y.compcode is title.compcode)
					str += "#{student.get "studentId"}, #{student.get "name"}\n"
				str += "\n"
			str += "\n"
			str += "By Section\n"
			for section in course.get("lectureSections") ? []
				str += "Lecture Section: #{section.number}, Enrolled: #{students._filter((x) -> x.get("selectedcourses")._any (y) -> y.selectedLectureSection is section.number).length}\n"
				str += "Student Id, Student Name\n"
				for student in students._filter((x) -> x.get("selectedcourses")._any (y) -> y.selectedLectureSection is section.number)
					str += "#{student.get "studentId"}, #{student.get "name"}\n"
				str += "\n"
			for section in course.get("labSections") ? []
				str += "Lecture Section: #{section.number}, Enrolled: #{students._filter((x) -> x.get("selectedcourses")._any (y) -> y.selectedLabSection is section.number).length}\n"
				str += "Student Id, Student Name\n"
				for student in students._filter((x) -> x.get("selectedcourses")._any (y) -> y.selectedLabSection is section.number)
					str += "#{student.get "studentId"}, #{student.get "name"}\n"
				str += "\n"
			callback str

exports.getStats = (callback) ->
	await db.Misc.findOne desc: "Stats", defer err, stats
	await db.Student.count registered: $ne: true, defer err, notRegistered
	await db.Student.count registered: true, validated: $ne: true, defer err, notValidated
	await db.Student.count validated: true, defer err, validated
	await db.Student.count difficultTimetable: true, defer err, difficultTimetable
	callback
		currentStudents: stats?.get "currentStudents"
		currentNotRegistered: notRegistered
		currentNotValidated: notValidated
		currentValidated: validated
		currentDifficultTimetable: difficultTimetable
		currentValidators: stats?.get "currentValidators"