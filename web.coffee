# BPD-CDMS
# Author: Gautham Badhrinathan - b.gautham@gmail.com, fb.com/GotEmB

envimport = require "./envimport"
http = require "http"
socket_io = require "socket.io"

server = http.createServer()

io = socket_io.listen server
io.set "log level", 0
io.sockets.on "connection", (socket) ->

	socket.on "broadcast", (message, data) ->
		socket.broadcast.emit "broadcast", message, data
		console.log message: JSON.stringify(room: room, data: data)

server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"