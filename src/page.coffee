class SectionViewModel
	constructor: ({number, instructor, timeslots, capacity}) ->
		@number = ko.observable number
		@instructor = ko.observable instructor
		@timeslots = ko.observableArray timeslots
		@capacity = ko.observable capacity
		@timetable = ko.computed =>
			for hour, h in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "E"]
				for day, d in ["S", "M", "T", "W", "Th", "F", "Sa"]
					slot: "#{day}#{hour}"
					busy: _(@timeslots()).any (x) -> x.day is d + 1 and x.hour is h + 1
	editSection: =>
		window.currentSection = @
		ko.applyBindings @, $("#sectiondetails")[0]
		$("#sectiondetails").modal "show"

class CourseViewModel
	constructor: ({compcode, number, name, lectureSections, labSections}) ->
		@compcode = ko.observable compcode
		@number = ko.observable number
		@name = ko.observable name
		@lectureSections = ko.observableArray (new SectionViewModel section for section in lectureSections ? [])
		@labSections = ko.observableArray (new SectionViewModel section for section in labSections ? [])
		@visible = ko.observable true
	selectCourse: =>
		window.viewmodel.currentCourse @

class CoursesViewModel
	constructor: ({courses}) ->
		@courses = ko.observableArray (new CourseViewModel course for course in courses)
		@currentCourse = ko.observable @courses()[0]

$ ->
	socket = io.connect()
	socket.on "connect", ->
		socket.emit "getCourses", (courses) ->
			window.viewmodel = viewmodel = new CoursesViewModel courses: courses
			ko.applyBindings viewmodel, $("#courses-container")[0]

	$("#courses-search").keyup ->
		query = $(@).val().toLowerCase()
		for course in viewmodel.courses()
			course.visible false
			if course.compcode().toString().indexOf(query) >= 0
				course.visible true
			if course.number().toLowerCase().indexOf(query) >= 0
				course.visible true
			if course.name().toLowerCase().indexOf(query) >= 0
				course.visible true

	window.selectSlot = ->
		elem = arguments[1].currentTarget
		day = $(elem).parent().index(elem) + 1
		hour = $(elem).parent().parent().index($(elem).parent()) + 1
		if $(elem).hasClass "selected"
			window.currentSection.timeslots.remove (x) -> x.day is day and x.hour is hour
		else
			window.currentSection.timeslots.push day: day, hour: hour