# BPD-CDMS
# Author: Gautham Badhrinathan - b.gautham@gmail.com, fb.com/GotEmB

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
		dslt = _(viewmodel.coursesViewModel.groups()).find((x) => x.indexOf(@compcode) >= 0) ? []
		dslt = _(dslt).filter (x) => x isnt @compcode
		_.chain(viewmodel.coursesViewModel.psc()).filter((x) -> x.compcode in dslt).each (x) -> x.selected false
		_.chain(viewmodel.coursesViewModel.el()).filter((x) -> x.compcode in dslt).each (x) -> x.selected false
	electiveMouseOver: =>
		window.viewmodel.coursesViewModel.selectedValueDropdown @
	electiveSelect: =>
		@selected true

class CoursesViewModel
	constructor: ->
		@bc = ko.observableArray []
		@psc = ko.observableArray []
		@allEl = ko.observableArray []
		@el = ko.computed => _(@allEl()).sortBy (x) -> x.compcode
		@reqEl = ko.observable 0
		@groups = ko.observableArray []
		@groupsPsc = ko.computed => _(@groups()).filter (x) => _(@psc()).any (y) => y.compcode in x
		@groupsNI = ko.computed =>
			for group in @groups()
				g = group[0...group.length - 1].join ", "
				g + " and " + group[group.length - 1]
		@electiveQuery = ko.observable ""
		@selectedValueDropdown = ko.observable undefined
		@enableOverloads = ko.observable false
		@enableUnderRegister = ko.observable false
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
		@blEnabled = ko.computed => _(@psc()).all((x) -> not x.selected()) and _(@el()).filter((x) -> x.selected()).length is 0
		@pscEnabled = ko.computed => _(@bc()).all((x) -> x.selected()) and _(@el()).filter((x) -> x.selected()).length <= @reqEl()
		@elEnabled = ko.computed => _(@bc()).all (x) -> x.selected()
		@elsEnabled = ko.computed =>
			p1 = _(@psc()).filter((x) -> x.selected()).length is @psc().length - _.chain(@groupsPsc()).filter((x) -> x?.length > 1).map((x) -> x.length - 1).reduce(((sum, n) -> sum + n), 0).value()
			_(@el()).filter((x) -> x.selected()).length < @reqEl() or (p1 and @enableOverloads()) or not @elEnabled()
		@nextStepWarning = ko.computed =>
			p1 = _(@psc()).filter((x) -> x.selected()).length is @psc().length - _.chain(@groupsPsc()).filter((x) -> x?.length > 1).map((x) -> x.length - 1).reduce(((sum, n) -> sum + n), 0).value()
			_(@el()).filter((x) -> x.selected()).length < @reqEl() or not p1
		@allSelectedCourses = ko.computed => _.chain([@bc(), @psc(), @el()]).flatten(1).filter((x) -> x.selected()).value()
		@clashingOtherDates = ko.computed => _(@allSelectedCourses()).any (x) -> _(x.otherDates()).any (y) -> y.clashing()
		@numberOfSections = ko.computed =>
			ret = 0
			ret++ if @bc().length > 0
			ret++ if @psc().length > 0
			ret++ if @el().length > 0
			ret
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
	showOptions: =>
		$("#options-box").modal "show"
	toData: =>
		bc: _(@bc()).map (x) -> compcode: x.compcode, selected: x.selected()
		psc: _(@psc()).map (x) -> compcode: x.compcode, selected: x.selected()
		el: _(@allEl()).map (x) -> compcode: x.compcode, selected: x.selected()

class SectionViewModel
	constructor: ({@number, @instructor, status}, @parent) ->
		@status = ko.observable if status.isFull then "isFull" else if status.lessThan5 then "lessThan5" else undefined
	chooseLectureSection: (callback) =>
		sectionInfo =
			compcode: @parent.compcode
			section_number: @number
			isLectureSection: true
		@parent.loadingState true
		socket.emit "chooseSection", sectionInfo, ({success, status, schedule}) =>
			@parent.loadingState false
			return callback?() unless success
			@parent.selectedLectureSection @number
			@status do =>
				if not status or status.isFull
					"isFull"
				else if status.lessThan5
					"lessThan5"
				else
					undefined
			viewmodel.sectionsViewModel.setSchedule schedule
			callback?()
	chooseLabSection: (callback) =>
		sectionInfo =
			compcode: @parent.compcode
			section_number: @number
			isLabSection: true
		@parent.loadingState true
		socket.emit "chooseSection", sectionInfo, ({success, status, schedule}) =>
			@parent.loadingState false
			return callback?() unless success
			@parent.selectedLabSection @number
			@status do =>
				if not status or status.isFull
					"isFull"
				else if status.lessThan5
					"lessThan5"
				else
					undefined
			viewmodel.sectionsViewModel.setSchedule schedule
			callback?()

class CourseSectionsViewModel
	constructor: ({@compcode, @number, @name, @hasLectures, @hasLab, lectureSections, labSections, selectedLectureSection, selectedLabSection, @otherDates}) ->
		@loadingState = ko.observable false
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
			c2 = _(@courses()).all (x) -> (!x.selectedLectureSection()? or x.selectedLectureSectionStatus() isnt "isFull") and (!x.selectedLabSection()? or x.selectedLabSectionStatus() isnt "isFull")
			return false unless c2
			not _([0..6]).any (j) => _([5..7]).all (i) => @schedule[i][j]().length is 1
		@lunchHourProblem = ko.computed =>
			_([0..6]).any (j) => _([5..7]).all (i) => @schedule[i][j]().length is 1
		@dtcEnabled = ko.computed => _(@schedule).any (x) -> _(x).any (y) -> y().length > 1
		@registeredOn = ko.observable ""
		@validatedOn = ko.observable ""
		@validatedBy = ko.observable ""
		@sectionsLoadingState = ko.computed => _(@courses()).any (x) -> x.loadingState()
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
		socket.emit "confirmRegistration", (result) =>
			return bootbox.alert "One or more of your selections aren't available. Modify your selections and try registering again." if not result.success and result.invalidRegistration?
			window.scrollTo 0, 0
			$('input[rel=tooltip]').tooltip()
			viewmodel.studentStatus "registered"
			@registeredOn Date()
	needHelp: =>
		bootbox.confirm """
			Continue only if you have tried all combinations and are not able to build a valid timetable.
			Choose your sections wherever possible before you proceed.
			Once you click Ok, you will be locked out and will have to approach the Registration Incharge.
		""", (result) ->
			return unless result
			socket.emit "difficultTimetable", -> viewmodel.studentStatus "difficultTimetable"

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
		socket.emit "getCourses", ({success, bc, psc, el, reqEl, groups}) =>
			@coursesViewModel.bc (new CourseViewModel course for course in bc ? [])
			@coursesViewModel.psc (new CourseViewModel course for course in psc ? [])
			@coursesViewModel.allEl (new CourseViewModel course for course in el ? [])
			@coursesViewModel.reqEl reqEl ? 0
			@coursesViewModel.groups groups ? []
			@pleaseWaitVisible false
	gotoSectionsView: =>
		@activeView "sectionsView"
		@pleaseWaitVisible true
		socket.emit "initializeSectionsScreen", ({success, selectedcourses, schedule, conflicts, registeredOn, validatedOn, validatedBy}) =>
			@sectionsViewModel.courses (new CourseSectionsViewModel course for course in selectedcourses ? [])
			@sectionsViewModel.setSchedule schedule
			@sectionsViewModel.registeredOn registeredOn
			@sectionsViewModel.validatedOn validatedOn
			@sectionsViewModel.validatedBy validatedBy
			toSet = []
			for course in @sectionsViewModel.courses()
				toSet.push course.lectureSections()[0].chooseLectureSection if course.lectureSections().length is 1
				toSet.push course.labSections()[0].chooseLabSection if course.labSections().length is 1
			recSet = =>
				return @pleaseWaitVisible false if toSet.length is 0
				toSet.pop() -> recSet()
			recSet()

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
		return unless viewmodel.activeView() is "sectionsView"
		d = _(viewmodel.sectionsViewModel.courses()).find((x) -> x.compcode is compcode)
		return unless d?
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
	$('body').on "touchstart.dropdown", ".dropdown-menu", (e) -> e.stopPropagation()
