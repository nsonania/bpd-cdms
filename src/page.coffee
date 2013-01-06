socket = undefined
viewmodel = undefined

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
	constructor: ({@_id, @compcode, @number, @name, selected}) ->
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
		saveCourses = =>
			viewmodel.pleaseWaitVisible true
			socket.emit "saveCourses", @toData(), =>
				viewmodel.pleaseWaitVisible false
				viewmodel.gotoSectionsView()
		if @nextStepWarning()
			bootbox.confirm "You haven't registered for all the courses prescribed in your program. As a result you might end up doing an extra semester.", (result) =>
				saveCourses() if result
		else
			saveCourses()
	toData: =>
		bc: _(@bc()).map (x) -> course_id: x._id, selected: x.selected()
		psc: _(@psc()).map (x) -> course_id: x._id, selected: x.selected()
		el: _(@allEl()).map (x) -> course_id: x._id, selected: x.selected()

class SectionViewModel
	constructor: ({@number, @instructor, status}, @parent) ->
		@status = ko.observable if status.isFull then "isFull" else if status.lessThan5 then "lessThan5" else undefined
	chooseLectureSection: =>
		sectionInfo =
			course_compcode: @parent.compcode
			section_number: @number
			isLectureSection: true
		socket.emit "chooseSection", sectionInfo, ({status, schedule}) =>
			@parent.selectedLectureSection @number
			@status if status.isFull then "isFull" else if status.lessThan5 then "lessThan5" else undefined
			#Schedule & Conflicts
			viewmodel.sectionsViewModel.setSchedule schedule
	chooseLabSection: =>
		sectionInfo =
			course_compcode: @parent.compcode
			section_number: @number
			isLabSection: true
		socket.emit "chooseSection", sectionInfo, ({status, schedule}) =>
			@parent.selectedLabSection @number
			@status if status.isFull then "isFull" else if status.lessThan5 then "lessThan5" else undefined
			#Schedule & Conflicts
			viewmodel.sectionsViewModel.setSchedule schedule

class CourseSectionsViewModel
	constructor: ({@compcode, @number, @name, @hasLectures, @hasLab, lectureSections, labSections, selectedLectureSection, selectedLabSection}) ->
		@lectureSections = ko.observableArray (new SectionViewModel section, @ for section in lectureSections ? [])
		@labSections = ko.observableArray (new SectionViewModel section, @ for section in labSections ? [])
		@selectedLectureSection = ko.observable selectedLectureSection
		@selectedLabSection = ko.observable selectedLabSection
		@selectedLectureSectionText = ko.computed => "Lecture" + if @selectedLectureSection()? then ": " + @selectedLectureSection() else ""
		@selectedLabSectionText = ko.computed => "Lab" + if @selectedLabSection()? then ": " + @selectedLabSection() else ""
		@selectedLectureSectionStatus = ko.computed => _(@lectureSections()).find((x) => x.number is @selectedLectureSection()).status() if @selectedLectureSection()?
		@selectedLabSectionStatus = ko.computed => _(@labSections()).find((x) => x.number is @selectedLabSection()).status() if @selectedLabSection()?

class SectionsViewModel
	constructor: ->
		@courses = ko.observableArray []
		@schedule = (ko.observableArray [] for x in [1..7] for y in [1..10])

	gotoCoursesView: =>
		viewmodel.gotoCoursesView()
	setSchedule: (schedule) =>
		for k1 in [1..7]
			for k2 in [1..10]
				@schedule[k2 - 1][k1 - 1].removeAll()
		for k1, day of schedule
			for k2, hour of day
				for course_number in hour
					@schedule[k2 - 1][k1 - 1].push course_number

class BodyViewModel
	constructor: ->
		@studentName = ko.observable undefined
		@studentId = ko.observable undefined
		@studentNI = ko.computed => "#{@studentName()} (#{@studentId()})"
		@authenticated = ko.observable false
		@semesterTitle = ko.observable undefined
		@startTime = ko.observable undefined
		@activeView = ko.observable undefined
		@loginViewModel = new LoginViewModel()
		@coursesViewModel = new CoursesViewModel()
		@sectionsViewModel = new SectionsViewModel()
		@pleaseWaitVisible = ko.observable false
		@activeViewNZ = ko.computed =>
			if @pleaseWaitVisible() then "pleaseWait"
			else unless @authenticated() then "loginView"
			else @activeView()
	gotoCoursesView: =>
		@activeView "coursesView"
		@pleaseWaitVisible true
		socket.emit "getCourses", ({success, bc, psc, el, reqEl}) =>
			@coursesViewModel.bc (new CourseViewModel course for course in bc ? [])
			@coursesViewModel.psc (new CourseViewModel course for course in psc ? [])
			@coursesViewModel.allEl (new CourseViewModel course for course in el ? [])
			@coursesViewModel.reqEl reqEl ? 0
			@pleaseWaitVisible false
	gotoSectionsView: =>
		@activeView "sectionsView"
		@pleaseWaitVisible true
		socket.emit "initializeSectionsScreen", ({success, selectedcourses, schedule, conflicts}) =>
			@sectionsViewModel.courses (new CourseSectionsViewModel course for course in selectedcourses ? [])
			#Schedule & Conflicts
			@sectionsViewModel.setSchedule schedule
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

	$('input[rel=tooltip]').tooltip()

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

	#pubsub = io.connect "http://bpd-cdms-pubsub.herokuapp.com:80"
	#pubsub.on "connect", ->
	#	setupLoginContainer()

	setupSectionsContainer = ->
		$("#courses-sections tbody").remove()
		$("#timetable-grid tbody tr td:not(:first-of-type)").text ""

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
			return alert "Please restart your session by refreshing this page." unless data.success
			for course in data.selectedcourses
				#...|||...#
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