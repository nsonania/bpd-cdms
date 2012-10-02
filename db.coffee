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
		number: "ECE C313"
		name: "Microelectronic Circuits"
		sections: [{
			number: 1
			timetableSlots: (day: slot[0], hour: slot[1] for slot in [[1, 4], [3, 1], [4, 2], [5, 8]])
			capacity: 40
		}]
	}
	{
		number: "ECE C393"
		name: "Information Theory and Coding"
		sections: [{
			number: 1
			timetableSlots: (day: slot[0], hour: slot[1] for slot in [[1, 5], [2, 4], [4, 5], [5, 7]])
			capacity: 40
		}]
	}
	{
		number: "ECE C383"
		name: "Communication Systems"
		sections: [{
			number: 1
			timetableSlots: (day: slot[0], hour: slot[1] for slot in [[2, 2], [3, 4], [5, 1], [1, 9], [2, 7], [2, 8], [2, 9]])
			capacity: 40
		}
		{
			number: 2
			timetableSlots: (day: slot[0], hour: slot[1] for slot in [[2, 2], [3, 4], [5, 1], [1, 9], [3, 7], [3, 8], [3, 9]])
			capacity: 40
		}
		{
			number: 3
			timetableSlots: (day: slot[0], hour: slot[1] for slot in [[2, 2], [3, 4], [5, 1], [1, 9], [4, 7], [4, 8], [4, 9]])
			capacity: 40
		}]
	}]
	for item in courses
		course = new Course item
		await course.save defer err
		console.log "Added Course: #{item.name}."