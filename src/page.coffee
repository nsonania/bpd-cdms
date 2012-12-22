socket = undefined

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
		window.viewmodel.currentSection @
		$("#sectiondetails").modal "show"
	deleteSection: =>
		if window.viewmodel.currentCourse().lectureSections().indexOf window.viewmodel.currentSection() >= 0
			window.viewmodel.currentCourse().lectureSections.remove window.viewmodel.currentSection()
		else if window.viewmodel.currentCourse().labSections().indexOf window.viewmodel.currentSection() >= 0
			window.viewmodel.currentCourse().labSections.remove window.viewmodel.currentSection()
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
	constructor: ({compcode, number, name, lectureSections, labSections, otherDates} = {compcode: null, number: null, lectureSections: [], labSections: [], otherDates: []}) ->
		@compcode = ko.observable compcode
		@number = ko.observable number
		@name = ko.observable name
		@lectureSections = ko.observableArray (new SectionViewModel section for section in lectureSections ? [])
		@labSections = ko.observableArray (new SectionViewModel section for section in labSections ? [])
		@visible = ko.observable true
		@otherDates = ko.observable otherDates
	selectCourse: =>
		window.viewmodel.currentCourse @
	deleteCourse: =>
		window.viewmodel.courses.remove @
		window.viewmodel.filteredCourses()[0].selectCourse()
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
		@courses = ko.observableArray (new CourseViewModel course for course in courses)
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
		@courses.push course = new CourseViewModel()
		course.selectCourse()
		window.scrollTo 0, document.height
	fetchCourses: =>
		$("#pleaseWaitBox").css display: "block"
		socket.emit "getCourses", (courses) =>
			$("#pleaseWaitBox").css display: "none"
			@courses (new CourseViewModel course for course in courses)
			@currentCourse @filteredCourses()[0]
	commitCourses: =>
		$("#pleaseWaitBox").css display: "block"
		courses = @toData()
		socket.emit "commitCourses", courses, (result) =>
			$("#pleaseWaitBox").css display: "none"
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
				$("#pleaseWaitBox").css display: "block"
				socket.emit "importCourses", e.target.result, (success) =>
					$("#pleaseWaitBox").css display: "none"
					if success
						@fetchCourses()
					else
						alert "Parsing Error. Please recheck .csv file for errors."
			fs.readAsText $fup[0].files[0]
		$fup.trigger "click"
	deleteAll: =>
		$("#pleaseWaitBox").css display: "block"
		socket.emit "deleteAllCourses", (success) =>
			$("#pleaseWaitBox").css display: "none"
			@fetchCourses()
	toData: =>
		course.toData() for course in @courses()

$ ->
	$('button[rel=tooltip]').tooltip()
	$("#pleaseWaitBox").css display: "block"
	socket = io.connect()
	socket.on "connect", ->
		socket.emit "getCourses", (courses) ->
			$("#pleaseWaitBox").css display: "none"
			window.viewmodel = viewmodel = new CoursesViewModel courses: courses
			ko.applyBindings viewmodel, $("#courses-container")[0]