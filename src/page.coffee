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
	constructor: ({studentId, name, registered, registeredOn, validated, validatedOn, validatedBy, difficultTimetable, bc, psc, el, reqEl, selectedcourses, _id}) ->
		@_id = ko.observable _id ? undefined
		@studentId = ko.observable studentId ? ""
		@name = ko.observable name ? ""
		@registered = ko.observable registered ? undefined
		@registeredOn = ko.observable new Date registeredOn ? Date()
		@validated = ko.observable validated ? undefined
		@validatedOn = ko.observable new Date validatedOn ? Date()
		@validatedBy = ko.observable validatedBy ? undefined
		@validatedByNI = ko.observable ""
		@difficultTimetable = ko.observable difficultTimetable ? undefined
		@bc = ko.observableArray bc ? []
		@psc = ko.observableArray psc ? []
		@el = ko.observableArray el ? []
		@reqEl = ko.observable reqEl ? 0
		@groups = ko.observableArray _(groups ? []).map (x) -> ko.observableArray x
		@selectedcourses = ko.observableArray selectedcourses ? []
		@courses = ko.observableArray []
		@coursesCI = ko.computed =>
			_(@courses()).map (x) =>
				compcode: x.compcode
				number: x.number
				name: x.name
				lectureSection: _(@selectedcourses()).find((z) => z.compcode is x.compcode)?.selectedLectureSection
				lectureSectionInstructor: _(x.lectureSections).find((y) => y.number is _(@selectedcourses()).find((z) => z.compcode is x.compcode)?.selectedLectureSection)?.instructor
				labSection: _(@selectedcourses()).find((z) => z.compcode is x.compcode)?.selectedLabSection
				labSectionInstructor: _(x.labSections).find((y) => y.number is _(@selectedcourses()).find((z) => z.compcode is x.compcode)?.selectedLabSection)?.instructor
				lectureSections: x.lectureSections
				labSections: x.labSections
	fetchCourses: =>
		socket.emit "getCoursesFor", {titles: $elemMatch: compcode: $in: _(@selectedcourses()).map((x) -> x.compcode)}, (courses) =>
			viewmodel.pleaseWaitStatus undefined
			@courses.removeAll()
			@courses do =>
				_.chain(courses).map((x) => _(x.titles).map (y) =>
					compcode: y.compcode
					number: y.number
					name: y.name
					lectureSections: x.lectureSections ? []
					labSections: x.labSections ? []
				).flatten(1).filter((x) => x.compcode in _(@selectedcourses()).map((y) -> y.compcode)).value()
	toggleRegistered: =>
		bootbox.confirm "Are you sure that you would like to unregister this student?", (result) ->
			if result
				@registered not @registered()
				@selectedcourses [] unless @registered()
				@difficultTimetable false
	validate: =>
		socket.emit "validate", @_id(), => viewmodel.studentsPackagesViewModel().fetchStudent()

class StudentsPackagesViewModel
	constructor: ->
		@student = ko.observable undefined
		@query = ko.observable ""
	fetchStudent: (elem, event) =>
		keyCode = event?.which ? event?.keyCode
		return unless keyCode in [13, 1, null, undefined]
		socket.emit "getStudent", studentId: @query(), (student) =>
			@student if student? then new StudentViewModel student else undefined
			@student().fetchCourses() if @student()?
			if @student()?.validated()
				socket.emit "getValidatorById", @student().validatedBy(), (validator) =>
					@student().validatedByNI validator.name

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
		@studentsPackagesViewModel = ko.observable undefined
		@pleaseWaitStatus = ko.observable undefined
		@pleaseWaitVisible = ko.computed => @pleaseWaitStatus()?
		@activeView = ko.observable undefined
		@authenticated = ko.observable false
		@username = ko.observable undefined
		@name = ko.observable undefined
		@nameNI = ko.computed => "#{@name()} (#{@username()})"
		@password = ko.observable undefined
		@loginAlertStatus = ko.observable undefined
	gotoStudents: =>
		@studentsPackagesViewModel new StudentsPackagesViewModel
		@activeView "studentsPackagesView"
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