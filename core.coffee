db = require "./db"
uap = require "./uap"

exports.sectionStatus = (sectionInfo, callback) ->
	query =
		registered: true
		selectedcourses: $elemMatch:
			course_id: sectionInfo.course_id
			selectedLectureSection: sectionInfo.section_number if sectionInfo.isLectureSection
			selectedLabSection: sectionInfo.section_number if sectionInfo.isLabSection
	db.Student.find(query).count (err, doneCount) ->
		db.Course.findById(sectionInfo.course_id).lean().exec (err, course) ->
			course.sections = if sectionInfo.isLectureSection then course.lectureSections else if sectionInfo.isLabSection then course.labSections
			seatsLeft = course.sections._find((x) -> x.number is sectionInfo.section_number).capacity - doneCount
			callback do ->
				if seatsLeft > 5
					moreThan5: true
				else if seatsLeft > 0
					lessThan5: true
				else
					isFull: true

exports.generateSchedule = (student_id, callback) ->
	db.Student.findById(student_id).lean().exec (err, student) ->
		db.Course.find(_id: $in: student.selectedcourses._map((x) -> db.toObjectId x.course_id)).lean().exec (err, courses) ->
			slots = {}
			for course in student.selectedcourses when course.selectedLectureSection? or course.selectedLabSection?
				if course.selectedLectureSection?
					for timeslot in courses._find((x) -> x._id.equals course.course_id).lectureSections._find((x) -> x.number is course.selectedLectureSection).timeslots
						slots[timeslot.day] ?= {}
						slots[timeslot.day][timeslot.hour] ?= []
						slots[timeslot.day][timeslot.hour].push course_number: courses._find((x) -> x._id.equals course.course_id).number, section_number: course.selectedLectureSection, type: "lecture"
				if course.selectedLabSection?
					for timeslot in courses._find((x) -> x._id.equals course.course_id).labSections._find((x) -> x.number is course.selectedLabSection).timeslots
						slots[timeslot.day] ?= {}
						slots[timeslot.day][timeslot.hour] ?= []
						slots[timeslot.day][timeslot.hour].push course_number: courses._find((x) -> x._id.equals course.course_id).number, section_number: course.selectedLabSection, type: "lab"
			conflicts = []
			for k1, day of slots
				for k2, hour of day
					if hour.length > 1
						conflicts.push hour...
			conflicts = conflicts._uniq false, (x) -> "#{x.course_number}/#{x.type}/#{x.section_number}"
			callback
				schedule: slots
				conflicts: conflicts