###
This file provides a way to store and access session variables from a MongoDB.
###

mongoose = {Schema} = require "mongoose"
pubsub = require "./pubsub"
md5 = require "MD5"
db = require "./db"

store = mongoose.createConnection "mongodb://#{process.env.DB_USER}:#{process.env.DB_PASSWORD}@ds043457.mongolab.com:43457/bpd-cdms-sessions"

Session = store.model "Session", new Schema
	hash: String
	student_id: Schema.Types.ObjectId

exports.createSession = (student_id, callback) ->
	Session.find student_id: student_id, (err, sessions) ->
		for session in sessions
			session.remove()
			pubsub.emit "destroySession", session.hash
		hash = md5 "#{student_id.toString()}_#{Date.now()}" while do ->
			return true unless hash?
			await Session.find(hash: hash).count defer err, count
			return count > 0
		session = new Session hash: hash, student_id: student_id
		session.save ->
			callback hash

exports.getStudent = (hash, callback) ->
	Session.findOne hash: hash, (err, session) ->
		db.Student.findById session.student_id, (err, student) ->
			callback student