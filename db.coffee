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
		number: "MATH C191"
		name: "Mathematics 1"
	}
	{
		number: "MATH C192"
		name: "Mathematics 2"
	}]
	for item in courses
		course = new Course item
		await course.save defer err
		console.log "Added Course: #{item.name}."