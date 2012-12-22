startTime = Date.now()

md5 = require "MD5"
db = require "./db"
fs = require "fs"
uap = require "./uap"

exports.commitCourses = (new_courses, callback) ->
	db.Course.find {}, (err, courses) ->
		return console.log err if err?
		for course in courses
			course.remove()
			course.save()
		course = null
		for obj in new_courses
			course = new db.Course obj
			course.save()
		callback true

exports.importCourses = (data, callback) ->
	db.Course.find {}, (err, courses) ->
		return console.log err if err?
		for course in courses
			course.remove()
			course.save()
		course = null
		lines = data.split(/\r\n|\r|\n/)._map((x) -> x.split(',')._map (y) -> if y is "" then null else y)._filter (x) -> x? and x.length > 0
		for line in lines[6..]
			if line[0] not in [null, undefined]
				if course?
					if lectureSections.length > 0
						course.set "hasLectures", true
						course.set "lectureSections", lectureSections
					if labSections.length > 0
						course.set "hasLab", true
						course.set "labSections", labSections
					course.save()
				course = new db.Course
					compcode: parseInt line[0]
					number: line[1]
					name: line[2]
				lectureSections = []
				labSections = []
				currentSections = if line[3].indexOf "0" is 0 then labSections else lectureSections
			else
				if line[4] is "1" then currentSections = labSections
			currentSections.push
				number: currentSections.length + 1
				instructor: line[5]
				timeslots: do ->
					ts =
						for day in "#{line[7]} #{line[8]}".split(" ")._filter (x) -> x? and x.length > 0
							for di, dii in ["Su", "M", "T", "W", "Th", "F", "S"]
								if day[0...di.length] is di
									hours = day[di.length..]
									break
							for hour in hours
								day: dii
								hour: Number hour
					_(ts).flatten()

exports.buildCoursesCollection = (data, callback) ->
	db.Course.find {}, (err, courses) ->
		return console.log err if err?
		for course in courses
			course.remove()
			course.save()
		course = null
		lines = data.split(/\r\n|\r|\n/)._map((x) -> x.split(',')._map (y) -> if y is "" then null else y)._filter (x) -> x? and x.length > 0
		for line in lines
			if line[0] not in [null, undefined, "_"]
				if course?
					if lectureSections.length > 0
						course.set "hasLectures", true
						course.set "lectureSections", lectureSections
					if labSections.length > 0
						course.set "hasLab", true
						course.set "labSections", labSections
					course.save()
				course = new db.Course
					compcode: parseInt line[0]
					number: line[1]
					name: line[2]
				lectureSections = []
				labSections = []
			else if line[0] is "_"
				inLectureSections = inLabSections = false
				switch line[1]
					when "Lecture Sections"
						inLectureSections = true
					when "Lab Sections"
						inLabSections = true
			else unless line[0]?
				if line[1] not in [null, undefined, "_"]
					section =
						number: parseInt line[1]
						instructor: line[2]
						capacity: parseInt line[3] ? 0
						timeslots: []
					if inLectureSections
						lectureSections.push section
					else if inLabSections
						labSections.push section
				else if line[1] is "_"
					inSlots = false
					switch line[2]
						when "Slots"
							inSlots = true
				else unless line[1]?
					if inSlots
						section.timeslots.push
							day: parseInt line[2]
							hour: parseInt line[3]
		if course?
			if lectureSections.length > 0
				course.set "hasLectures", true
				course.set "lectureSections", lectureSections
			if labSections.length > 0
				course.set "hasLab", true
				course.set "labSections", labSections
			course.save()
		console.log "Courses Done."
		callback true

exports.buildStudentsCollection = (data, callback) ->
	db.Course.find({}, "_id compcode").lean().exec (err, courses) ->
		db.Student.find {}, (err, students) ->
			for student in students
				student.remove()
				student.save()
			student = null
			lines = data.split(/\r\n|\r|\n/)._map((x) -> x.split(',')._map (y) -> if y is "" then null else y)
			console.log lines
			for line in lines
				if line[0] not in [null, undefined, "_"]
					if student?
						student.set "selectedcourses", selectedcourses
						student.save()
					student = new db.Student
						studentId: line[0]
						name: line[1]
						password: md5 line[2]
						registered: true if line[3] is "true"
					selectedcourses = []
				else if line[0] is "_"
					inSelectedcourses = false
					switch line[1]
						when "Selected Courses"
							inSelectedcourses = true
				else unless line[0]?
					if inSelectedcourses
						return callback false unless courses._find((x) -> x.compcode is parseInt line[1])?
						selectedcourses.push
							course_id: courses._find((x) -> x.compcode is parseInt line[1])._id
							selectedLectureSection: parseInt line[2] if line[2]?
							selectedLabSection: parseInt line[3] if line[3]?
			if student?
				student.set "selectedcourses", selectedcourses
				student.save()
			console.log "Students Done"
			callback true