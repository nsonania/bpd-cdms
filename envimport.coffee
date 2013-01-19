fs = require "fs"
uap = require "./uap"

if fs.existsSync(".env")
	for x in fs.readFileSync(".env" ,"UTF-8").split(/\r\n|\r|\n/)._map((x) -> x.split "=")
		process.env[x[0]] = Number(x[1]) or x[1]