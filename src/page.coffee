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
	selectStudent: =>
		viewmodel.studentsViewModel().currentStudent @
	validate: =>
		socket.emit "validate", @_id, (success) =>
			@validated true if success

class StudentsViewModel
	constructor: ({students}) ->
		@students = ko.observableArray (new StudentViewModel student for student in students)
		@sort = ko.observable "studentId"
		@filteredStudents = ko.computed => _.chain(@students()).filter((x) -> x.visible()).sortBy((x) => x[@sort()]()).value()
		@currentStudent = ko.observable @filteredStudents()[0]
	filter: =>
		query = $(arguments[1].currentTarget).val().toLowerCase()
		for student in @students()
			student.visible false
			if student.studentId().toLowerCase().indexOf(query) >= 0
				student.visible true
			if student.name().toLowerCase().indexOf(query) >= 0
				student.visible true
	sortStudentId: =>
		@sort "studentId"
	sortName: =>
		@sort "name"
	fetchStudents: =>
		viewmodel.pleaseWaitStatus "Fetching Students..."
		socket.emit "getStudents", (students) =>
			viewmodel.pleaseWaitStatus undefined
			@students (new StudentViewModel student for student in students)
			@currentStudent @filteredStudents()[0]

class BodyViewModel
	constructor: ->
		@studentsViewModel = ko.observable undefined
		@pleaseWaitStatus = ko.observable undefined
		@pleaseWaitVisible = ko.computed => @pleaseWaitStatus()?
		@activeView = ko.observable undefined
		@authenticated = ko.observable false
		@username = ko.observable undefined
		@password = ko.observable undefined
		@loginAlertStatus = ko.observable undefined
	gotoStudents: =>
		viewmodel.pleaseWaitStatus "Fetching Students..."
		socket.emit "getStudents", (students) ->
			viewmodel.pleaseWaitStatus undefined
			viewmodel.studentsViewModel new StudentsViewModel students: students
			viewmodel.activeView "studentsView"
			$("#studentheader, #studentdetails").affix offset: top: 290
			$('button[rel=tooltip]').tooltip()
	login: =>
		viewmodel.pleaseWaitStatus "Authenticating..."
		socket.emit "login", accessCode, (success) =>
			viewmodel.pleaseWaitStatus undefined
			if success
				@authenticated true
				@password undefined
				@gotoStudents()
			else
				@loginAlertStatus "authFailure"
	dismissLoginAlert: =>
		@loginAlertStatus undefined
	logout: =>
		socket.emit "logout", =>
			@username undefined
			@authenticated false

$ ->
	window.viewmodel = viewmodel = new BodyViewModel()
	viewmodel.pleaseWaitStatus "Connecting..."
	ko.applyBindings viewmodel, $("body")[0]

	socket = io.connect()
	socket.on "connect", ->
		viewmodel.pleaseWaitStatus undefined