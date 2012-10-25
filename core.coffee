db = require "./db"

exports.canOfferSection = (student_id, sectionInfo) ->
	db.Course.findById(sectionInfo.course).lean().exec (err, course) ->
		db.Student.find (selectedcourses: $elemMatch: course: db.Types.ObjectId.fromString "5086c78f5080fadd49000001"), (err, students) ->
			student = (x for x in students when x._id is student_id)[0]
			pscStudents = (x for x in students when (y for y in x.selectedcourses when y.course is course._id and y.isPsc).length is 1)