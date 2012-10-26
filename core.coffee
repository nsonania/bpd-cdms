db = require "./db"
_ = require	"underscore"

exports.canOfferSection = (student_id, sectionInfo) ->
	db.Course.findById(sectionInfo.course).lean().exec (err, course) ->
		if sectionInfo.lectureSection?
			course.sections = course.lectureSections
			sectionInfo.section = sectionInfo.lectureSection
		else if sectionInfo.labSection?
			course.sections = course.labSections
			sectionInfo.section = sectionInfo.labSection
		db.Student.find(selectedcourses: $elemMatch: course: db.Types.ObjectId.fromString course._id).lean().exec (err, students) ->
			_(students).each (x) -> x.thisCourse = _(x.selectedcourses).find (y) -> y.course is course._id
			student = _(students).find (x) -> x._id is student_id
			leftStudents = _(students).select (x) -> x.thisCourse.isPsc and not x.thisCourse.reserved and x._id isnt student._id
			doneStudents = _.chain(students)
				.select (x) ->
					x.thisCourse.reserved and x._id isnt student._id
				.groupBy (x) ->
					selcourse = _(x.selectedcourses).find (y) -> y.course is course._id and y.reserved
					if sectionInfo.lectureSection?
						selcourse.selectedLectureSection
					else if sectionInfo.labSection?
						selcourse.selectedLabSection
				.value()

			recAssignCheck = (assignments, depth) ->
				return false if _(assignments).count((x) -> x.section is _(assignments).last().section) > _(assignments).last().section.capacity
				return true if depth is leftStudents.length
				for section in course.sections
					return true if recAssignCheck _(assignments).union([student: leftStudents[depth], section: section]), depth + 1 
				return false

			recAssignCheck [student: student, section: sectionInfo.section], 0