###
This file deals with declaring the Schema and provide direct access to Mongoose collections for the MongoDB database.
###

mongoose = {Schema} = require "mongoose"

# mongoose.connect "mongodb://#{process.env.DB_USER}:#{process.env.DB_PASSWORD}@dbh73.mongolab.com:27737/bpd-cdms"			#MongoLab (Cloud)
mongoose.connect "mongodb://localhost:27017/bpd-cdms"																		#Local

collections = ["Course", "Student", "Misc"]
for collection in collections
	exports[collection] = mongoose.model collection, new Schema {}, strict: false

exports.Types = mongoose.Types
exports.toObjectId = (id) ->
	if typeof id is "string"
		mongoose.Types.ObjectId.fromString id
	else
		id