http = require "http"
socket_io = require "socket.io"

server = http.createServer expressServer

io = socket_io.listen server
io.set "log level", 0
io.sockets.on "connection", (socket) ->
	
	socket.on "subscribe", (course_id) ->
		socket.join course_id

	socket.on "unsubscribe", (course_id) ->
		socket.leave course_id

	socket.on "publish", (room, data) ->
		io.sockets.to(room).emit room, data

server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"