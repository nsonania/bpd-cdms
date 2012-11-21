###
This file deals with declaring the Schema and provide direct access to Mongoose collections for the MongoDB database.
###

mongoose = {Schema} = require "mongoose"

db = mongoose.createConnection "mongodb://#{process.env.DB_USER}:#{process.env.DB_PASSWORD}@dbh73.mongolab.com:27737/bpd-cdms"

exports.Course = db.model "Course", new Schema {}, strict: false
exports.Student = db.model "Student", new Schema {}, strict: false
exports.Types = mongoose.Types
exports.toObjectId = (id) ->
	if typeof id is "string"
		mongoose.Types.ObjectId.fromString id
	else
		id