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
				@alertStatus data.reason
			else
				viewmodel.studentName data.student.name
				viewmodel.studentId data.student.studentId
				viewmodel.studentStatus data.student.status
				viewmodel.authenticated true
				if viewmodel.studentStatus() is "not registered"
					viewmodel.gotoCoursesView()
				else
					viewmodel.gotoSectionsView()
		@studentId undefined
		@password undefined
	dismissAlert: =>
		@alertStatus undefined
	logout: =>
		viewmodel.pleaseWaitVisible true
		socket.emit "logout", ->
			viewmodel.studentName undefined
			viewmodel.studentId undefined
			viewmodel.studentStatus undefined
			viewmodel.authenticated false
			viewmodel.activeView "loginView"
			viewmodel.pleaseWaitVisible false

class TestDateViewModel
	constructor: (@date) ->
		@clashing = ko.computed => _.chain(viewmodel.coursesViewModel.allSelectedCourses()).map((x) => x.otherDates()).flatten(1).filter((x) => x.date is @date).value().length > 1

class CourseViewModel
	constructor: ({@compcode, @number, @name, selected, otherDates}) ->
		@selected = ko.observable selected
		@otherDates = ko.observableArray (new TestDateViewModel date for date in otherDates)
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
				return true if x.compcode.toString().toLowerCase().indexOf(@electiveQuery().toLowerCase()) >= 0
				return true if x.number.toLowerCase().indexOf(@electiveQuery().toLowerCase()) >= 0
				return true if x.name.toLowerCase().indexOf(@electiveQuery().toLowerCase()) >= 0
				false
			@selectedValueDropdown els[0]
			_(els).take 5
		@blEnabled = ko.computed => _(@psc()).all((x) -> not x.selected()) and @el().length is 0
		@pscEnabled = ko.computed => _(@bc()).all((x) -> x.selected()) and @el().length <= @reqEl()
		@elEnabled = ko.computed => _(@bc()).all (x) -> x.selected()
		@elsEnabled = ko.computed => @el().length < @reqEl() or _(@psc()).all((x) -> x.selected()) or not @elEnabled()
		@nextStepWarning = ko.computed => @el().length < @reqEl() or _(@psc()).any (x) -> not x.selected()
		@allSelectedCourses = ko.computed => _.chain([@bc(), @psc(), @el()]).flatten(1).filter((x) -> x.selected()).value()
		@clashingOtherDates = ko.computed => _(@allSelectedCourses()).any (x) -> _(x.otherDates()).any (y) -> y.clashing()
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
		bc: _(@bc()).map (x) -> compcode: x.compcode, selected: x.selected()
		psc: _(@psc()).map (x) -> compcode: x.compcode, selected: x.selected()
		el: _(@allEl()).map (x) -> compcode: x.compcode, selected: x.selected()

class SectionViewModel
	constructor: ({@number, @instructor, status}, @parent) ->
		@status = ko.observable if status.isFull then "isFull" else if status.lessThan5 then "lessThan5" else undefined
	chooseLectureSection: =>
		sectionInfo =
			compcode: @parent.compcode
			section_number: @number
			isLectureSection: true
		socket.emit "chooseSection", sectionInfo, ({status, schedule}) =>
			@parent.selectedLectureSection @number
			@status if status.isFull then "isFull" else if status.lessThan5 then "lessThan5" else undefined
			viewmodel.sectionsViewModel.setSchedule schedule
	chooseLabSection: =>
		sectionInfo =
			compcode: @parent.compcode
			section_number: @number
			isLabSection: true
		socket.emit "chooseSection", sectionInfo, ({status, schedule}) =>
			@parent.selectedLabSection @number
			@status if status.isFull then "isFull" else if status.lessThan5 then "lessThan5" else undefined
			viewmodel.sectionsViewModel.setSchedule schedule

class CourseSectionsViewModel
	constructor: ({@compcode, @number, @name, @hasLectures, @hasLab, lectureSections, labSections, selectedLectureSection, selectedLabSection, @otherDates}) ->
		@lectureSections = ko.observableArray (new SectionViewModel section, @ for section in lectureSections ? [])
		@labSections = ko.observableArray (new SectionViewModel section, @ for section in labSections ? [])
		@selectedLectureSection = ko.observable selectedLectureSection
		@selectedLabSection = ko.observable selectedLabSection
		@selectedLectureSectionText = ko.computed => "Lecture" + if @selectedLectureSection()? then ": " + @selectedLectureSection() else ""
		@selectedLabSectionText = ko.computed => "Lab" + if @selectedLabSection()? then ": " + @selectedLabSection() else ""
		@selectedLectureSectionStatus = ko.computed => _(@lectureSections()).find((x) => x.number is @selectedLectureSection()).status() ? "success" if @selectedLectureSection()?
		@selectedLabSectionStatus = ko.computed => _(@labSections()).find((x) => x.number is @selectedLabSection()).status() ? "success" if @selectedLabSection()?
		@selectedLectureSectionTextFull = ko.computed => (@selectedLectureSectionText() + " (#{_(@lectureSections()).find((x) => x.number is @selectedLectureSection()).instructor})") if @selectedLectureSection()?
		@selectedLabSectionTextFull = ko.computed => (@selectedLabSectionText() + " (#{_(@labSections()).find((x) => x.number is @selectedLabSection()).instructor})") if @selectedLabSection()?

class SectionsViewModel
	constructor: ->
		@courses = ko.observableArray []
		@schedule = (ko.observableArray [] for x in [1..7] for y in [1..10])
		@registerEnabled = ko.computed =>
			c1 = _.chain(@schedule).flatten(true).all((x) -> x().length <= 1).value() and 
					_(@courses()).all (x) -> (x.lectureSections().length is 0 or x.selectedLectureSection()?) and (x.labSections().length is 0 or x.selectedLabSection()?)
			return false unless c1
			not _([0..6]).any (j) => _([4..6]).all (i) => @schedule[i][j]().length is 1
		@dtcEnabled = ko.computed => _(@schedule).any (x) -> _(x).any (y) -> y().length > 1
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
	register: =>
		socket.emit "confirmRegistration", (result) ->
			return bootbox.alert "Invalid Registration. Please refresh your browser and register again." if not result.success and result.invalidRegistration?
			bootbox.alert "You have registered for your courses. Print, sign and submit your Registration Card for validation."
			$('input[rel=tooltip]').tooltip()
			viewmodel.studentStatus "registered"
	needHelp: =>
		bootbox.confirm """
			Continue only if you have tried all combinations and are not able to build a valid timetable.
			Choose your sections wherever possible before you proceed.
			Once you click Ok, you will be locked out and will have to approach the Registration Incharge.
		""", (result) ->
			return unless result
			socket.emit "difficultTimetable", -> viewmodel.studentStatus "difficultTimetable"
	printRC: =>
		win = window.open()
		console.log win
		socket.emit "setup_sid", (sid) ->
			win.location = "registrationCard?sid=#{sid}"

class BodyViewModel
	constructor: ->
		@studentName = ko.observable undefined
		@studentId = ko.observable undefined
		@studentNI = ko.computed => "#{@studentName()} (#{@studentId()})"
		@studentStatus = ko.observable undefined
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
			@sectionsViewModel.setSchedule schedule
			@pleaseWaitVisible false

$ ->
	window.viewmodel = viewmodel = new BodyViewModel()
	viewmodel.pleaseWaitVisible true
	ko.applyBindings viewmodel, $("body")[0]

	socket = io.connect()
	socket.on "connect", ->
		socket.emit "getSemesterDetails", ({success, semesterTitle, startTime, reason}) ->
			if success
				viewmodel.semesterTitle semesterTitle
				viewmodel.startTime new Date startTime
				viewmodel.pleaseWaitVisible false
			else
				viewmodel.loginViewModel.alertStatus reason

	socket.on "sectionUpdate", (compcode, data) ->
		d = _(viewmodel.sectionsViewModel.courses()).find((x) -> x.compcode is compcode)
		if data.sectionType is "lecture"
			_(d.lectureSections()).find((x) -> x.number is data.sectionNumber).status if data.status.isFull then "isFull" else if data.status.lessThan5 then "lessThan5" else undefined
		else if data.sectionType is "lab"
			_(d.labSections()).find((x) -> x.number is data.sectionNumber).status if data.status.isFull then "isFull" else if data.status.lessThan5 then "lessThan5" else undefined

	socket.on "statusChanged", (status) ->
		viewmodel.studentStatus status

	socket.on "destroySession", =>
		viewmodel.loginViewModel.logout()
		viewmodel.loginViewModel.alertStatus "remoteLogout"

	$('input[rel=tooltip]').tooltip()