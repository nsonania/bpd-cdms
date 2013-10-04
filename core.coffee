# BPD-CDMS
# Author: Gautham Badhrinathan - b.gautham@gmail.com, fb.com/GotEmB

db = require "./db"
uap = require "./uap"
PDFDocument = require "pdfkit"

exports.sectionStatus = (sectionInfo, callback) ->
	db.Course.findOne(titles: $elemMatch: compcode: sectionInfo.compcode).lean().exec (err, course) ->
		query =
			registered: true
			selectedcourses: $elemMatch:
				compcode: $in: course.titles._map (x) -> x.compcode
		query.selectedcourses.$elemMatch.selectedLectureSection = sectionInfo.section_number if sectionInfo.isLectureSection
		query.selectedcourses.$elemMatch.selectedLabSection = sectionInfo.section_number if sectionInfo.isLabSection
		db.Student.find(query).count (err, doneCount) ->
			course.sections = if sectionInfo.isLectureSection then course.lectureSections else if sectionInfo.isLabSection then course.labSections
			seatsLeft = course.sections._find((x) -> x.number is sectionInfo.section_number).capacity - doneCount
			callback? do =>
				if seatsLeft > 5
					moreThan5: true
				else if seatsLeft > 0
					lessThan5: true
				else
					isFull: true
			#console.log sectionInfo: sectionInfo, seatsLeft: seatsLeft

exports.generateSchedule = (student_id, callback) ->
	db.Student.findById(student_id).lean().exec (err, student) ->
		db.Course.find(titles: $elemMatch: compcode: $in: student.selectedcourses._map((x) -> x.compcode)).lean().exec (err, courses) ->
			slots = {}
			for course in student.selectedcourses when course.selectedLectureSection? or course.selectedLabSection?
				if course.selectedLectureSection?
					for timeslot in (courses._find((x) -> x.titles._any (y) -> y.compcode is course.compcode)?.lectureSections ? [])._find((x) -> x.number is course.selectedLectureSection)?.timeslots ? []
						slots[timeslot.day] ?= {}
						slots[timeslot.day][timeslot.hour] ?= []
						slots[timeslot.day][timeslot.hour].push course_number: courses._map((x) -> x.titles)._flatten()._find((x) -> x.compcode is course.compcode).number, section_number: course.selectedLectureSection, type: "Lecture"
				if course.selectedLabSection?
					for timeslot in (courses._find((x) -> x.titles._any (y) -> y.compcode is course.compcode)?.labSections ? [])._find((x) -> x.number is course.selectedLabSection)?.timeslots ? []
						slots[timeslot.day] ?= {}
						slots[timeslot.day][timeslot.hour] ?= []
						slots[timeslot.day][timeslot.hour].push course_number: courses._map((x) -> x.titles)._flatten()._find((x) -> x.compcode is course.compcode).number, section_number: course.selectedLabSection, type: "Lab"
			conflicts = []
			for k1, day of slots
				for k2, hour of day
					if hour.length > 1
						conflicts.push hour...
			conflicts = conflicts._uniq false, (x) -> "#{x.course_number}/#{x.type}/#{x.section_number}"
			callback? do =>
				schedule: slots
				conflicts: conflicts
