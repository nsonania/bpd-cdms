express = require "express"
http = require "http"
socket_io = require "socket.io"
request = require "request"
url = require "url"
md5 = require "MD5"
connect = require "connect"
cookie = require "cookie"
mongoose = require "mongoose"
{spawn} = require "child_process"

cp = spawn "cake", ["build"]
await cp.on "exit", defer code
return console.log "Build failed! Run 'cake build' to display build errors." if code isnt 0

expressServer = express.createServer()
expressServer.configure ->

	expressServer.use express.bodyParser()
	expressServer.use (req, res, next) ->
		req.url = "/page.html" if req.url is "/"
		next()
	expressServer.use express.static "#{__dirname}/lib", maxAge: 31557600000, (err) -> console.log "Static: #{err}"
	expressServer.use expressServer.router

server = http.createServer expressServer

io = socket_io.listen server
io.set "log level", 0
io.sockets.on "connection", (socket) ->
	# ...

server.listen (port = process.env.PORT ? 5000), -> console.log "Listening on port #{port}"