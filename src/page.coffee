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
				else
					global.student = data.student
					setupMainContainer()

		setupMainContainer = ->
			resetContainers()
			$("#main-container").removeClass("hide")
			$(".nav.pull-right").removeClass("hide")
			$("#current-student").text("#{global.student.name} (#{global.student.studentId})")

			socket.emit "initializeSectionsScreen", (data) ->
				console.log data
				return alert "Please restart your session by refreshing this page." unless data.success
				$("<tbody></tbody>").appendTo("#courses-sections table")
				for course in data.selectedcourses
					hasLectures = ->
						selectedSection = if course.selectedLectureSection? then ": #{course.selectedLectureSection}" else ""
						sectionColorClass =
							if course.reserved
								"btn-success disabled"
							else if selectedSection isnt ""
								section = (section for section in course.lectureSections when section.number is course.selectedLectureSection)[0]
								if section.status.isFull then "btn-danger"
								else if section.status.last5Left then "btn-warning"
								else "btn-success"
							else
								""
						"""
						<div class="btn-group">
							<button class="btn dropdown-toggle #{sectionColorClass}" data-toggle="dropdown">Lecture#{selectedSection} <span class="caret"></span></button>
							<ul class="dropdown-menu">
								#{
									ret =
										for section in course.lectureSections
											liClass = if section.status.isFull then "error" else if section.status.last5Left then "warning" else ""
											"<li class='#{liClass}' data-course='#{course.compcode}' data-sectiontype='lecture' data-section='#{section.number}'><a><strong>#{section.number}</strong>: #{section.instructor}</a></li>"
									ret.join("\n")
								}
							</ul>
						</div>
						"""
					hasLab = ->
						selectedSection = if course.selectedLabSection? then ": #{course.selectedLabSection}" else ""
						sectionColorClass =
							if course.reserved
								"btn-success disabled"
							else if selectedSection isnt ""
								section = (section for section in course.labSections when section.number is course.selectedLabSection)[0]
								if section.status.isFull then "btn-danger"
								else if section.status.last5Left then "btn-warning"
								else "btn-success"
							else
								""
						"""
						<div class="btn-group">
							<button class="btn dropdown-toggle #{sectionColorClass}" data-toggle="dropdown">Lab#{selectedSection} <span class="caret"></span></button>
							<ul class="dropdown-menu">
								#{
									ret =
										for section in course.labSections
											liClass = if section.status.isFull then "error" else if section.status.last5Left then "warning" else ""
											"<li class='#{liClass}' data-course='#{course.compcode}' data-sectiontype='lab' data-section='#{section.number}'><a><strong>#{section.number}</strong>: #{section.instructor}</a></li>"
									ret.join("\n")
								}
							</ul>
						</div>
						"""
					elem =
						"""
						<tr>
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
						return if elem.hasClass "error"
						msg =
							course_compcode: parseInt elem.attr "data-course"
							section_number: parseInt elem.attr "data-section"
							isLectureSection: if elem.attr("data-sectiontype") is "lecture" then true
							isLabSection: if elem.attr("data-sectiontype") is "lab" then true
						socket.emit "chooseSection", msg, (data) ->
							return alert "Please restart your session by refreshing this page." unless data.success
							if data.status or data.status is "yellow"
								elem.parents("div.btn-group").children("button").removeClass("btn-danger").addClass if data.status then "btn-success" else "btn-warning"
								elem.parents("tr").removeClass("error")
							else
								elem.parents("div.btn-group").children("button").removeClass("btn-success").addClass("btn-danger")
								elem.parents("tr").addClass("error")
							sectionTypeText = if elem.attr("data-sectiontype") is "lecture" then "Lecture" else if elem.attr("data-sectiontype") is "lab" then "Lab"
							elem.parents("div.btn-group").children("button").html "#{sectionTypeText}: #{elem.attr "data-section"} <span class='caret'></span>"