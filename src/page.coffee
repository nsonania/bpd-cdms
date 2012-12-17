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
				$tr.data "lectureSections", course.lectureSections
				$tr.data "labSections", course.labSections
				$("#courselist table").append $tr
			$("#courselist table tr").click -> selectCourse @
			$("#courselist table tr:first-of-type").click()

	$("#courses-search").keyup ->
		$("#courselist table tr").hide()
		$("#courselist table tr").filter(-> $(@).text().toLowerCase().indexOf($("#courses-search").val().toLowerCase()) >= 0).show()

	selectCourse = (elem) ->
		$("#courselist table tr").removeClass "info"
		$(elem).addClass "info"
		$("#input-1compcode").val $(elem).find("td:nth-of-type(1)").text()
		$("#input-1number").val $(elem).find("td:nth-of-type(2)").text()
		$("#input-1name").val $(elem).find("td:nth-of-type(3)").text()

		$("#lecturesectionsbox table tr").remove()
		for lectureSection in $(elem).data "lectureSections" then do ->
			$tr = $ """
				<tr>
					<td>#{lectureSection.number}</td>
					<td>#{lectureSection.instructor}</td>
					<td><button class="btn btn-small"><i class="icon-pencil"></i></button></td>
				</tr>
				"""
			$tr.find("td:last-of-type button").click ->
				$("#sectiondetailsLabel").text "Lecture Section"
				$("#input-2number").val $tr.find("td:nth-of-type(1)").text()
				$("#input-2incharge").val $tr.find("td:nth-of-type(2)").text()
				$("#makeschedule td").removeClass("selected")
				for timeslot in lectureSection.timeslots
					$("#makeschedule tr:nth-of-type(#{timeslot.hour}) td:nth-of-type(#{timeslot.day})").addClass "selected"
				$("#sectiondetails").modal "show"

			$("#lecturesectionsbox table").append $tr

	$("#input-1compcode").change ->
		$("#courselist table tr.info").find("td:nth-of-type(1)").text $("#input-1compcode").val()

	$("#input-1number").change ->
		$("#courselist table tr.info").find("td:nth-of-type(2)").text $("#input-1number").val()

	$("#input-1name").change ->
		$("#courselist table tr.info").find("td:nth-of-type(3)").text $("#input-1name").val()