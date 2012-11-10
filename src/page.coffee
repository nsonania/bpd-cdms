$(document).ready ->
	socket = io.connect()

	$(".navbar .nav li a[data-content='courses'").click ->
		socket.emit "getAllCourses", (allCourses) ->
			$("#allCourses tbody").remove()
			$("#allCourses").append $ "<tbody>"
			for course in allCourses
				tr = $ """
					<tr>
						<td>#{course.compcode}</td>
						<td>#{course.number}</td>
						<td>#{course.name}</td>
					</tr>
				"""
				$("#allCourses tbody").append tr
				tr.click ->
					socket.emit "getCourseDetails", (CourseDetails) ->
						$("#allCourses tbody tr.courseDetails").remove()
						tr = $ """
							<tr>
								<td colspan="3">
									<div class="form-horizontal">
										<div class="control-group">
											<label class="control-label" for="input_compcode">Compcode</label>
											<div class="controls">
												<input type="text" id="input_compcode" placeholder="Compcode">
											</div>
										</div>
										<div class="control-group">
											<label class="control-label" for="input_coursenumber">Course No.</label>
											<div class="controls">
												<input type="text" id="input_coursenumber" placeholder="Course No.">
											</div>
										</div>
										<div class="control-group">
											<label class="control-label" for="input_coursename">Course Name</label>
											<div class="controls">
												<input type="text" id="input_coursename" placeholder="Course Name">
											</div>
										</div>
									</div>
								</td>
							</tr>
						"""