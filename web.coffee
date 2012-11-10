md5 = require "MD5"
db = require "./db"
fs = require "fs"
uap = require "./uap"

db.Course.find {}, (err, courses) ->
	for course in courses
		course.remove()
		course.save()
	fs.readFile "csv/courses.csv", "utf8", (err, data) ->
		course = null
		throw err if err?
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