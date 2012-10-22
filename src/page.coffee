$(document).ready ->
		$("#loginbox input").addClass if $(document).width() >= 1200 then "span3" else "span2"
		$("#courses-sections").addClass if $(document).width() >= 1200 then "span8 offset2" else "span12"
		$("#timetable-grid").addClass if $(document).width() >= 1200 then "span10 offset1" else "span12"
		$(window).resize ->
			if $(document).width() >= 1200
				$("#loginbox input").removeClass("span2").addClass("span3")
				$("#courses-sections").removeClass("span12").addClass("span8 offset2")
				$("#timetable-grid").removeClass("span12").addClass("span10 offset1")
			else
				$("#loginbox input").removeClass("span3").addClass("span2")
				$("#courses-sections").removeClass("span8 offset2").addClass("span12")
				$("#timetable-grid").removeClass("span10 offset1").addClass("span12")