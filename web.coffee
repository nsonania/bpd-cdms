startTime = Date.now()

md5 = require "MD5"
db = require "./db"
fs = require "fs"
uap = require "./uap"

db.Course.find {}, (err, courses) ->
	for course in courses
		course.remove()
		course.save()
	fs.readFile "csv/courses.csv", "utf8", (err, data) ->
		throw err if err?
		course = null
		lines = data.split(/\r\n|\r|\n/)._map((x) -> x.split ',')
		for line in lines
			if line[0] not in ["", "_"]
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
			else if line[0] is ""
				if line[1] not in ["", "_"]
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
				else if line[1] is ""
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

		db.Course.find({}, "_id compcode").lean().exec (err, courses) ->
			db.Student.find {}, (err, students) ->
				for student in students
					student.remove()
					student.save()
				fs.readFile "csv/students.csv", "utf8", (err, data) ->
					throw err if err
					student = null
					lines = data.split(/\r\n|\r|\n/)._map((x) -> x.split ',')
					for line in lines
						if line[0] not in ["", "_"]
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
						else if line[0] is ""
							if inSelectedcourses
									selectedcourses.push
										course_id: courses._find((x) -> x.compcode is parseInt line[1])._id
										selectedLectureSection: parseInt line[2] unless line[2] is ""
										selectedLabSection: parseInt line[3] unless line[3] is ""
					if student?
						student.set "selectedcourses", selectedcourses
						student.save()
					console.log "Task Completed in #{Date.now() - startTime} milliseconds."
					process.exit 0