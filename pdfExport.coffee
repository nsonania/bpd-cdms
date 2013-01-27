# BPD-CDMS
# Author: Gautham Badhrinathan - b.gautham@gmail.com, fb.com/GotEmB

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

	doc.image "pdfGen/BPDC_logo_only.png", 147.64, 270.945, height: 300

	doc.font "pdfGen/Avenir Next Condensed.ttc", "AvenirNextCondensed-DemiBold"
	doc.fontSize 22
	doc.text "Birla Institute of Technology & Science, Pilani", align: "center"
	doc.font "pdfGen/Avenir Next Condensed.ttc", "AvenirNextCondensed-Medium"
	doc.fontSize 16
	doc.text "Dubai Campus, Dubai International Academic City", align: "center"
	doc.moveDown()
	doc.text data.semesterTitle, align: "center"
	doc.text "Registration Card", align: "center"
	doc.moveDown()
	doc.fontSize 12
	doc.text "Status: #{data.status ? "NORMAL"}\nName: #{data.studentName}\nID No.: #{data.studentId}\n"

	columns = [
		{px: 76, width: 50, name: "Code"}
		{px: 232, width: 74, name: "Course No."}
		{px: 306, width: 185.28, name: "Course Name"}
		{px: 126, width: 33, name: "LS"}
		{px: 159, width: 33, name: "PS"}
		{px: 192, width: 40, name: "Type"}
		{px: 490.28, width: 37, name: "A/R"}
	]

	doc.font "pdfGen/Avenir Next Condensed.ttc", "AvenirNextCondensed-Medium"
	start = x: doc.x, y: doc.y
	for {px, width, name} in columns
		doc.text name, px + 4, start.y, width: width - 16, align: "center"

	doc.moveTo(start.x, start.y + 21).lineTo(523.28, start.y + 21).lineWidth(2).stroke()

	doc.font "pdfGen/Avenir Next Condensed.ttc", "AvenirNextCondensed-Regular"
	doc.y++
	for course in data.courses
		cur = x: doc.x, y: doc.y
		doc.text course.compcode, columns[0].px + 4, cur.y + 9, width: columns[0].width - 16, align: "center"
		doc.text course.number, columns[1].px + 4, cur.y + 9, width: columns[1].width - 16, align: "center"
		doc.text course.lecture, columns[3].px + 4, cur.y + 9, width: columns[3].width - 16, align: "center" if course.lecture?
		doc.text course.lab, columns[4].px + 4, cur.y + 9, width: columns[4].width - 16, align: "center" if course.lab?
		doc.text course.type, columns[5].px + 4, cur.y + 9, width: columns[5].width - 16, align: "center"
		doc.text course.name, columns[2].px + 4, cur.y + 9, width: columns[2].width - 16, align: "left"
		doc.moveTo(start.x, cur.y + 4).lineTo(523.28, cur.y + 4).lineWidth(1).stroke() unless course is data.courses._first()

	for x in [0 ... 10 - data.courses.length]
		doc.moveTo(start.x, doc.y + 4).lineTo(523.28, doc.y + 4).lineWidth(1).stroke()
		doc.moveDown()
		doc.y += 9

	doc.moveUp()
	doc.y -= 9
	doc.rect(start.x, start.y - 6, 451.28, doc.y - start.y + 36).lineWidth(2).stroke()
	for {px} in columns
		doc.moveTo(px - 4, start.y - 6).lineTo(px - 4, doc.y + 36 - 6).lineWidth(1).stroke()

	doc.fontSize 8
	doc.text "LS: Lecture Section,    PS: Lab / Practicals Section,    A/R: Amendment / Revision", start.x, doc.y + 34
	doc.fontSize 12
	doc.font "pdfGen/Avenir Next Condensed.ttc", "AvenirNextCondensed-Medium"
	doc.text (data.registeredDate ? new Date).toDateString(), start.x + 1, 730, width: 90, align: "center"
	doc.font "pdfGen/Avenir Next Condensed.ttc", "AvenirNextCondensed-MediumItalic"
	doc.text "Date", start.x + 1, 750, width: 90, align: "center"
	doc.text "Student", start.x + 121, 750, width: 90, align: "center"
	doc.text "Validator", start.x + 241, 750, width: 90, align: "center"
	doc.text "Dean", start.x + 361, 750, width: 90, align: "center"
	doc.moveTo(start.x + 1, doc.y - 18).lineTo(start.x + 91, doc.y - 18).dash(1, space: 2).stroke()
	doc.moveTo(start.x + 121, doc.y - 18).lineTo(start.x + 211, doc.y - 18).dash(1, space: 2).stroke()
	doc.moveTo(start.x + 241, doc.y - 18).lineTo(start.x + 331, doc.y - 18).dash(1, space: 2).stroke()
	doc.moveTo(start.x + 361, doc.y - 18).lineTo(start.x + 451, doc.y - 18).dash(1, space: 2).stroke()

	doc.write "lib/rc_#{data.sid}.pdf", callback