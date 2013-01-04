socket = undefined
viewmodel = viewmodel = undefined

class LoginViewModel
	constructor: ->
		@studentId = ko.observable undefined
		@password = ko.observable undefined
		@alertStatus = ko.observable undefined
	login: =>
		viewmodel.pleaseWaitVisible true
		@alertStatus undefined
		socket.emit "login", studentId: @studentId() ? "", password: md5(@password() ? ""), (data) =>
			viewmodel.pleaseWaitVisible false
			unless data.success
				@alertStatus "authFailure"
			else if data.registered
				@alertStatus "alreadyRegistered"
			else
				viewmodel.studentName data.student.name
				viewmodel.studentId data.student.studentId
				viewmodel.authenticated true
				viewmodel.gotoCoursesView()
				socket.once "destroySession", ->
					alert "Your session has expired."
					viewmodel.authenticated false
					viewmodel.activeView "loginView"
	dismissAlert: =>
		@alertStatus undefined

class CourseViewModel
	constructor: ({@compcode, @number, @name, selected}) ->
		@selected = ko.observable selected
	toggleSelection: =>
		@selected not @selected()
	electiveMouseOver: =>
		window.viewmodel.coursesViewModel.selectedValueDropdown @
	electiveSelect: =>
		@selected true

class CoursesViewModel
	constructor: ->
		@bc = ko.observableArray []
		@psc = ko.observableArray []
		@allEl = ko.observableArray []
		@el = ko.computed => _(@allEl()).filter (x) -> x.selected()
		@reqEl = ko.observable 0
		@electiveQuery = ko.observable ""
		@selectedValueDropdown = ko.observable undefined
		@electiveChoices = ko.computed =>
			return [] if @electiveQuery() is ""
			els = _(@allEl()).filter (x) =>
				return false if x.selected()
				return true if x.compcode.toLowerCase().indexOf(@electiveQuery().toLowerCase()) >= 0
				return true if x.number.toLowerCase().indexOf(@electiveQuery().toLowerCase()) >= 0
				return true if x.name.toLowerCase().indexOf(@electiveQuery().toLowerCase()) >= 0
				false
			@selectedValueDropdown els[0]
			_(els).take 5
		@blEnabled = ko.computed => _(@psc()).all((x) -> not x.selected()) and @el().length is 0
		@pscEnabled = ko.computed => _(@bc()).all((x) -> x.selected()) and @el().length <= @reqEl()
		@elEnabled = ko.computed => _(@bc()).all (x) -> x.selected()
		@elsEnabled = ko.computed => @el().length < @reqEl() or _(@psc()).all((x) -> x.selected()) or not @elEnabled()
		@nextStepWarning = ko.computed => not @elsEnabled() or not @elEnabled()
	electiveQueryKeyDown: =>
		event = arguments[1]
		if event.which is 38 and @electiveChoices().indexOf(@selectedValueDropdown()) > 0
			@selectedValueDropdown @electiveChoices()[@electiveChoices().indexOf(@selectedValueDropdown()) - 1]
		else if event.which is 40 and @electiveChoices().indexOf(@selectedValueDropdown()) < @electiveChoices().length - 1
			@selectedValueDropdown @electiveChoices()[@electiveChoices().indexOf(@selectedValueDropdown()) + 1]
		else if event.which is 13
			@selectedValueDropdown().electiveSelect()
			@electiveQuery ""
		unless event.which in [13, 38, 40] and @electiveChoices().length > 0
			return true
	nextStep: =>
		bootbox.alert "You haven't registered for all the courses prescribed in your program. As a result you might end up doing an extra semester." if @nextStepWarning()


class BodyViewModel
	constructor: ->
		@studentName = ko.observable undefined
		@studentId = ko.observable undefined
		@studentNI = ko.computed => "#{@studentName} (#{@studentId})"
		@authenticated = ko.observable false
		@semesterTitle = ko.observable undefined
		@startTime = ko.observable undefined
		@activeView = ko.observable undefined
		@loginViewModel = new LoginViewModel()
		@coursesViewModel = new CoursesViewModel()
		@pleaseWaitVisible = ko.observable false
		@activeViewNZ = ko.computed =>
			if @pleaseWaitVisible() then "pleaseWait"
			else unless @authenticated() then "loginView"
			else @activeView()
	gotoCoursesView: =>
		@activeView "coursesView"
		@pleaseWaitVisible true
		socket.emit "getCourses", ({bc, psc, el, reqEl}) =>
			@coursesViewModel.bc (new CourseViewModel course for course in bc ? [])
			@coursesViewModel.psc (new CourseViewModel course for course in psc ? [])
			@coursesViewModel.allEl (new CourseViewModel course for course in el ? [])
			@coursesViewModel.reqEl reqEl ? 0
			@pleaseWaitVisible false

$ ->
	window.viewmodel = viewmodel = new BodyViewModel()
	viewmodel.pleaseWaitVisible true
	ko.applyBindings viewmodel, $("body")[0]

	socket = io.connect()
	socket.on "connect", ->
		socket.emit "getSemesterDetails", ({semesterTitle, startTime}) ->
			viewmodel.semesterTitle semesterTitle
			viewmodel.startTime new Date startTime
			viewmodel.pleaseWaitVisible false

$.extend
	postJSON: (url, data, callback) ->
		jQuery.ajax
			type: "POST"
			url: url
			data: JSON.stringify(data)
			success: callback
			dataType: "json"
			contentType: "application/json"
			processData: false

$(document).ready ->
	return
	$("#loginbox input").addClass if $(document).width() >= 1200 then "span3" else "span2"
	$("#courses-sections, .courses-selections").addClass if $(document).width() >= 1200 then "span8 offset2" else "span12"
	$("#timetable-grid").addClass if $(document).width() >= 1200 then "span10 offset1" else "span12"
	$(window).resize ->
		if $(document).width() >= 1200
			$("#loginbox input").removeClass("span2").addClass("span3")
			$("#courses-sections, .courses-selections").removeClass("span12").addClass("span8 offset2")
			$("#timetable-grid").removeClass("span12").addClass("span10 offset1")
		else
			$("#loginbox input").removeClass("span3").addClass("span2")
			$("#courses-sections, .courses-selections").removeClass("span8 offset2").addClass("span12")
			$("#timetable-grid").removeClass("span10 offset1").addClass("span12")

	resetContainers = ->
		$("#prelogin-container, #login-container, #sections-container").addClass("hide")
		$("#courses-sections tbody").remove()
		$("#timetable-grid tbody tr td:not(:first-of-type)").text ""

	pubsub = io.connect "http://bpd-cdms-pubsub.herokuapp.com:80"
	pubsub.on "connect", ->
		setupLoginContainer()

	setupLoginContainer = ->
		resetContainers()
		pubsub.removeAllListeners() if global.student?
		global = {}
		$("#login-container").removeClass("hide")
		$(".nav.pull-right").addClass("hide")
		$("#current-student").text("")
		$("#input-studentid").val("")
		$("#input-password").val("")

	$("#input-studentid").tooltip()
	$("#submit-login").click ->
		#truncated

	setupSectionsContainer = ->
		resetContainers()
		$("#prelogin-container").removeClass "hide"
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
			if $("#courses-sections tbody tr .btn-group .btn:not(.btn-success, .btn-warning)").length > 0
				$("#register_button").addClass "disabled"
			else
				$("#register_button").removeClass "disabled"

		$.postJSON "/api/initializeSectionsScreen", hash: global.hash, (data) ->
			$("#prelogin-container").addClass "hide"
			$("#sections-container").removeClass "hide"
			return alert "Please restart your session by refreshing this page." unless data.success
			global.student[key] = value for key, value of data when key isnt "success"
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
						<button class="btn dropdown-toggle #{sectionColorClass}" data-sectiontype="lecture" data-selectedsection="#{course.selectedLectureSection ? ""}" data-toggle="dropdown">Lecture#{selectedSection} <span class="caret"></span></button>
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
						<button class="btn dropdown-toggle #{sectionColorClass}" data-sectiontype="lab" data-selectedsection="#{course.selectedLabSection ? ""}" data-toggle="dropdown">Lab#{selectedSection} <span class="caret"></span></button>
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
				tr =
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
				tr = $(tr).appendTo("#courses-sections table tbody")
				tr.find("td div.btn-group li").click ->
					elem = $(@)
					sectionInfo =
						course_compcode: parseInt elem.attr "data-course"
						section_number: parseInt elem.attr "data-section"
						isLectureSection: if elem.attr("data-sectiontype") is "lecture" then true
						isLabSection: if elem.attr("data-sectiontype") is "lab" then true
					$.postJSON "/api/chooseSection", sectionInfo: sectionInfo, hash: global.hash, (data) ->
						return alert "Please restart your session by refreshing this page." unless data.success
						sectionTypeText = if elem.attr("data-sectiontype") is "lecture" then "Lecture" else if elem.attr("data-sectiontype") is "lab" then "Lab"
						elem.parents("div.btn-group").children("button").html "#{sectionTypeText}: #{elem.attr "data-section"} <span class='caret'></span>"
						elem.parents("div.btn-group").children("button").removeClass("status-conflict status-full status-limited status-free btn-danger btn-warning btn-success")
						elem.parents("div.btn-group").children("button").attr "data-selectedsection", sectionInfo.section_number
						if data.status or data.status is "yellow"
							elem.parents("div.btn-group").children("button").addClass if data.status is true then "status-free btn-success" else "status-limited btn-warning"
							elem.parents("tr").removeClass("error")
						else
							elem.parents("div.btn-group").children("button").addClass("status-full btn-danger")
							elem.parents("tr").addClass("error")
						setSchedule data.schedule
						setConflicts data.conflicts
						$("#timetable-grid tbody tr td").removeClass "hover"
				tr.mouseenter ->
					elem = $(@)
					$("#timetable-grid tbody tr td").filter(-> $(@).text().match elem.attr "data-coursenumber").addClass "hover"
				tr.mouseleave ->
					elem = $(@)
					$("#timetable-grid tbody tr td").filter(-> $(@).text().match elem.attr "data-coursenumber").removeClass "hover"
				pubsub.on "course_#{course.compcode}", (data) ->
					$("li[data-course='#{course.compcode}'][data-sectiontype='#{data.sectionType}'][data-section='#{data.sectionNumber}']")
						.removeClass("error warning")
						.addClass if data.status.isFull then "error" else if data.status.lessThan5 then "warning" else ""
					$("tr[data-compcode='#{course.compcode}'] .btn[data-sectiontype'#{data.sectionType}'][data-selectedsection='#{data.sectionNumber}']").not("status-conflict")
						.removeClass("status-full status-limited status-free btn-danger btn-warning btn-success")
						.addClass if data.status.isFull then "status-full btn-danger" else if data.status.lessThan5 then "status-limited btn-warning" else "status-free btn-success"	
					if $("#courses-sections tbody tr .btn-group .btn:not(.btn-success, .btn-warning)").length > 0
						$("#register_button").addClass "disabled"
					else
						$("#register_button").removeClass "disabled"
			setSchedule data.schedule
			setConflicts data.conflicts

	$("#register_button").click ->
		return if $(@).hasClass "disabled"
		$.postJSON "/api/confirmRegistration", hash: global.hash, (data) ->
			if data.success
				alert "Registration Complete!"
			else if data.invalidRegistration
				alert "Registration was not successful. Please login again."
			else
				alert "An unknown error has occured. Please login again."
			setupLoginContainer()

	$("#logout_button").click ->
		setupLoginContainer()