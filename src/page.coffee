socket = undefined
viewmodel = undefined

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
	constructor: ({compcode, number, name, lectureSections, labSections, otherDates, openTo, _id}) ->
		@_id = ko.observable _id ? undefined
		@compcode = ko.observable compcode ? null
		@number = ko.observable number ? null
		@name = ko.observable name ? null
		@lectureSections = ko.observableArray (new SectionViewModel section for section in lectureSections ? [])
		@labSections = ko.observableArray (new SectionViewModel section for section in labSections ? [])
		@visible = ko.observable true
		@otherDates = ko.observable otherDates ? []
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
		scrollTo 0, document.height
	fetchCourses: =>
		viewmodel.pleaseWaitStatus "Fetching Courses..."
		socket.emit "getCourses", (courses) =>
			viewmodel.pleaseWaitStatus undefined
			@courses (new CourseViewModel course for course in courses)
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
		course.toData() for course in @courses()

class SelectedCourseViewModel
	constructor: ({course_id, selectedLectureSection, selectedLabSection}) ->
		@course_id = ko.observable course_id
		@selectedLectureSection = ko.observable selectedLectureSection
		@selectedLabSection = ko.observable selectedLabSection
		@course = ko.computed => _(viewmodel.coursesViewModel().courses()).find (x) -> x._id is @course_id
	toData: =>
		course_id: @course_id()
		selectedLectureSection: @selectedLectureSection()
		selectedLabSection: @selectedLabSection()

class StudentViewModel
	constructor: ({studentId, name, password, registered, validated, bc, psc, el, selectedcourses, _id}) ->
		@_id = ko.observable _id ? undefined
		@studentId = ko.observable studentId ? undefined
		@name = ko.observable name ? undefined
		@password = ko.observable password ? undefined
		@newPassword = ko.observable undefined
		@registered = ko.observable registered ? undefined
		@validated = ko.observable validated ? undefined
		@bc = ko.observableArray bc ? []
		@psc = ko.observableArray psc ? []
		@el = ko.observableArray el ? []
		@selectedcourses = ko.observableArray (new SelectedCourseViewModel sc for sc in selectedcourses ? [])
		@visible = ko.observable true
		@courses = ko.computed =>
			for course in viewmodel.coursesViewModel().courses()
				course: course
				bc: @bc().indexOf(course._id()) >= 0
				psc: @psc().indexOf(course._id()) >= 0
				el: @el().indexOf(course._id()) >= 0
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
	selectStudent: =>
		viewmodel.studentsViewModel().currentStudent @
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
		if @bc().indexOf($data.course._id()) >= 0
			@bc.remove $data.course._id()
		else
			@bc.push $data.course._id()
		@psc.remove $data.course._id()
		@el.remove $data.course._id()
	togglePsc: =>
		$data = arguments[0]
		if @psc().indexOf($data.course._id()) >= 0
			@psc.remove $data.course._id()
		else
			@psc.push $data.course._id()
		@bc.remove $data.course._id()
		@el.remove $data.course._id()
	toggleEl: =>
		$data = arguments[0]
		if @el().indexOf($data.course._id()) >= 0
			@el.remove $data.course._id()
		else
			@el.push $data.course._id()
		@bc.remove $data.course._id()
		@psc.remove $data.course._id()
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
	toggleRegistered: =>
		@registered not @registered()
	toggleValidated: =>
		@validated not @validated()
	resetPassword: =>
		@newPassword = md5(Date.toString())[0..8]
		@password = md5 @newPassword()
	toData: =>
		_id: @_id()
		studentId: @studentId()
		name: @name()
		password: @password()
		registered: @registered()
		validated: @validated()
		bc: @bc() if @bc().length > 0
		psc: @psc() if @psc().length > 0
		el: @el() if @el().length > 0
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
	newStudent: =>
		@students.push student = new StudentViewModel {}
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
	deleteAll: =>
		viewmodel.pleaseWaitStatus "Deleting all Students..."
		socket.emit "deleteAllStudents", (success) =>
			viewmodel.pleaseWaitStatus undefined
			@fetchStudents()
	toData: =>
		student.toData() for student in @students()

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

class BodyViewModel
	constructor: ->
		@coursesViewModel = ko.observable undefined
		@studentsViewModel = ko.observable undefined
		@pleaseWaitStatus = ko.observable undefined
		@pleaseWaitVisible = ko.computed => @pleaseWaitStatus()?
		@activeView = ko.observable undefined
		@authenticated = ko.observable false
		@semester = new SemesterViewModel()
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
			viewmodel.pleaseWaitStatus "Fetching Students..."
			viewmodel.coursesViewModel new CoursesViewModel courses: courses
			socket.emit "getStudents", (students) ->
				viewmodel.pleaseWaitStatus undefined
				viewmodel.studentsViewModel new StudentsViewModel students: students
				viewmodel.activeView "studentsView"
				$("#studentheader, #studentdetails").affix offset: top: 290
				$('button[rel=tooltip]').tooltip()
	gotoHome: =>
		@activeView "homeView"
		@semester.fetchSemester()
		$('input[rel=datetime]').datetimepicker()
	login: =>
		accessCode = $("#input-accesscode").val()
		socket.emit "login", accessCode, (success) =>
			viewmodel.pleaseWaitStatus undefined
			if success
				@authenticated true
				@gotoHome()
			else
				alert "Incorrect Password"
	logout: =>
		socket.emit "logout", =>
			@authenticated false

$ ->
	viewmodel = new BodyViewModel()
	viewmodel.pleaseWaitStatus "Connecting..."
	ko.applyBindings viewmodel, $("body")[0]

	socket = io.connect()
	socket.on "connect", ->
		viewmodel.pleaseWaitStatus undefined