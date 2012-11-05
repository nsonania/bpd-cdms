global = {}

$(document).ready ->
	$("#loginbox input").addClass if $(document).width() >= 1200 then "span3" else "span2"
	$("#courses-sections").addClass if $(document).width() >= 1200 then "span8 offset2" else "span12"
	$("#timetable-grid").addClass if $(document).width() >= 1200 then "span10 offset1" else "span12"
	$(window).resize ->
		if $(document).width() >= 1200
			$("#loginbox input").removeClass("span2").addClass("span3")
			$("#courses-sections").removeClass("span12").addClass("span8 offset2")
			$("#timetable-grid").removeClass("span12").addClass("span10 offset1")
		else
			$("#loginbox input").removeClass("span3").addClass("span2")
			$("#courses-sections").removeClass("span8 offset2").addClass("span12")
			$("#timetable-grid").removeClass("span10 offset1").addClass("span12")

	resetContainers = ->
		$("#prelogin-container, #login-container, #main-container").addClass("hide")
		$("#courses-sections tbody").remove()

	socket = io.connect()
	socket.on "connect", ->
		setupLoginContainer()

	setupLoginContainer = ->
		resetContainers()
		global = {}
		$("#login-container").removeClass("hide")
		$(".nav.pull-right").addClass("hide")
		$("#current-student").text("")
		$("#input-studentid").val("")
		$("#input-password").val("")

	$("#input-studentid").tooltip()
	$("#submit-login").click ->
		$("#alert-login").remove()
		socket.emit "login", studentId: $("#input-studentid").val(), password: md5($("#input-password").val()), (data) ->
			unless data.success
				elem =
					"""
					<div id="alert-login" class="alert alert-error">
						<button type="button" class="close" data-dismiss="alert">×</button>
						<strong>Authentication Failure!</strong> Check if your Student Id &amp; Password are correct.
					</div>
					"""
				$(elem).insertAfter("#loginbox legend")
			else if data.registered
				elem =
					"""
					<div id="alert-login" class="alert alert-info">
						<button type="button" class="close" data-dismiss="alert">×</button>
						<strong>Already Registered!</strong> You cannot amend your registration right now.
					</div>
					"""
				$(elem).insertAfter("#loginbox legend")
			else
				global.student = data.student
				setupMainContainer()

	setupMainContainer = ->
		resetContainers()
		$("#main-container").removeClass("hide")
		$(".nav.pull-right").removeClass("hide")
		$("#current-student").text("#{global.student.name} (#{global.student.studentId})")

		setSchedule = (schedule) ->
			$("#timetable-grid tbody tr td:not(:nth-of-type(1))").text ""
			$("#timetable-grid tbody tr td:not(:nth-of-type(1))").removeClass "error"
			for k1, day of schedule
				k1 = parseInt k1
				for k2, hour of day
					k2 = parseInt k2
					$("#timetable-grid tr:nth-of-type(#{if k2 < 10 then k2 else 11}) td:nth-of-type(#{k1 + 1})").html _(hour).map((x) -> x.course_number + if x.type is "Lab" then " (Lab)" else "").join "<br>"
					if hour.length > 1
						$("#timetable-grid tr:nth-of-type(#{if k2 < 10 then k2 else 11}) td:nth-of-type(#{k1 + 1})").addClass "error"

		setConflicts = (conflicts) ->
			$("#courses-sections tbody tr").removeClass "error"
			$("#courses-sections tbody tr .btn-group .btn").removeClass "status-conflict btn-danger btn-warning btn-success"
			for conflict in conflicts
				$("#courses-sections tbody tr[data-coursenumber='#{conflict.course_number}']").addClass("error")
					.find(".btn-group[data-sectiontype='#{conflict.type}']").children(".btn").addClass "status-conflict btn-danger"
			$("#courses-sections tbody tr .btn-group .btn.status-free").not(".status-conflict").addClass "btn-success"
			$("#courses-sections tbody tr .btn-group .btn.status-limited").not(".status-conflict").addClass "btn-warning"
			$("#courses-sections tbody tr .btn-group .btn.status-conflict, .btn.status-full").addClass "btn-danger"
			if $("#courses-sections tbody tr .btn-group .btn.btn-danger").length > 0
				$("#register_button").addClass "disabled"
			else
				$("#register_button").removeClass "disabled"

		socket.emit "initializeSectionsScreen", (data) ->
			console.log data
			return alert "Please restart your session by refreshing this page." unless data.success
			$("<tbody></tbody>").appendTo("#courses-sections table")
			for course in data.selectedcourses
				hasLectures = ->
					selectedSection = if course.selectedLectureSection? then ": #{course.selectedLectureSection}" else ""
					sectionColorClass =
						if selectedSection isnt ""
							section = (section for section in course.lectureSections when section.number is course.selectedLectureSection)[0]
							if section.status.isFull then "status-full btn-danger"
							else if section.status.lessThan5 then "status-limited btn-warning"
							else "status-free btn-success"
						else
							""
					"""
					<div class="btn-group" data-sectiontype="lecture">
						<button class="btn dropdown-toggle #{sectionColorClass}" data-toggle="dropdown">Lecture#{selectedSection} <span class="caret"></span></button>
						<ul class="dropdown-menu">
							#{
								ret =
									for section in course.lectureSections
										liClass = if section.status.isFull then "error" else if section.status.lessThan5 then "warning" else ""
										"<li class='#{liClass}' data-course='#{course.compcode}' data-sectiontype='lecture' data-section='#{section.number}'><a><strong>#{section.number}</strong>: #{section.instructor}</a></li>"
								ret.join("\n")
							}
						</ul>
					</div>
					"""
				hasLab = ->
					selectedSection = if course.selectedLabSection? then ": #{course.selectedLabSection}" else ""
					sectionColorClass =
						if selectedSection isnt ""
							section = (section for section in course.labSections when section.number is course.selectedLabSection)[0]
							if section.status.isFull then "status-full btn-danger"
							else if section.status.lessThan5 then "status-limited btn-warning"
							else "status-free btn-success"
						else
							""
					"""
					<div class="btn-group" data-sectiontype="lab">
						<button class="btn dropdown-toggle #{sectionColorClass}" data-toggle="dropdown">Lab#{selectedSection} <span class="caret"></span></button>
						<ul class="dropdown-menu">
							#{
								ret =
									for section in course.labSections
										liClass = if section.status.isFull then "error" else if section.status.lessThan5 then "warning" else ""
										"<li class='#{liClass}' data-course='#{course.compcode}' data-sectiontype='lab' data-section='#{section.number}'><a><strong>#{section.number}</strong>: #{section.instructor}</a></li>"
								ret.join("\n")
							}
						</ul>
					</div>
					"""
				elem =
					"""
					<tr data-compcode="#{course.compcode}" data-coursenumber="#{course.number}">
						<td>#{course.compcode}</td>
						<td>#{course.number}</td>
						<td>#{course.name}</td>
						<td #{if course.isProject then "" else 'class="btn-toolbar"'}>
							#{
								if course.isProject
									course.supervisor
								else
									"#{if course.hasLectures then hasLectures() else ""}\n#{if course.hasLab then hasLab() else ""}"
							}
						</td>
					</tr>
					"""
				$(elem).appendTo("#courses-sections table tbody")
				$("#courses-sections table tbody td div.btn-group li").click ->
					elem = $(@)
					msg =
						course_compcode: parseInt elem.attr "data-course"
						section_number: parseInt elem.attr "data-section"
						isLectureSection: if elem.attr("data-sectiontype") is "lecture" then true
						isLabSection: if elem.attr("data-sectiontype") is "lab" then true
					socket.emit "chooseSection", msg, (data) ->
						return alert "Please restart your session by refreshing this page." unless data.success
						sectionTypeText = if elem.attr("data-sectiontype") is "lecture" then "Lecture" else if elem.attr("data-sectiontype") is "lab" then "Lab"
						elem.parents("div.btn-group").children("button").html "#{sectionTypeText}: #{elem.attr "data-section"} <span class='caret'></span>"
						elem.parents("div.btn-group").children("button").removeClass("status-conflict status-full status-limited status-free btn-danger btn-warning btn-success")
						if data.status or data.status is "yellow"
							elem.parents("div.btn-group").children("button").addClass if data.status is true then "status-free btn-success" else "status-limited btn-warning"
							elem.parents("tr").removeClass("error")
						else
							elem.parents("div.btn-group").children("button").addClass("status-full btn-danger")
							elem.parents("tr").addClass("error")
						setSchedule data.schedule
						setConflicts data.conflicts
						$("#timetable-grid tbody tr td").removeClass "hover"
				$("#courses-sections table tbody tr").mouseenter ->
					elem = $(@)
					$("#timetable-grid tbody tr td").filter(-> $(@).text().match elem.attr "data-coursenumber").addClass "hover"
				$("#courses-sections table tbody tr").mouseleave ->
					$("#timetable-grid tbody tr td").filter(-> $(@).text().match elem.attr "data-coursenumber").removeClass "hover"
			setSchedule data.schedule
			setConflicts data.conflicts

	$("#register_button").click ->
		socket.emit "confirmRegistration", (data) ->
			if data.success
				alert "Registration Complete!"
				setupLoginContainer()