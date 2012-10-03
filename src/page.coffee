student = null
courses = null
removedCourses = []
selectedCourse = null

$(document).ready ->
	socket = io.connect()
	socket.on "connect", ->
		$("#blockerbox").css display: "none"

	$("#login_button").click ->
		socket.emit "login", username: $("#username_input").val(), password: $("#password_input").val(), (data) ->
			if data.error?
				return alert "Invalid Username/Password"
			student = data.student
			socket.emit "courses", studentId: student.id, (data) ->
				courses = data.courses
				$("#newcourse_select").html("")
				for course, i in courses
					$("#newcourse_select").append "<option nbr='#{course.number.split(" ").join("_")}'>#{course.number}: #{course.name}</option>"
				$("#newcourse_select").removeAttr "disabled"
				
				cid = $("#newcourse_select").children(":selected").attr("nbr").split("_").join(" ")
				selectedCourse = course = _(courses).select((x) -> x.number is cid)[0]
				$("#section_select").html("")
				for section in course.sections
					$("#section_select").append "<option>#{section.number}</option>"
				$("#section_select, #addcourse_button").removeAttr "disabled"

	$("#newcourse_select").change ->
		cid = $(this).children(":selected").attr("nbr").split("_").join(" ")
		selectedCourse = course = _(courses).select((x) -> x.number is cid)[0]
		$("#section_select").html("")
		for section in course.sections
			$("#section_select").append "<option>#{section.number}</option>"
		$("#section_select, #addcourse_button").removeAttr "disabled"

	$("#section_select").change ->
		$("#addcourse_button").removeAttr "disabled"

	$("#addcourse_button").click ->
		tcourse = selectedCourse
		cid = parseInt($("#section_select").children(":selected").text())
		slots = selectedCourse.sections[cid - 1].timetableSlots
		$("#c#{slot.day}#{slot.hour}").append "<div>#{selectedCourse.number}</div>" for slot in slots
		validateSlots()
		$("#selcourses").append "<tr><td>#{selectedCourse.number}</td><td>#{selectedCourse.name}</td><td>#{cid}</td><td><button>X</button></td></tr>"
		$("#selcourses td button").last().click ->
			$(_($("#c#{slot.day}#{slot.hour}").children()).select((x) -> $(x).text() is tcourse.number)[0]).remove() for slot in slots
			$(this).parent().parent().remove()
			removedCourses = _(removedCourses).select (x) -> x isnt tcourse
			courses.push tcourse
			$("#newcourse_select").html("")
			for course, i in courses
				$("#newcourse_select").append "<option nbr='#{course.number.split(" ").join("_")}'>#{course.number}: #{course.name}</option>"
			$("#section_select").html("")
			$("#addcourse_button, #section_select").attr disabled: "disabled"
			validateSlots()
			
			if $("#newcourse_select").children().length > 0
				cid = $("#newcourse_select").children(":selected").attr("nbr").split("_").join(" ")
				tcourse = course = _(courses).select((x) -> x.number is cid)[0]
				$("#section_select").html("")
				for section in course.sections
					$("#section_select").append "<option>#{section.number}</option>"
				$("#section_select, #addcourse_button").removeAttr "disabled"
		removedCourses.push tcourse
		courses = _(courses).difference(removedCourses)
		$("#newcourse_select").html("")
		for course, i in courses
			$("#newcourse_select").append "<option nbr='#{course.number.split(" ").join("_")}'>#{course.number}: #{course.name}</option>"
		$("#section_select").html("")
		$("#addcourse_button, #section_select").attr disabled: "disabled"
		
		if $("#newcourse_select").children().length > 0
			cid = $("#newcourse_select").children(":selected").attr("nbr").split("_").join(" ")
			selectedCourse = course = _(courses).select((x) -> x.number is cid)[0]
			$("#section_select").html("")
			for section in course.sections
				$("#section_select").append "<option>#{section.number}</option>"
			$("#section_select, #addcourse_button").removeAttr "disabled"

	validateSlots = ->
		flag = true
		for i in [1..5]
			for j in [1..9]
				$("#c#{i}#{j}").css backgroundColor: if $("#c#{i}#{j}").children().length > 1 then "red" else "white"
				if $("#c#{i}#{j}").children().length > 1 then flag = false
		$("submit_button").attr disabled: if flag then "" else "disabled"