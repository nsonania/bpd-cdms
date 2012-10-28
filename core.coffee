db = require "./db"
_ = require "underscore"

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
	await db.Student.find(_id: $in: _(student_ids).map (x) -> db.Types.ObjectId.fromString x).lean().exec defer err, leftStudents
	await db.Course.find(_id: $in: _(course_ids).map (x) -> db.Types.ObjectId.fromString x)
		.select("_id lectureSections labSections").lean().exec defer err, course_sections
	await db.Student.find selectedcourses: $elemMatch: reserved: true, course: $in: _(course_ids).map (x) -> db.Types.ObjectId.fromString x
		.lean().exec defer err, doneStudents
	capacitiesDone = {}
	for x in course_sections
		capacitiesDone[x] = {}
		if x.lectureSections?
			for y in x.lectureSections
				capacitiesDone[x._id].lectureSections[y.number] =
					_(doneStudents).select((z) -> _(z.selectedcourses).any (w) -> w.course is x._id and w.selectedLectureSection is y.number).length
		if x.labSections?
			for y in x.labSections
				capacitiesDone[x._id].labSections[y.number] =
					_(doneStudents).select((z) -> _(z.selectedcourses).any (w) -> w.course is x._id and w.selectedLabSection is y.number).length
	leftStudents = _([_(leftStudents).find (x) -> x._id = student_id]).union _(leftStudents).select (x) -> x._id isnt student_id #handle
	recAssignCheck = (assignments) ->
		if assignments.length > 0
			lastAssignment = _(assignments).last()
			res1 = _(lastAssignment.courses).all (assignment_course) ->
				if course.lectureSection?
					res2 = _(_(course_sections).find((x) -> x._id is assignment_course.course).lectureSections).any (section) ->
						section.capacity <
						capacitiesDone[assignment_course.course].lectureSections[assignment_course.section] +
						_(assignments).count (x) -> _(x.courses).any (y) -> y.course is assignment_course.course and y.lectureSection is course.lectureSection
					return false if res2
				if course.labSection?
					res2 = _(_(course_sections).find((x) -> x._id is assignment_course.course).labSections).any (section) ->
						section.capacity <
						capacitiesDone[assignment_course.course].labSections[assignment_course.section] +
						_(assignments).count (x) -> _(x.courses).any (y) -> y.course is assignment_course.course and y.labSection is course.labSection
					return false if res2
				true
			return false unless res1
		return true if _(leftStudents).all (x) -> x._id in _(assignments).map (y) -> y.student._id
		thisStudent = _(_(leftStudents).select (x) -> x._id not in _(assignments).map (y) -> y.student._id).first()
		thisAssignment = student_id: thisStudent._id
		thisCourses = _(thisStudent.selectedcourses).map (x) -> selection: x, course: _(course_sections).find (y) -> y._id is x.course_sections.course
		doneCourses = _(thisCourses).select (x) -> x.selection.reserved
		leftCourses = _(thisCourses).difference doneCourses
		recAssignSection = (section_assignments, todo) ->
			if todo is "lab" and _(leftCourses).all((x) -> x._id in _(section_assignments).map (y) -> y.course)
				return recAssignCheck _(assignments).union [student: thisStudent, course: section_assignments]
			takenSlots = do ->
				ret = []
				for x in doneCourses
					if (k = _(thisStudent.selectedcourses).find((y) -> y.course is x._id).selectedLectureSection)?
						ret.push _(x.lectureSections).find((y) -> y.number is k).timeslots...
					if (k = _(thisStudent.selectedcourses).find((y) -> y.course is x._id).selectedLabSection)?
						ret.push _(x.labSections).find((y) -> y.number is k).timeslots...
				for x in section_assignments
					if x.selectedLectureSection?
						ret.push _(_(leftCourses).find((y) -> y._id is x.course).lectureSections).select((y) -> y.number is x.selectedLectureSection).timeslots...
					if x.selectedLabSection?
						ret.push _(_(leftCourses).find((y) -> y._id is x.course).labSections).select((y) -> y.number is x.selectedLabSection).timeslots...

			if todo is "lecture"
				courseToAssign = _(_(leftCourses).select (x) -> x._id not in _(section_assignments).map (y) -> y.course).first()
				if courseToAssign.hasLectures
					for x in courseToAssign.lectureSections
						continue if _(x.timeslots).intersection(takenSlots).length > 0
						continue unless recAssignSection _(section_assignments).union [course: courseToAssign._id, selectedLectureSection: x.number], "lab"
						return true
					return false
				else
					return recAssignSection _(section_assignments).union [course: courseToAssign._id], "lab"
			else if todo is "lab"
				courseToAssign = _(leftCourses).find (x) -> x._id is _(section_assignments).last().course
				if courseToAssign.hasLab
					for x in courseToAssign.labSections
						continue if _(x.timeslots).intersection(takenSlots).length > 0
						oldAssignment = (sa = _(section_assignments).union([])).pop()
						continue unless recAssignSection _(sa).union [
							course: oldAssignment.course
							selectedLectureSection: oldAssignment.selectedLectureSection
							selectedLabSection: x.number
						], "lecture"
						return true
					return false
				else
					return recAssignSection section_assignments, "lecture"
			else if todo is "lecture+"
				courseToAssign = _(leftCourses).find (x) -> x._id is _(section_assignments).last().course
				if courseToAssign.hasLectures
					for x in courseToAssign.lectureSections
						continue if _(x.timeslots).intersection(takenSlots).length > 0
						oldAssignment = (sa = _(section_assignments).union([])).pop()
						continue unless recAssignSection _(sa).union [
							course: oldAssignment.course
							selectedLectureSection: x.number
							selectedLabSection: oldAssignment.selectedLabSection
						], "lecture"
						return true
					return false
				else
					return recAssignSection section_assignments, "lecture"
		startWith = 
		recAssignSection (if assignments.length > 0 then [] else [
			course: sectionInfo.course_id
			selectedLectureSection: if sectionInfo.lectureSection? then sectionInfo.section
			selectedLabSection: if sectionInfo.labSection? then sectionInfo.section
		]), (if sectionInfo.lectureSection? then "lab" else "lecture+")
	recAssignCheck()