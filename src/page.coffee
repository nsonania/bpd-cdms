# BPD-CDMS
# Author: Gautham Badhrinathan - b.gautham@gmail.com, fb.com/GotEmB

socket = undefined
viewmodel = undefined

arrayGroup = (array, lambda) ->
	group = []
	for obj in array
		k = lambda obj
		if _(group).any((x) -> x.criteria is k)
			_(group).find((x) -> x.criteria is k).collection.push obj
		else
			group.push
				criteria: k
				collection: [obj]
	group

class StudentViewModel
	constructor: ({studentId, name, registered, validated, difficultTimetable, _id}) ->
		@_id = ko.observable _id ? undefined
		@studentId = ko.observable studentId ? undefined
		@name = ko.observable name ? undefined
		@registered = ko.observable registered ? undefined
		@validated = ko.observable validated ? undefined
		@difficultTimetable = ko.observable difficultTimetable ? undefined
		@visible = ko.observable true
		@validateMessage = ko.computed =>
			unless @registered()
				"Registration Not Complete"
			else if @validated()
				"Registration Validated"
			else
				"Validate"
	validate: =>
		socket.emit "validate", @_id(), (success) =>
			@validated true if success

class StudentsViewModel
	constructor: ({students}) ->
		@students = ko.observableArray (new StudentViewModel student for student in students)
		@sort = ko.observable "studentId"
		@filteredStudents = ko.computed => _.chain(@students()).filter((x) -> x.visible()).sortBy((x) => x[@sort()]()).value()
	queryEnter: (elem, event) =>
		keyCode = event.which ? event.keyCode
		if keyCode is 13
			@fetchStudents arguments...
	sortStudentId: =>
		@sort "studentId"
	sortName: =>
		@sort "name"
	fetchStudents: =>
		viewmodel.pleaseWaitStatus "Fetching Students..."
		socket.emit "getStudents", $(arguments[1].currentTarget).val().toLowerCase(), (students) =>
			viewmodel.pleaseWaitStatus undefined
			@students (new StudentViewModel student for student in students)

class BodyViewModel
	constructor: ->
		@studentsViewModel = ko.observable undefined
		@pleaseWaitStatus = ko.observable undefined
		@pleaseWaitVisible = ko.computed => @pleaseWaitStatus()?
		@activeView = ko.observable undefined
		@authenticated = ko.observable false
		@username = ko.observable undefined
		@name = ko.observable undefined
		@nameNI = ko.computed => "#{@name()} (@username())"
		@password = ko.observable undefined
		@loginAlertStatus = ko.observable undefined
	gotoStudents: =>
		@pleaseWaitStatus "Fetching Students..."
		socket.emit "getStudents", "", (students) =>
			@pleaseWaitStatus undefined
			@studentsViewModel new StudentsViewModel students: students
			@activeView "studentsView"
			$("#studentheader, #studentdetails").affix offset: top: 290
			$('button[rel=tooltip]').tooltip()
	login: =>
		@loginAlertStatus undefined
		@pleaseWaitStatus "Authenticating..."
		socket.emit "login", @username(), md5(@password()), (data) =>
			@pleaseWaitStatus undefined
			if data isnt false
				@authenticated true
				@password undefined
				@username data.username
				@name data.name
				@gotoStudents()
			else
				@loginAlertStatus "authFailure"
	dismissLoginAlert: =>
		@loginAlertStatus undefined
	logout: =>
		socket.emit "logout", =>
			@username undefined
			@name undefined
			@authenticated false

$ ->
	window.viewmodel = viewmodel = new BodyViewModel()
	viewmodel.pleaseWaitStatus "Connecting..."
	ko.applyBindings viewmodel, $("body")[0]

	socket = io.connect()
	socket.on "connect", ->
		viewmodel.pleaseWaitStatus undefined

	socket.on "studentStatusChanged", (student_id, what, that) ->
		_(viewmodel.studentsViewModel().students()).find((x) -> x._id() is student_id)[what] that

	socket.on "destroySession", ->
		viewmodel.logout()
		viewmodel.loginAlertStatus "remoteLogout"