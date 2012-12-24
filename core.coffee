startTime = Date.now()

md5 = require "MD5"
db = require "./db"
fs = require "fs"
uap = require "./uap"

exports.commitCourses = (new_courses, callback) ->
	await for obj in new_courses
		db.Course.findOneAndRemove _id: obj._id, defer err, robj
	await for obj in new_courses
		course = new db.Course obj
		course.save defer err, robj
	callback true

exports.importCourses = (data, callback) ->
	db.Course.find {}, (err, oldCourses) ->
		return console.log err if err?
		course = null
		lines = data.split(/\r\n|\r|\n/)._map((x) -> x.split(',')._map (y) -> if y is "" then null else y)._filter (x) -> x? and x.length > 0
		await for line in lines[6..]
			if line[0] not in [null, undefined]
				if course?
					if lectureSections.length > 0
						course.set "hasLectures", true
						course.set "lectureSections", lectureSections
					if labSections.length > 0
						course.set "hasLab", true
						course.set "labSections", labSections
					course.save defer err, robj
				_oic = undefined
				for oc in oldCourses when (oc.get("compcode").toString() is line[0].toString())
					_oic = oc.get("_id")
					await db.Course.findOneAndRemove _id: _oic, defer err, robj
				course = new db.Course
					_id: _oic
					compcode: line[0]
					number: line[1]
					name: line[2]
					otherDates: od for od in line[9..] when od not in [null, undefined, "*", "-"]
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
						for day in "#{line[7] ? ""} #{line[8] ? ""}".split(" ")._filter((x) -> x? and x.length > 0)
							for di, dii in ["Su", "M", "T", "W", "Th", "F", "S"]
								if day[0...di.length] is di and not isNaN day[di.length..]
									hours = day[di.length..]
									break
							for hour in hours
								throw "Invalid Timeslot" if isNaN hour
								day: dii + 1
								hour: Number hour
					ts._flatten()
				capacity: 20
		if course?
			if lectureSections.length > 0
				course.set "hasLectures", true
				course.set "lectureSections", lectureSections
			if labSections.length > 0
				course.set "hasLab", true
				course.set "labSections", labSections
			await course.save defer err, robj
		console.log "Import Courses Done."
		callback true

exports.deleteAllCourses = (callback) ->
	db.Course.find {}, (err, courses) ->
		return console.log err if err?
		await for course in courses
			course.remove defer err, robj
			course.save defer err, robj
		callback true