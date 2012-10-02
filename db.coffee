mongoose = require "mongoose"
mongoose.connect "mongodb://#{process.env.DB_USER}:#{process.env.DB_PASSWORD}@ds037837.mongolab.com:37837/bpd-cdms"

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

mongoose.connection.once "open", ->
	courses = [{
		number: "ES C241"
		name: "Electrical Sciences 1"
	}
	{
		number: "ENGG C111"
		name: "Electrical and Electronics Technology"
	}]
	for item in courses
		course = new Course item
		await course.save defer err
		console.log "Added Course: #{item.name}."