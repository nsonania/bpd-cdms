$ ->
	socket = io.connect()
	socket.on "connect", ->
		socket.emit "getCourses", (courses) ->
			$("#courselist table tr").remove()
			for course in courses
				$tr = $ """
					<tr data-compcode="#{course.compcode}">
						<td>#{course.compcode}</td>
						<td>#{course.number}</td>
						<td>#{course.name}</td>
					</tr>
					"""
				$tr.data "course", course
				$("#courselist table").append $tr
			$("#courselist table tr").click -> selectCourse @
			$("#courselist table tr:first-of-type").click()

	$("#courses-search").keyup ->
		$("#courselist table tr").hide()
		$("#courselist table tr").filter(-> $(@).text().toLowerCase().indexOf($("#courses-search").val().toLowerCase()) >= 0).show()

	selectCourse = (elem) ->
		$("#courselist table tr").removeClass "info"
		$(elem).addClass "info"
		$("#input-1compcode").val $(elem).data("course").compcode
		$("#input-1number").val $(elem).data("course").number
		$("#input-1name").val $(elem).data("course").name

		$("#lecturesectionsbox table tr").remove()
		if $(elem).data("course").lectureSections?
			for lectureSection in $(elem).data("course").lectureSections then do (lectureSection) ->
				$tr = $ """
					<tr>
						<td>#{lectureSection.number}</td>
						<td>#{lectureSection.instructor}</td>
						<td><button class="btn btn-small"><i class="icon-pencil"></i></button></td>
					</tr>
					"""
				$tr.find("td:last-of-type button").click ->
					$("sectiondetails").data "section", lectureSection
					$("sectiondetails").data "$tr", $tr
					$("#sectiondetailsLabel").text "Lecture Section"
					$("#input-2number").val lectureSection.number
					$("#input-2incharge").val lectureSection.instructor
					$("#makeschedule td").removeClass("selected")
					for timeslot in lectureSection.timeslots
						$("#makeschedule tr:nth-of-type(#{timeslot.hour}) td:nth-of-type(#{timeslot.day})").addClass "selected"
					$("#sectiondetails").modal "show"
				$("#lecturesectionsbox table").append $tr

		$("#labsectionsbox table tr").remove()
		if $(elem).data("course").labSections?
			for labSection in $(elem).data("course").labSections then do (labSection) ->
				$tr = $ """
					<tr>
						<td>#{labSection.number}</td>
						<td>#{labSection.instructor}</td>
						<td><button class="btn btn-small"><i class="icon-pencil"></i></button></td>
					</tr>
					"""
				$tr.find("td:last-of-type button").click ->
					$("sectiondetails").data "section", labSection
					$("sectiondetails").data "$tr", $tr
					$("#sectiondetailsLabel").text "Lab Section"
					$("#input-2number").val labSection.number
					$("#input-2incharge").val labSection.instructor
					$("#makeschedule td").removeClass("selected")
					for timeslot in labSection.timeslots
						$("#makeschedule tr:nth-of-type(#{timeslot.hour}) td:nth-of-type(#{timeslot.day})").addClass "selected"
					$("#sectiondetails").modal "show"
				$("#labsectionsbox table").append $tr

	$("#input-1compcode").change ->
		$("#courselist table tr.info").data("course").compcode = $("#input-1compcode").val()
		$("#courselist table tr.info").find("td:nth-of-type(1)").text $("#input-1compcode").val()

	$("#input-1number").change ->
		$("#courselist table tr.info").data("course").number = $("#input-1number").val()
		$("#courselist table tr.info").find("td:nth-of-type(2)").text $("#input-1number").val()

	$("#input-1name").change ->
		$("#courselist table tr.info").data("course").name = $("#input-1name").val()
		$("#courselist table tr.info").find("td:nth-of-type(3)").text $("#input-1name").val()

	#...