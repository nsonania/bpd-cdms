PDFDocument = require "pdfkit"
uap = require "./uap"

exports.generateRC = (data, callback) ->
	doc = new PDFDocument
		size: "A4"
		layout: "portrait"
		info:
			Title: "#{data.studentName}'s Registration Card"
			Author: "BITS Pilani, Dubai Campus"
			Subject: "Registration Card for #{data.studentName} (#{data.studentId}) [#{data.semesterTitle}]"

	doc.font "Helvetica"
	doc.fontSize 22
	doc.text "BITS Pilani, Dubai Campus", align: "center"
	doc.fontSize 16
	doc.text "#{data.semesterTitle}", align: "center"
	doc.moveDown()
	doc.fontSize 18
	doc.text "Registration Card", align: "center"
	doc.moveDown()
	doc.fontSize 12
	doc.text "Name: #{data.studentName}\nID No.: #{data.studentId}\n"
	doc.moveDown()

	columns = [
		{px: 76, width: 50, name: "Code"}
		{px: 126, width: 90, name: "Course No."}
		{px: 216, width: 244, name: "Course Name"}
		{px: 460.28, width: 33, name: "L"}
		{px: 493.28, width: 34, name: "P"}
	]

	doc.font "Helvetica-Bold"
	start = x: doc.x, y: doc.y
	for {px, width, name} in columns
		doc.text name, px + 4, start.y, width: width - 16, align: "center"

	doc.moveTo(start.x, start.y + 22).lineTo(523.28, start.y + 22).lineWidth(2).stroke()

	doc.font "Helvetica"
	for course in data.courses
		cur = x: doc.x, y: doc.y
		doc.text course.compcode, columns[0].px + 4, cur.y + 20, width: columns[0].width - 16, align: "center"
		doc.text course.number, columns[1].px + 4, cur.y + 20, width: columns[1].width - 16, align: "center"
		doc.text course.lecture, columns[3].px + 4, cur.y + 20, width: columns[3].width - 16, align: "center" if course.lecture?
		doc.text course.lab, columns[4].px + 4, cur.y + 20, width: columns[4].width - 16, align: "center" if course.lab?
		doc.text course.name, columns[2].px + 4, cur.y + 20, width: columns[2].width - 16, align: "left"

		doc.moveTo(start.x, cur.y + 7).lineTo(523.28, cur.y + 7).lineWidth(1).stroke() unless course is data.courses._first()

	doc.rect(start.x, start.y - 13, 451.28, cur.y - start.y + 54).lineWidth(2).stroke()
	for {px} in columns
		doc.moveTo(px - 4, start.y - 13).lineTo(px - 4, cur.y + 54 - 13).lineWidth(1).stroke()

	doc.fontSize 8
	doc.text "L: Lecture Section, P: Lab / Practicals Section", start.x, doc.y + 12

	doc.fontSize 12
	doc.font "Helvetica-BoldOblique"
	doc.text data.studentName, start.x, 770
	doc.moveTo(start.x, doc.y - 22).lineTo(222, doc.y - 22).dash(1, space: 2).stroke()

	doc.image "/Users/Gautham/Desktop/BPDC\ Logos/BITS Logo.jpg", 72, 65, height: 80
	doc.image "/Users/Gautham/Desktop/BPDC\ Logos/Tagline_colored.jpg", 434, 750, height: 30
	doc.write "lib/rc_#{data.studentId}.pdf", callback