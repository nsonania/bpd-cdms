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
		window.viewmodel.coursesViewModel().currentSection @
		$("#sectiondetails").modal "show"
	deleteSection: =>
		if window.viewmodel.coursesViewModel().currentCourse().lectureSections().indexOf window.viewmodel.coursesViewModel().currentSection() >= 0
			window.viewmodel.coursesViewModel().currentCourse().lectureSections.remove window.viewmodel.coursesViewModel().currentSection()
		else if window.viewmodel.coursesViewModel().currentCourse().labSections().indexOf window.viewmodel.coursesViewModel().currentSection() >= 0
			window.viewmodel.coursesViewModel().currentCourse().labSections.remove window.viewmodel.coursesViewModel().currentSection()
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

class OpenToViewModel
	constructor: ({department, open}) ->
		@department = ko.observable department
		@open = ko.observable open
	toggle: =>
		@open not @open()

class CourseViewModel
	constructor: ({compcode, number, name, lectureSections, labSections, otherDates, openTo, _id}) ->
		@_id = ko.observable _id ? undefined
		@compcode = ko.observable compcode ? null
		@number = ko.observable number ? null
		@name = ko.observable name ? null
		@lectureSections = ko.observableArray (new SectionViewModel section for section in lectureSections ? [])
		@labSections = ko.observableArray (new SectionViewModel section for section in labSections ? [])
		@visible = ko.observable true
		@otherDates = ko.observable otherDates ? []
		@openTo = ko.observableArray (new OpenToViewModel department: dept, open: (openTo ? []).indexOf(dept) >= 0 for dept in ["EEE", "ECE", "EIE", "CS", "ME", "BIOT", "CHE"])
	selectCourse: =>
		window.viewmodel.coursesViewModel().currentCourse @
	deleteCourse: =>
		window.viewmodel.coursesViewModel().courses.remove @
		window.viewmodel.coursesViewModel().filteredCourses()[0].selectCourse()
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
		_id: @_id()
		compcode: @compcode()
		number: @number()
		name: @name()
		hasLectureSections: true if @lectureSections().length > 0
		lectureSections: section.toData() for section in @lectureSections() if @lectureSections().length > 0
		hasLabSections: true if @labSections().length > 0
		labSections: section.toData() for section in @labSections() if @labSections().length > 0
		otherDates: @otherDates()
		openTo: department() for {department, open} in @openTo() when open()
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
		@courses.push course = new CourseViewModel {}
		course.selectCourse()
		window.scrollTo 0, document.height
	fetchCourses: =>
		window.viewmodel.pleaseWaitStatus "Fetching Courses..."
		socket.emit "getCourses", (courses) =>
			window.viewmodel.pleaseWaitStatus undefined
			@courses (new CourseViewModel course for course in courses)
			@currentCourse @filteredCourses()[0]
	commitCourses: =>
		window.viewmodel.pleaseWaitStatus "Saving changes..."
		courses = @toData()
		socket.emit "commitCourses", courses, (result) =>
			window.viewmodel.pleaseWaitStatus undefined
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
				window.viewmodel.pleaseWaitStatus "Importing Courses..."
				socket.emit "importCourses", e.target.result, (success) =>
					window.viewmodel.pleaseWaitStatus undefined
					if success
						@fetchCourses()
					else
						alert "Parsing Error. Please recheck .csv file for errors."
			fs.readAsText $fup[0].files[0]
		$fup.trigger "click"
	deleteAll: =>
		window.viewmodel.pleaseWaitStatus "Deleting all Courses..."
		socket.emit "deleteAllCourses", (success) =>
			window.viewmodel.pleaseWaitStatus undefined
			@fetchCourses()
	toData: =>
		course.toData() for course in @courses()

class SelectedCourseViewModel
	constructor: ({course_id, selectedLectureSection, selectedLabSection}) ->
		@course_id = ko.observable course_id
		@selectedLectureSection = ko.observable selectedLectureSection
		@selectedLabSection = ko.observable selectedLabSection
		@course = ko.computed => _(window.viewmodel.coursesViewModel().courses()).find (x) -> x._id is @course_id
	toData: =>
		course_id: @course_id()
		selectedLectureSection: @selectedLectureSection()
		selectedLabSection: @selectedLabSection()

class StudentViewModel
	constructor: ({studentId, name, password, departments, registered, validated, bc, psc, selectedcourses, _id}) ->
		@_id = ko.observable _id ? undefined
		@studentId = ko.observable studentId ? undefined
		@name = ko.observable name ? undefined
		@password = ko.observable password ? undefined
		@newPassword = ko.observable undefined
		@departments = ko.observableArray (new OpenToViewModel department: dept, open: _(departments ? []).map((x) -> x.toUpperCase()).indexOf(dept) >= 0 for dept in ["EEE", "ECE", "EIE", "CS", "ME", "BIOT", "CHE"])
		@registered = ko.observable registered ? undefined
		@validated = ko.observable validated ? undefined
		@bc = ko.observableArray bc ? []
		@psc = ko.observableArray psc ? []
		@selectedcourses = ko.observableArray (new SelectedCourseViewModel sc for sc in selectedcourses ? [])
		@visible = ko.observable true
		@courses = ko.computed =>
			for course in window.viewmodel.coursesViewModel().courses()
				course: course
				bc: @bc().indexOf(course._id()) >= 0
				psc: @psc().indexOf(course._id()) >= 0
				selected: _(@selectedcourses()).any (x) => x.course_id() is course._id()
				selectedLectureSection: _(@selectedcourses()).find((x) => x.course_id() is course._id()).selectedLectureSection() if course.lectureSections().length > 0 and _(@selectedcourses()).any (x) => x.course_id() is course._id()
				selectedLabSection: _(@selectedcourses()).find((x) => x.course_id() is course._id()).selectedLabSection() if course.labSections().length > 0 and _(@selectedcourses()).any (x) => x.course_id() is course._id()
		@filterCategory = ko.observable 1
		@query = ko.observable ""
		@filteredCourses = ko.computed =>
			query = @query().toLowerCase()
			cat = 
				switch @filterCategory()
					when 0 then @courses()
					when 1 then _(@courses()).filter (x) => x.bc or x.psc
					when 2 then _(@courses()).filter (x) => x.selected
			_(cat).filter (x) =>
				course = x.course
				if course.compcode().toString().indexOf(query) >= 0
					true
				else if course.number().toLowerCase().indexOf(query) >= 0
					true
				else if course.name().toLowerCase().indexOf(query) >= 0
					true
	selectStudent: =>
		window.viewmodel.studentsViewModel().currentStudent @
	deleteStudent: =>
		window.viewmodel.studentsViewModel().students.remove @
		window.viewmodel.studentsViewModel().filteredStudents()[0].selectStudent()
	resetPassword: =>
	filterCat0: =>
		@filterCategory 0
	filterCat1: =>
		@filterCategory 1
	filterCat2: =>
		@filterCategory 2
	toggleBc: =>
		$data = arguments[0]
		if @bc().indexOf($data.course._id()) >= 0
			@bc.remove $data.course._id()
		else
			@bc.push $data.course._id()
	togglePsc: =>
		$data = arguments[0]
		if @psc().indexOf($data.course._id()) >= 0
			@psc.remove $data.course._id()
		else
			@psc.push $data.course._id()
	toggleSelected: =>
		$data = arguments[0]
		if _(@selectedcourses()).any((x) -> x.course_id() is $data.course._id())
			@selectedcourses.remove (x) -> x.course_id() is $data.course._id()
		else
			@selectedcourses.push new SelectedCourseViewModel course_id: $data.course._id()
	selectLectureSection: =>
		$section = arguments[1]
		$course = arguments[0][0]
		_(@selectedcourses()).find((x) -> x.course_id() is $course.course._id()).selectedLectureSection $section.number()
	selectLabSection: =>
		$section = arguments[1]
		$course = arguments[0][0]
		_(@selectedcourses()).find((x) -> x.course_id() is $course.course._id()).selectedLabSection $section.number()
	toData: =>
		_id: @_id()
		studentId: @studentId()
		name: @name()
		password: @password()
		departments: department() for {department, open} in @departments() when open()
		registered: @registered()
		validated: @validated()
		bc: @bc() if @bc().length > 0
		psc: @psc() if @psc().length > 0
		selectedcourses: course.toData() for course in @selectedcourses()

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
	selectFile: =>
		return # remove...
		$fup = $("<input type='file' accept='text/csv'>")
		$fup.one "change", =>
			return if $fup[0].files.length is 0
			fs = new FileReader()
			fs.onload = (e) =>
				window.viewmodel.pleaseWaitStatus "Importing Courses..."
				socket.emit "importCourses", e.target.result, (success) =>
					window.viewmodel.pleaseWaitStatus undefined
					if success
						@fetchCourses()
					else
						alert "Parsing Error. Please recheck .csv file for errors."
			fs.readAsText $fup[0].files[0]
		$fup.trigger "click"
	sortStudentId: =>
		@sort "studentId"
	sortName: =>
		@sort "name"
	fetchStudents: =>
		window.viewmodel.pleaseWaitStatus "Fetching Students..."
		socket.emit "getStudents", (students) =>
			window.viewmodel.pleaseWaitStatus undefined
			@students (new StudentViewModel student for student in students)
			@currentStudent @filteredStudents()[0]
	commitStudents: =>
		window.viewmodel.pleaseWaitStatus "Saving changes..."
		students = @toData()
		socket.emit "commitStudents", students, (result) =>
			window.viewmodel.pleaseWaitStatus undefined
	toData: =>
		student.toData() for student in @students()

class BodyViewModel
	constructor: ->
		@coursesViewModel = ko.observable undefined
		@studentsViewModel = ko.observable undefined
		@pleaseWaitStatus = ko.observable undefined
		@pleaseWaitVisible = ko.computed => @pleaseWaitStatus()?
		@activeView = ko.observable undefined
	gotoCourses: =>
		window.viewmodel.pleaseWaitStatus "Fetching Courses..."
		socket.emit "getCourses", (courses) ->
			window.viewmodel.pleaseWaitStatus undefined
			window.viewmodel.coursesViewModel new CoursesViewModel courses: courses
			window.viewmodel.activeView "coursesView"
			$("#courseheader, #coursedetails").affix offset: top: 290
			$('button[rel=tooltip]').tooltip()
	gotoStudents: =>
		window.viewmodel.pleaseWaitStatus "Fetching Courses..."
		socket.emit "getCourses", (courses) ->
			window.viewmodel.pleaseWaitStatus "Fetching Students..."
			window.viewmodel.coursesViewModel new CoursesViewModel courses: courses
			socket.emit "getStudents", (students) ->
				window.viewmodel.pleaseWaitStatus undefined
				window.viewmodel.studentsViewModel new StudentsViewModel students: students
				window.viewmodel.activeView "studentsView"
				$("#studentheader, #studentdetails").affix offset: top: 290
				$('button[rel=tooltip]').tooltip()

$ ->
	window.viewmodel = new BodyViewModel()
	window.viewmodel.pleaseWaitStatus "Connecting..."
	ko.applyBindings viewmodel, $("body")[0]

	socket = io.connect()
	socket.on "connect", ->
		window.viewmodel.pleaseWaitStatus undefined