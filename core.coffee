startTime = Date.now()

md5 = require "MD5"
db = require "./db"
fs = require "fs"
uap = require "./uap"

exports.buildCoursesCollection = (data, callback) ->
	db.Course.find {}, (err, courses) ->
		return console.log err if err?
		for course in courses
			course.remove()
			course.save()
		course = null
		lines = data.split(/\r\n|\r|\n/)._map((x) -> x.split(',')._map (y) -> if y is "" then null else y)
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
						capacity: line[3]
						slots: []
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
						section.slots.push
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