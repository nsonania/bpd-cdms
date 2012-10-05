###
This file deals with declaring the Schema and provide direct access to Mongoose collections for the MongoDB database.
###

mongoose = require "mongoose"

# mongoose.connect "mongodb://#{process.env.DB_USER}:#{process.env.DB_PASSWORD}@ds037837.mongolab.com:37837/bpd-cdms"		#MongoLab (Cloud)
mongoose.connect "mongodb://localhost:27017/bpd-cdms"																		#Local

{ObjectId, Schema, model} = mongoose

Predicate = new Schema
	predicate: type: String, enum: ["is", "isnt", "greaterThan", "lessThan", "in", "not", "and", "or"], required: true
	op1: type: Schema.Types.Mixed, required: true
	op2: type: Schema.Types.Mixed, required: false

Course = model "Course", new Schema
	number: type: String, required: true
	name: type: String, required: true
	semesters: [
		year: type: Number, required: true
		semester: type: Number, required: true
		sections: [
			number: type: Number, required: true
			timeTableSlots: [
				day: type: String, enum: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday"], required: true
				from: type: Date, required: true
				to: type: Date, required: true
			]
			capacity: type: Number, required: true
		]
		components: [
			component: type: String, enum: ["Test 1", "Test 2", "Quiz 1", "Quiz 2", "Compre"], required: true
			from: type: Date, required: true
			to: type: Date, required: true
		]
		prerequisites: type: Schema.Types.Mixed, required: true
	]

Student = mongoose.model "Student", new mongoose.Schema
	id: String
	name: String
	username: String
	password: String
	coursesTaken: [mongoose.ObjectId]

exports = {Predicate, Course, Student}