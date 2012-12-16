$ ->
	socket = io.connect()
	socket.on "connect", ->
		socket.emit "getCourses", (courses) ->
			$("#courselist table tr").remove()
			for course in courses
				$("#courselist table").append """
					<tr data-compcode="#{course.compcode}">
						<td>#{course.compcode}</td>
						<td>#{course.number}</td>
						<td>#{course.name}</td>
					</tr>
					"""

	$("#courses-search").keyup ->
		$("#courselist table tr").hide()
		$("#courselist table tr").filter(-> $(@).text().toLowerCase().indexOf($("#courses-search").val().toLowerCase()) >= 0).show()

	$("#lecturesectionsbox table tr td:last-of-type button").click ->
		$("#sectiondetails").modal "show"