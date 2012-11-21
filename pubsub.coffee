socket_io_client = require "socket.io-client"

exports = module.exports = socket_io_client.connect "http://bpd-cdms-pubsub.herokuapp.com:80"