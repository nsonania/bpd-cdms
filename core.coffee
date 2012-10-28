db = require "./db"
_ = require	"underscore"

studentsAffected = (course_id, callback) ->
	student_ids = []
	course_ids = []
	recfn = (course_id, callback) ->
		await db.Student.find
				_id: $nin: _(student_ids).map (x) -> db.Types.ObjectId.fromString x
				selectedcourses: $elemMatch:
					course: db.Types.ObjectId.fromString(course_id)
					isPsc: true
					reserved: $ne: true
			.lean().exec defer err, newStudents
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

exports.canOfferSection = (student_id, sectionInfo, callback) ->
	await db.Course.findById(sectionInfo.course).lean().exec defer err, course
	if sectionInfo.lectureSection?
		course.sections = course.lectureSections
		sectionInfo.section = sectionInfo.lectureSection
	else if sectionInfo.labSection?
		course.sections = course.labSections
		sectionInfo.section = sectionInfo.labSection
	await studentsAffected sectionInfo.course_id, defer student_ids, course_ids
	await db.Student.find(_id: $in: student_ids).lean().exec defer err, leftStudents
	await db.Course.find
			_id: $in: _(course_ids).map (x) -> db.Types.ObjectId.fromString x
		.select("_id lectureSections labSections").lean().exec defer err, course_sections
	await db.Student.find
			selectedcourses: $elemMatch:
				course: $in: _(course_ids).map (x) -> db.Types.ObjectId.fromString x
				reserved: true
		.lean().exec defer err, doneStudents
	capacitiesDone = {}
	await for x in course_sections
		capacitiesDone[x] = {}
		if x.lectureSections?
			for y in x.lectureSections
				_(doneStudents).find
					selectedcourses: $elemMatch:
						course: db.Types.ObjectId.fromString(x._id)
						selectedLectureSection: y.number
				.count defer err, capacitiesDone[x._id].lectureSections[y.number]
		if x.labSections?
			for y in x.labSections
				_(doneStudents).find
					selectedcourses: $elemMatch:
						course: db.Types.ObjectId.fromString(x._id)
						selectedLabSection: y.number
				.count defer err, capacitiesDone[x._id].labSections[y.number]
	leftStudents = _([_(leftStudents).find (x) -> x._id = student_id]).union _(leftStudents).select (x) -> x._id isnt student_id
	recAssignCheck = (assignments, depth) ->
		lastAssignment = _(assignments).last()
		if assignments.length > 0
			return false unless _(lastAssignment.courses).all((assignment_course) ->
				if course.lectureSection?
					return false if _(_(course_sections).find((x) -> x._id is assignment_course.course).lectureSections).any((section) ->
						section.capacity <
						capacitiesDone[assignment_course.course].lectureSections[assignment_course.section] +
						_(assignments).count((x) -> _(x.courses).any (y) -> y.course is assignment_course.course and y.lectureSection is course.lectureSection)))
				if course.labSection?
					return false if _(_(course_sections).find((x) -> x._id is assignment_course.course).labSections).any((section) ->
						section.capacity <
						capacitiesDone[assignment_course.course].labSections[assignment_course.section] +
						_(assignments).count((x) -> _(x.courses).any (y) -> y.course is assignment_course.course and y.labSection is course.labSection)))
				true
		return true if depth is leftStudents.length
		thisStudent = leftStudents[depth]
		thisAssignment = student_id: thisStudent._id, courses: []
		for course in _(thisStudent.selectedcourses).select (x) -> x.reserved isnt true
			# ...

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