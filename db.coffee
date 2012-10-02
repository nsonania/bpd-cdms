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
	await Course.findOne number: "ES C241", defer err, es1
	await Course.findOne number: "ENGG C111", defer err, eet
	courses = [{
		number: "AAOC C321"
		name: "Control Systems"
		prerequisites: [math1._id, es1._id, eet._id]
		sections: [{
			number: 1
			timetableSlots: (day: day, hour: hour for day, hour of {1: 8, 3: 2, 5: 2, 4: 1})
			capacity: 40
		}
		{
			number: 2
			timetableSlots: (day: day, hour: hour for day, hour of {1: 5, 2: 8, 3: 6, 4: 1})
			capacity: 40
		}
		{
			number: 3
			timetableSlots: (day: day, hour: hour for day, hour of {2: 8, 3: 2, 5: 5, 4: 1})
			capacity: 40
		}
		{
			number: 4
			timetableSlots: (day: day, hour: hour for day, hour of {2: 6, 3: 3, 5: 2, 4: 1})
			capacity: 40
		}]
	}
	{
		number: "CS C351"
		name: "Theory of Computation"
		sections: [{
			number: 1
			timetableSlots: (day: day, hour: hour for day, hour of {2: 3, 3: 4, 4: 2, 1: 9})
			capacity: 40
		}]
	}
	{
		number: "CS C363"
		name: "Data Structures and Algorithm"
		sections: [{
			number: 1
			timetableSlots: (day: slot[0], hour: slot[1] for slot in [[3, 1], [4, 3], [5, 3], [1, 8], [3, 8], [3, 9]])
			capacity: 40
		}]
	}
	{
		number: "CS C372"
		name: "Operating Systems"
		sections: [{
			number: 1
			timetableSlots: (day: slot[0], hour: slot[1] for slot in [[2, 6], [3, 5], [5, 1], [1, 7]])
			capacity: 40
		}]
	}
	{
		number: "CS C391"
		name: "Digital Electronics and Computer Organization"
		sections: [{
			number: 1
			timetableSlots: (day: slot[0], hour: slot[1] for slot in [[2, 5], [4, 5], [5, 2], [3, 7], [1, 3], [1, 4], [1, 5]])
			capacity: 40
		}
		{
			number: 2
			timetableSlots: (day: slot[0], hour: slot[1] for slot in [[2, 5], [4, 5], [5, 2], [3, 7], [4, 7], [4, 8], [4, 9]])
			capacity: 40
		}
		{
			number: 3
			timetableSlots: (day: slot[0], hour: slot[1] for slot in [[2, 5], [4, 5], [5, 2], [3, 7], [5, 7], [5, 8], [5, 9]])
			capacity: 40
		}]
	}]
	for item in courses
		course = new Course item
		await course.save defer err
		console.log "Added Course: #{item.name}."