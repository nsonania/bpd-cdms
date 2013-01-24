envimport = require "./envimport"
http = require "http"
socket_io = require "socket.io"

server = http.createServer()

	socket.on "broadcast", (message, data) ->
		socket.broadcast.emit "broadcast", message, data
		console.log message: JSON.stringify(room: room, data: data)

server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"