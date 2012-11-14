$ ->
	socket = io.connect()
	socket.on "connect", ->
		$("#courses_btn, #students_btn").off "click"
		$("#courses_btn").click ->
			fs = new FileReader()
			fs.onload = (e) ->
				socket.emit "uploadCourses", e.target.result, (success) ->
					if success
						alert "Collection Courses now reflects the uploaded database."
					else
						alert "Parsing Error. Please recheck .csv file for errors."
			fs.readAsText $("#courses_fup")[0].files[0]
		$("#students_btn").click ->
			fs = new FileReader()
			fs.onload = (e) ->
				socket.emit "uploadStudents", e.target.result, (success) ->
					if success
						alert "Collection Students now reflects the uploaded database."
					else
						alert "Parsing Error. Please recheck .csv file for errors."
			fs.readAsText $("#students_fup")[0].files[0]