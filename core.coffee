db = require "./db"
_ = require	"underscore"

studentsAffected = (course_id, callback) ->
	student_ids = []
	course_ids = []
	recfn = (course_id, callback) ->
		db.Student.find
			_id: $nin: _(student_ids).map (x) -> db.Types.ObjectId.fromString x
			selectedcourses: $elemMatch:
				course: db.Types.ObjectId.fromString(course_id)
				isPsc: true
				reserved: $ne: true
		.lean().exec (err, newStudents) ->
			course_ids.push course_id
			unless newStudents.length is 0
				student_ids.push newStudents...
				newCourses = _.chain(newStudents)
					.map (x) -> _(x.selectedcourses)
						.select (y) ->
							y.isPsc and not y.reserved
						.map (y) ->
							y.course
					.flatten().uniq().difference(course_ids).value()
				innerRec = ->
					if newCourses.length > 0
						recfn newCourses.pop(), -> innerRec()
					else
						callback()
				innerRec()
	recfn course_id, -> callback student_ids, course_ids

exports.canOfferSection = (student_id, sectionInfo) ->
	db.Course.findById(sectionInfo.course).lean().exec (err, course) ->
		if sectionInfo.lectureSection?
			course.sections = course.lectureSections
			sectionInfo.section = sectionInfo.lectureSection
		else if sectionInfo.labSection?
			course.sections = course.labSections
			sectionInfo.section = sectionInfo.labSection
		studentsAffected sectionInfo.course_id, (student_ids, course_ids) ->
			db.Student.find(_id: $in: student_ids).lean().exec (err, leftStudents) ->
				db.Course.find
					_id: $in: _(course_ids).map (x) -> db.Types.ObjectId.fromString x
				.select("_id lectureSections labSections").lean().exec (err, course_sections) ->
					db.Student.find
						selectedcourses: $elemMatch:
							course: $in: _(course_ids).map (x) -> db.Types.ObjectId.fromString x
							reserved: true
					.lean().exec (err, doneStudents) ->
						doneStudents = do ->
							ret = {}
							await for x in course_sections
								ret[x] = {}
								if x.lectureSections?
									for y in x.lectureSections
										_(doneStudents).find
											selectedcourses: $elemMatch:
												course: db.Types.ObjectId.fromString(x._id)
												selectedLectureSection: y.number
										.count defer err, ret[x][y]
								if x.labSections?
									for y in x.labSections
										_(doneStudents).find
											selectedcourses: $elemMatch:
												course: db.Types.ObjectId.fromString(x._id)
												selectedLabSection: y.number
										.count defer err, ret[x][y]


###
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
				for section in course.sections # +when no clash with already registered courses; 
					return true if recAssignCheck _(assignments).union([student: leftStudents[depth], section: section]), depth + 1 
				return false

			recAssignCheck [student: student, section: sectionInfo.section], 0
###