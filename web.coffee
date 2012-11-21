http = require "http"
socket_io = require "socket.io"

server = http.createServer()

io = socket_io.listen server
io.set "log level", 0
io.sockets.on "connection", (socket) ->

	socket.on "publish", (room, data) ->
		io.sockets.emit "course_#{room}", data
		console.log message: JSON.stringify(room: room, data: data)

	socket.on "destroySession", (hash) ->
		io.sockets.emit "destroySession_#{hash}"
		console.log destroySession: hash

server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"