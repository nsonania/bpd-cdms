mongoose = require "mongoose"
_ = require "underscore"

# mongoose.connect "mongodb://#{process.env.DB_USER}:#{process.env.DB_PASSWORD}@ds037837.mongolab.com:37837/bpd-cdms"		#MongoLab (Cloud)
mongoose.connect "mongodb://localhost:27017/bpd-cdms"																		#Local

ObjectId = mongoose.ObjectId
Schema = mongoose.Schema

exports.Course = mongoose.model "Course", new mongoose.Schema
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

exports.Course

exports.Student = mongoose.model "Student", new mongoose.Schema
	id: String
	name: String
	username: String
	password: String
	coursesTaken: [mongoose.ObjectId]