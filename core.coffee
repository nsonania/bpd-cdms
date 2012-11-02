db = require "./db"
uap = require "./uap"

# Handle Core / Elective Slots
exports.sectionStatus = (sectionInfo, callback) ->
	db.Student.find(reserved: true, selectedcourses: $elemMatch: course_id: db.toObjectId(sectionInfo.course_id), section_number: sectionInfo.section_number).count (err, doneCount) ->
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
			console.log do ->
				if seatsLeft > 5
					moreThan5: true
				else if seatsLeft > 0
					lessThan5: true
				else
					isFull: true