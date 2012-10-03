mongoose = require "mongoose"
_ = require "underscore"

# mongoose.connect "mongodb://#{process.env.DB_USER}:#{process.env.DB_PASSWORD}@ds037837.mongolab.com:37837/bpd-cdms"		#MongoLab (Cloud)
mongoose.connect "mongodb://localhost:27017/bpd-cdms"																		#Local

Course = mongoose.model "Course", new mongoose.Schema
	number: String
	name: String
	prerequisites: [mongoose.ObjectId]
	sections: [
		number: Number
		timetableSlots: [
			day: Number
			hour: Number
		]
		capacity: Number
	]

Student = mongoose.model "Student", new mongoose.Schema
	id: String
	name: String
	username: String
	password: String
	coursesTaken: [mongoose.ObjectId]

exports.getStudent = (ts, callback) ->
	await Student.find username: ts.username, password: ts.password, defer err, student
	callback if student.length is 1 then student: student[0] else error: "Invalid Student"

exports.getCourses = (ts, callback) ->
	courseDeps = ["AAOC"]
	courseDeps.push if ts.studentId.match("AA")? then "ECE" else "CS"
	await Course.find {}, defer err, courses
	ct = _.map(courses, (x) -> ctype: x.number.split(" ")[0], course: x)
	ct = _.select(ct, (x) -> _.contains(courseDeps, x.ctype))
	ct = _.map(ct, (x) -> x.course)
	callback courses: ct

exports.commitStudent = (ts, callback) ->
	await Student.findOne id: ts.id, defer err, student
	console.log "Loaded Student: #{student.name}"
	await Course.find {}, defer err, courses
	console.log "Loaded all courses"
	student.coursesTaken = []
	for item in ts.coursesSelected
		student.coursesSelected.push _(courses).select((x) -> x.number is item).value()[0]._id
	student.save callback