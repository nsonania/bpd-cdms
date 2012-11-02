db = require "./db"
uap = require "./uap"

# Handle Core / Elective Slots
exports.sectionStatus = (sectionInfo, callback) ->
	db.Student.find(reserved: true, selectedcourses: $elemmatch: course_id: db.objectIdFromString(sectionInfo.course_id), section_number: sectionInfo.section_number).count (err, doneCount) ->
		db.Course.findById(sectionInfo.course_id).lean (err, course) ->
			course.sections = if sectionInfo.isLectureSection then course.lectureSections else if sectionInfo.isLabSection then course.labSections
			seatsLeft = course.sections.find((x) -> x.number).capacity - doneCount
			callback do ->
				if seatsLeft > 5
					moreThan5: true
				else if seatsLeft > 0
					lessThan5: true
				else
					full: true