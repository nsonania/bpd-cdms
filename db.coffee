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
	await Course.findOne number: "MATH C191", defer err, math1
	await Course.findOne number: "MATH C192", defer err, math2
	courses = [{
		number: "AAOC C321"
		name: "Optimisation"
		prerequisites: [math1._id, math2._id]
		sections: [{
			number: 1
			timetableSlots: (day: day, hour: hour for day, hour of {1: 3, 2: 3, 4: 3, 5: 4})
			capacity: 40
		}
		{
			number: 2
			timetableSlots: (day: day, hour: hour for day, hour of {1: 3, 2: 1, 3: 8, 5: 4})
			capacity: 40
		}
		{
			number: 3
			timetableSlots: (day: day, hour: hour for day, hour of {1: 1, 3: 3, 4: 4, 5: 4})
			capacity: 40
		}
		{
			number: 4
			timetableSlots: (day: day, hour: hour for day, hour of {2: 5, 3: 1, 4: 8, 5: 4})
			capacity: 40
		}]
	}]
	for item in courses
		course = new Course item
		course.save (err) -> console.log "Added Course: #{item.name}."