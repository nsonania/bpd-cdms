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

class ScheduleSlot
	constructor: ({day, hour, busy}) ->
		@day = ko.observable day
		@hour = ko.observable hour
		@busy = ko.observable busy
		@slot = ko.computed => "#{@day()}#{@hour()}"
	toggleSlot: =>
		@busy not @busy()

class SectionViewModel
	constructor: ({number, instructor, timeslots, capacity} = {number: null, instructor: null, timeslots: [], capacity: null}) ->
		@number = ko.observable number
		@instructor = ko.observable instructor
		@timetable = ko.observableArray do ->
			for hour, h in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "E"] then ko.observableArray do ->
				for day, d in ["Su", "M", "T", "W", "Th", "F", "S"]
					new ScheduleSlot
						day: day
						hour: hour
						busy: _(timeslots).any (x) -> x.day is d + 1 and x.hour is h + 1
		@capacity = ko.observable capacity
	editSection: =>
		viewmodel.coursesViewModel().currentSection @
		$("#sectiondetails").modal "show"
	deleteSection: =>
		if viewmodel.coursesViewModel().currentCourse().lectureSections().indexOf viewmodel.coursesViewModel().currentSection() >= 0
			viewmodel.coursesViewModel().currentCourse().lectureSections.remove viewmodel.coursesViewModel().currentSection()
		else if viewmodel.coursesViewModel().currentCourse().labSections().indexOf viewmodel.coursesViewModel().currentSection() >= 0
			viewmodel.coursesViewModel().currentCourse().labSections.remove viewmodel.coursesViewModel().currentSection()
	toData: =>
		timeslots =
			for hour, h in @timetable()
				for day, d in hour() when day.busy()
					day: d + 1
					hour: h + 1
		number: Number @number()
		instructor: @instructor()
		capacity: Number @capacity()
		timeslots: _(timeslots).flatten()

class CourseViewModel
	constructor: ({compcode, number, name, @lectureSections, @labSections, @otherDates}) ->
		@compcode = ko.observable compcode ? ""
		@number = ko.observable number ? "null"
		@name = ko.observable name ? "null"
		@visible = ko.observable true
		@sharedSections = ko.computed
			read: =>
				return unless viewmodel.coursesViewModel()?
				_.chain(viewmodel.coursesViewModel().courses()).filter((x) => x.lectureSections() is @lectureSections() and x.labSections() is @labSections() and x isnt @).map((x) => x.compcode()).sortBy((x) -> x).value().join ", "
			write: (value) =>
				return unless viewmodel.coursesViewModel()?
				oldS = _(viewmodel.coursesViewModel().courses()).filter (x) => x.lectureSections() is @lectureSections() and x.labSections() is @labSections()
				newS = _.chain(value.split(/\ *[;,\/]\ */)).filter((x) -> x not in ["", null, undefined]).map((x) => _(viewmodel.coursesViewModel().courses()).find (y) => y.compcode() is Number x).union([@]).uniq().value()
				addS = _(newS).difference oldS
				remS = _(oldS).difference newS
				oldLectureSections = oldS[0].lectureSections
				oldLabSections = oldS[0].labSections
				oldOtherDates = oldS[0].otherDates
				newLectureSections = ko.observableArray _(oldLectureSections()).map (x) -> new SectionViewModel x.toData()
				newLabSections = ko.observableArray _(oldLabSections()).map (x) -> new SectionViewModel x.toData()
				newOtherDates = ko.observableArray oldOtherDates().slice()
				_(addS).each (x) ->
					x.lectureSections oldLectureSections()
					x.labSections oldLabSections()
					x.otherDates oldOtherDates()
				_(remS).each (x) ->
					x.lectureSections newLectureSections()
					x.labSections newLabSections()
					x.otherDates newOtherDates()
		@otherDatesNI = ko.computed
			read: =>
				@otherDates().join ", "
			write: (value) =>
				@otherDates.removeAll()
				@otherDates.push _(value.split(/\ *[;,]\ */)).filter((x) -> x not in ["", null, undefined])...
	selectCourse: =>
		viewmodel.coursesViewModel().currentCourse @
	deleteCourse: =>
		viewmodel.coursesViewModel().courses.remove @
		viewmodel.coursesViewModel().filteredCourses()[0].selectCourse()
	distributeCapacity: =>
		newCapacity = $(arguments[1].currentTarget).prev().val()
		$(arguments[1].currentTarget).prev().val ""
		if $.isNumeric newCapacity
			newCapacity = Number newCapacity
		else
			alert "Total Capacity is not a number."
			return
		if @lectureSections().length > 0
			capacityPerSection = Math.floor newCapacity / @lectureSections().length
			extra = newCapacity % @lectureSections().length
			for section, s in @lectureSections()
				section.capacity capacityPerSection + if s < extra then 1 else 0
		if @labSections().length > 0
			capacityPerSection = Math.floor newCapacity / @labSections().length
			extra = newCapacity % @labSections().length
			for section, s in @labSections()
				section.capacity capacityPerSection + if s < extra then 1 else 0
	addLectureSection: =>
		@lectureSections.push section = new SectionViewModel()
		section.editSection()
	addLabSection: =>
		@labSections.push section = new SectionViewModel()
		section.editSection()
	exportCSV: =>
		window.open "course.csv?compcode=#{@compcode()}"
	toData: =>
		compcode: @compcode()
		number: @number()
		name: @name()
		hasLectureSections: true if @lectureSections().length > 0
		lectureSections: section.toData() for section in @lectureSections() if @lectureSections().length > 0
		hasLabSections: true if @labSections().length > 0
		labSections: section.toData() for section in @labSections() if @labSections().length > 0
		otherDates: @otherDates()
class CoursesViewModel
	constructor: ({courses}) ->
		@courses = ko.observableArray _.chain(courses).map((x) ->
			lectureSections =  ko.observableArray (new SectionViewModel section for section in x.lectureSections ? [])
			labSections = ko.observableArray (new SectionViewModel section for section in x.labSections ? [])
			otherDates = ko.observableArray (date for date in x.otherDates ? [])
			_(x.titles).map (y) ->
				new CourseViewModel
					compcode: y.compcode
					number: y.number
					name: y.name
					lectureSections: lectureSections
					labSections: labSections
					otherDates: otherDates
		).flatten().value()
		@sort = ko.observable "compcode"
		@filteredCourses = ko.computed => _.chain(@courses()).filter((x) -> x.visible()).sortBy((x) => x[@sort()]()).value()
		@currentCourse = ko.observable @filteredCourses()[0]
		@currentSection = ko.observable undefined
	filter: =>
		query = $(arguments[1].currentTarget).val().toLowerCase()
		for course in @courses()
			course.visible false
			if course.compcode().toString().indexOf(query) >= 0
				course.visible true
			if course.number().toLowerCase().indexOf(query) >= 0
				course.visible true
			if course.name().toLowerCase().indexOf(query) >= 0
				course.visible true
	newCourse: =>
		@courses.push course = new CourseViewModel {}
		course.selectCourse()
		scrollTo 0, document.height
	fetchCourses: =>
		viewmodel.pleaseWaitStatus "Fetching Courses..."
		socket.emit "getCourses", (courses) =>
			viewmodel.pleaseWaitStatus undefined
			@courses _.chain(courses).map((x) ->
				lectureSections =  ko.observableArray (new SectionViewModel section for section in x.lectureSections ? [])
				labSections = ko.observableArray (new SectionViewModel section for section in x.labSections ? [])
				otherDates = ko.observableArray (date for date in x.otherDates ? [])
				_(x.titles).map (y) ->
					new CourseViewModel
						compcode: y.compcode
						number: y.number
						name: y.name
						lectureSections: lectureSections
						labSections: labSections
						otherDates: otherDates
			).flatten().value()
			@currentCourse @filteredCourses()[0]
	commitCourses: =>
		viewmodel.pleaseWaitStatus "Saving changes..."
		courses = @toData()
		socket.emit "commitCourses", courses, (result) =>
			viewmodel.pleaseWaitStatus undefined
	sortCompcode: =>
		@sort "compcode"
	sortNumber: =>
		@sort "number"
	sortName: =>
		@sort "name"
	selectFile: =>
		$fup = $("<input type='file' accept='text/csv'>")
		$fup.one "change", =>
			return if $fup[0].files.length is 0
			fs = new FileReader()
			fs.onload = (e) =>
				viewmodel.pleaseWaitStatus "Importing Courses..."
				socket.emit "importCourses", e.target.result, (success) =>
					viewmodel.pleaseWaitStatus undefined
					if success
						@fetchCourses()
					else
						alert "Parsing Error. Please recheck .csv file for errors."
			fs.readAsText $fup[0].files[0]
		$fup.trigger "click"
	deleteAll: =>
		viewmodel.pleaseWaitStatus "Deleting all Courses..."
		socket.emit "deleteAllCourses", (success) =>
			viewmodel.pleaseWaitStatus undefined
			@fetchCourses()
	toData: =>
		_(arrayGroup @courses(), (x) -> x.lectureSections()).map (x) ->
			titles:
				for y in x.collection
					compcode: y.compcode()
					number: y.number()
					name: y.name()
			hasLectureSections: true if x.collection[0].lectureSections().length > 0
			lectureSections: section.toData() for section in x.collection[0].lectureSections() if x.collection[0].lectureSections().length > 0
			hasLabSections: true if x.collection[0].labSections().length > 0
			labSections: section.toData() for section in x.collection[0].labSections() if x.collection[0].labSections().length > 0
			otherDates: x.collection[0].otherDates()

class SelectedCourseViewModel
	constructor: ({compcode, selectedLectureSection, selectedLabSection}) ->
		@compcode = ko.observable compcode
		@selectedLectureSection = ko.observable selectedLectureSection
		@selectedLabSection = ko.observable selectedLabSection
	toData: =>
		compcode: @compcode()
		selectedLectureSection: @selectedLectureSection()
		selectedLabSection: @selectedLabSection()

class StudentViewModel
	constructor: ({studentId, name, newPassword, password, registered, validated, validatedBy, difficultTimetable, bc, psc, el, reqEl, selectedcourses, _id}) ->
		@_id = ko.observable _id ? undefined
		@studentId = ko.observable studentId ? ""
		@name = ko.observable name ? ""
		@password = ko.observable password ? ""
		@newPassword = ko.observable newPassword ? undefined
		@registered = ko.observable registered ? undefined
		@validated = ko.observable validated ? undefined
		@validatedBy = ko.observable validatedBy ? undefined
		@validatedByNI = ko.computed =>
			if @validated()
				if @validatedBy()? and (vuser = _(viewmodel.validatorsViewModel().validators()).find((x) => x._id() is @validatedBy())?.username())?
					"Validated by #{vuser}"
				else
					"Validated"
			else
				"Not Validated"
		@difficultTimetable = ko.observable difficultTimetable ? undefined
		@bc = ko.observableArray bc ? []
		@psc = ko.observableArray psc ? []
		@el = ko.observableArray el ? []
		@reqEl = ko.observable reqEl ? 0
		@selectedcourses = ko.observableArray (new SelectedCourseViewModel sc for sc in selectedcourses ? [])
		@courses = ko.computed =>
			for course in viewmodel.coursesViewModel().courses()
				course: course
				bc: @bc().indexOf(course.compcode()) >= 0
				psc: @psc().indexOf(course.compcode()) >= 0
				el: @el().indexOf(course.compcode()) >= 0
				selected: _(@selectedcourses()).any (x) => x.compcode() is course.compcode()
				selectedLectureSection: _(@selectedcourses()).find((x) => x.compcode() is course.compcode()).selectedLectureSection() if course.lectureSections().length > 0 and _(@selectedcourses()).any (x) => x.compcode() is course.compcode()
				selectedLabSection: _(@selectedcourses()).find((x) => x.compcode() is course.compcode()).selectedLabSection() if course.labSections().length > 0 and _(@selectedcourses()).any (x) => x.compcode() is course.compcode()
		@filterCategory = ko.observable 1
		@query = ko.observable ""
		@filteredCourses = ko.computed =>
			query = @query().toLowerCase()
			cat = 
				switch @filterCategory()
					when 0 then @courses()
					when 1 then _(@courses()).filter (x) => x.bc or x.psc or x.el
					when 2 then _(@courses()).filter (x) => x.selected
			_(cat).filter (x) =>
				course = x.course
				if course.compcode().toString().indexOf(query) >= 0
					true
				else if course.number().toLowerCase().indexOf(query) >= 0
					true
				else if course.name().toLowerCase().indexOf(query) >= 0
					true
		@modified = ko.observable false
		@studentId.subscribe => @modified true
		@name.subscribe => @modified true
		@password.subscribe => @modified true
		@registered.subscribe => @modified true
		@validated.subscribe => @modified true
		@bc.subscribe => @modified true
		@psc.subscribe => @modified true
		@el.subscribe => @modified true
		@reqEl.subscribe => @modified true
		@selectedcourses.subscribe => @modified true
	selectStudent: =>
		viewmodel.studentsViewModel().currentStudent @
		$('button.vbn').tooltip "destroy"
		$('button.vbn').tooltip title: @validatedByNI
	deleteStudent: =>
		viewmodel.studentsViewModel().students.remove @
		viewmodel.studentsViewModel().filteredStudents()[0].selectStudent()
	resetPassword: =>
	filterCat0: =>
		@filterCategory 0
	filterCat1: =>
		@filterCategory 1
	filterCat2: =>
		@filterCategory 2
	toggleBc: =>
		$data = arguments[0]
		if @bc().indexOf($data.compcode()) >= 0
			@bc.remove $data.course.compcode()
		else
			@bc.push $data.course.compcode()
		@psc.remove $data.course.compcode()
		@el.remove $data.course.compcode()
	togglePsc: =>
		$data = arguments[0]
		if @psc().indexOf($data.course.compcode()) >= 0
			@psc.remove $data.course.compcode()
		else
			@psc.push $data.course.compcode()
		@bc.remove $data.course.compcode()
		@el.remove $data.course.compcode()
	toggleEl: =>
		$data = arguments[0]
		if @el().indexOf($data.course.compcode()) >= 0
			@el.remove $data.course.compcode()
		else
			@el.push $data.course.compcode()
		@bc.remove $data.course.compcode()
		@psc.remove $data.course.compcode()
	toggleSelected: =>
		$data = arguments[0]
		if _(@selectedcourses()).any((x) -> x.compcode() is $data.course.compcode())
			@selectedcourses.remove (x) -> x.compcode() is $data.course.compcode()
		else
			@selectedcourses.push new SelectedCourseViewModel compcode: $data.course.compcode()
	selectLectureSection: =>
		$section = arguments[1]
		$course = arguments[0][0]
		_(@selectedcourses()).find((x) -> x.compcode() is $course.course.compcode()).selectedLectureSection $section.number()
	selectLabSection: =>
		$section = arguments[1]
		$course = arguments[0][0]
		_(@selectedcourses()).find((x) -> x.compcode() is $course.course.compcode()).selectedLabSection $section.number()
	toggleRegistered: =>
		@registered not @registered()
		@difficultTimetable false
	toggleValidated: =>
		@validated not @validated()
	toggleDifficultTimetable: =>
		@difficultTimetable not @difficultTimetable()
	resetPassword: =>
		@newPassword md5(Date())[0...8]
		@password md5 @newPassword()
	toData: =>
		_id: @_id()
		studentId: @studentId()
		name: @name()
		password: @password()
		registered: @registered()
		validated: @validated()
		validatedBy: @validatedBy()
		difficultTimetable: @difficultTimetable()
		bc: @bc() if @bc().length > 0
		psc: @psc() if @psc().length > 0
		el: @el() if @el().length > 0
		reqEl: @reqEl()
		selectedcourses: course.toData() for course in @selectedcourses()

class StudentsViewModel
	constructor: ({students}) ->
		@students = ko.observableArray (new StudentViewModel student for student in students)
		@sort = ko.observable "studentId"
		@filterCategory = ko.observable 0
		@query = ko.observable ""
		@filteredStudents = ko.computed =>
			query = @query().toLowerCase()
			cat = 
				switch @filterCategory()
					when 0 then @students()
					when 1 then _(@students()).filter (x) => not x.registered()
					when 2 then _(@students()).filter (x) => x.registered() and not x.validated()
					when 3 then _(@students()).filter (x) => x.validated()
					when 4 then _(@students()).filter (x) => x.difficultTimetable()
			cat = _(cat).filter (student) =>
				if student.studentId().toLowerCase().indexOf(query) >= 0
					true
				else if student.name().toLowerCase().indexOf(query) >= 0
					true
			_(cat).sortBy (x) => x[@sort()]()
		@currentStudent = ko.observable @filteredStudents()[0]
	newStudent: =>
		@students.push student = new StudentViewModel newPassword: (np = md5(Date())[0...8]), password: md5 np
		student.selectStudent()
		scrollTo 0, document.height
	selectFile: =>
		$fup = $("<input type='file' accept='text/csv'>")
		$fup.one "change", =>
			return if $fup[0].files.length is 0
			fs = new FileReader()
			fs.onload = (e) =>
				viewmodel.pleaseWaitStatus "Importing Students..."
				socket.emit "importStudents", e.target.result, (success) =>
					viewmodel.pleaseWaitStatus undefined
					if success
						@fetchStudents()
					else
						alert "Parsing Error. Please recheck .csv file for errors."
			fs.readAsText $fup[0].files[0]
		$fup.trigger "click"
	filterCat: (cat) => =>
		@filterCategory cat
	exportCSV: =>
		window.open "students.csv?cat=#{@filterCategory()}"
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
	commitStudents: =>
		viewmodel.pleaseWaitStatus "Saving changes..."
		students = @toData()
		socket.emit "commitStudents", students, (result) =>
			viewmodel.pleaseWaitStatus undefined
			@fetchStudents()
	deleteAll: =>
		viewmodel.pleaseWaitStatus "Deleting all Students..."
		socket.emit "deleteAllStudents", (success) =>
			viewmodel.pleaseWaitStatus undefined
			@fetchStudents()
	toData: =>
		student.toData() for student in @students() when student.modified()

class ValidatorViewModel
	constructor: ({username, newPassword, password, _id}) ->
		@_id = ko.observable _id ? undefined
		@username = ko.observable username ? undefined
		@password = ko.observable password ? undefined
		@newPassword = ko.observable newPassword ? undefined
		@visible = ko.observable true
	selectValidator: =>
		viewmodel.validatorsViewModel().currentValidator @
	deleteValidator: =>
		viewmodel.validatorsViewModel().validators.remove @
		viewmodel.validatorsViewModel().filteredValidators()[0].selectValidator()
	resetPassword: =>
		@newPassword md5(Date())[0...8]
		@password md5 @newPassword()
	toData: =>
		_id: @_id()
		username: @username()
		password: @password()

class ValidatorsViewModel
	constructor: ({validators}) ->
		@validators = ko.observableArray (new ValidatorViewModel validator for validator in validators)
		@filteredValidators = ko.computed => _.chain(@validators()).filter((x) -> x.visible()).sortBy((x) => x.username()).value()
		@currentValidator = ko.observable @filteredValidators()[0]
	filter: =>
		query = $(arguments[1].currentTarget).val().toLowerCase()
		for validator in @validators()
			validator.visible false
			if validator.username().toLowerCase().indexOf(query) >= 0
				validator.visible true
	newValidator: =>
		@validators.push validator = new ValidatorViewModel newPassword: (np = md5(Date())[0...8]), password: md5 np
		validator.selectValidator()
		scrollTo 0, document.height
	selectFile: =>
		$fup = $("<input type='file' accept='text/csv'>")
		$fup.one "change", =>
			return if $fup[0].files.length is 0
			fs = new FileReader()
			fs.onload = (e) =>
				viewmodel.pleaseWaitStatus "Importing Validators..."
				socket.emit "importValidators", e.target.result, (success) =>
					viewmodel.pleaseWaitStatus undefined
					if success
						@fetchValidators()
					else
						alert "Parsing Error. Please recheck .csv file for errors."
			fs.readAsText $fup[0].files[0]
		$fup.trigger "click"
	fetchValidators: =>
		viewmodel.pleaseWaitStatus "Fetching Validators..."
		socket.emit "getValidators", (validators) =>
			viewmodel.pleaseWaitStatus undefined
			@validators (new ValidatorViewModel validator for validator in validators)
			@currentValidator @filteredValidators()[0]
	commitValidators: =>
		viewmodel.pleaseWaitStatus "Saving changes..."
		validators = @toData()
		socket.emit "commitValidators", validators, (result) =>
			viewmodel.pleaseWaitStatus undefined
	deleteAll: =>
		viewmodel.pleaseWaitStatus "Deleting all Validators..."
		socket.emit "deleteAllValidators", (success) =>
			viewmodel.pleaseWaitStatus undefined
			@fetchValidators()
	toData: =>
		validator.toData() for validator in @validators()

class SemesterViewModel
	constructor: ->
		@title = ko.observable null
		@startTime = ko.observable null
	commitSemester: =>
		viewmodel.pleaseWaitStatus "Saving changes..."
		semester = @toData()
		socket.emit "commitSemester", semester, (result) =>
			viewmodel.pleaseWaitStatus undefined
	fetchSemester: =>
		viewmodel.pleaseWaitStatus "Fetching Semester Details..."
		socket.emit "getSemester", (semester) =>
			viewmodel.pleaseWaitStatus undefined
			@title semester.title
			@startTime moment(semester.startTime).format "DD/MM/YYYY HH:mm"
			$('input[rel=datetime]').datetimepicker("update")
	toData: =>
		title: @title()
		startTime: moment(@startTime(), "DD/MM/YYYY HH:mm").toDate()

class StatsViewModel
	constructor: ->
		@currentStudents = ko.observable "--"
		@currentNotRegistered = ko.observable "--"
		@currentNotValidated = ko.observable "--"
		@currentValidated = ko.observable "--"
		@currentDifficultTimetable = ko.observable "--"
		@currentValidators = ko.observable "--"
	fetchStats: =>
			viewmodel.pleaseWaitStatus "Fetching Stats..."
			rec = =>
				socket.emit "getStats", ({currentStudents, currentNotRegistered, currentNotValidated, currentValidated, currentDifficultTimetable, currentValidators}) =>
					viewmodel.pleaseWaitStatus undefined
					@currentStudents currentStudents ? "--"
					@currentNotRegistered currentNotRegistered ? "--"
					@currentNotValidated currentNotValidated ? "--"
					@currentValidated currentValidated ? "--"
					@currentDifficultTimetable currentDifficultTimetable ? "--"
					@currentValidators currentValidators ? "--"
			rec()
			setInterval rec, 1000

class BodyViewModel
	constructor: ->
		@coursesViewModel = ko.observable undefined
		@studentsViewModel = ko.observable undefined
		@validatorsViewModel = ko.observable undefined
		@statsViewModel = new StatsViewModel()
		@pleaseWaitStatus = ko.observable undefined
		@pleaseWaitVisible = ko.computed => @pleaseWaitStatus()?
		@activeView = ko.observable undefined
		@authenticated = ko.observable false
		@semester = new SemesterViewModel()
		@loginAlertStatus = ko.observable undefined
	gotoCourses: =>
		viewmodel.pleaseWaitStatus "Fetching Courses..."
		socket.emit "getCourses", (courses) ->
			viewmodel.pleaseWaitStatus undefined
			viewmodel.coursesViewModel new CoursesViewModel courses: courses
			viewmodel.activeView "coursesView"
			$("#courseheader, #coursedetails").affix offset: top: 290
			$('button[rel=tooltip]').tooltip()
	gotoStudents: =>
		viewmodel.pleaseWaitStatus "Fetching Courses..."
		socket.emit "getCourses", (courses) ->
			viewmodel.pleaseWaitStatus "Fetching Validators..."
			viewmodel.coursesViewModel new CoursesViewModel courses: courses
			socket.emit "getValidators", (validators) ->
				viewmodel.pleaseWaitStatus "Fetching Students..."
				viewmodel.validatorsViewModel new ValidatorsViewModel validators: validators
				socket.emit "getStudents", (students) ->
					viewmodel.pleaseWaitStatus undefined
					viewmodel.studentsViewModel new StudentsViewModel students: students
					viewmodel.activeView "studentsView"
					$("#studentheader, #studentdetails").affix offset: top: 290
					$('button[rel=tooltip]').tooltip()
	gotoValidators: =>
		viewmodel.pleaseWaitStatus "Fetching Validators..."
		socket.emit "getValidators", (validators) ->
			viewmodel.pleaseWaitStatus undefined
			viewmodel.validatorsViewModel new ValidatorsViewModel validators: validators
			viewmodel.activeView "validatorsView"
			$("#validatorheader, #validatordetails").affix offset: top: 290
			$('button[rel=tooltip]').tooltip()
	gotoHome: =>
		@activeView "homeView"
		@semester.fetchSemester()
		$('input[rel=datetime]').datetimepicker()
	gotoStats: =>
		@activeView "statsView"
		@statsViewModel.fetchStats()
	login: =>
		@loginAlertStatus undefined
		accessCode = $("#input-accesscode").val()
		socket.emit "login", accessCode, (success) =>
			viewmodel.pleaseWaitStatus undefined
			if success
				@authenticated true
				@gotoHome()
			else
				@loginAlertStatus "authFailure"
	dismissLoginAlert: =>
		@loginAlertStatus undefined
	logout: =>
		socket.emit "logout", =>
			$("#input-accesscode").val("")
			@authenticated false

$ ->
	window.viewmodel = viewmodel = new BodyViewModel()
	viewmodel.pleaseWaitStatus "Connecting..."
	ko.applyBindings viewmodel, $("body")[0]

	socket = io.connect()
	socket.on "connect", ->
		viewmodel.pleaseWaitStatus undefined

	socket.on "destroySession", ->
		viewmodel.logout()
		viewmodel.loginAlertStatus "remoteLogout"
