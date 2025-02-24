class_name SVGPathRef
extends RefCounted



var elements: Array[SVGPathRef]
var isClosed: bool = false

var should_regenerate_line_segments: bool = true
var line_segments: Array[SVGPathlineSegments]:
	get:
		if (should_regenerate_line_segments):
			line_segments = generate_line_segments()
			should_regenerate_line_segments = false
		return line_segments

var has_subpaths: bool:
	get:
		if (elements):
			for element: SVGPathRef in elements:
				if (element.type == SVGPathRef.Type.MOVE_TO):
					if (element != elements.front()):

						return true
		return false


enum BasicPathType
{
	NONE, 
	OVAL, 
	RECT, 
	POLYGON, 
	LINE, 
}


var basicType: BasicPathType = BasicPathType.NONE


func generate_line_segments() -> Array[SVGPathlineSegments]:

	var new_line_segments: Array[SVGPathlineSegments] = []


	var pathStartElement: SVGPathRef = null
	var previousElement: SVGPathRef = null
	var lineSegment: SVGPathlineSegments = null
	var previousLineSegment: SVGPathlineSegments = null

	for element: SVGPathRef in elements:

		if (element.type == SVGPathRef.Type.LINE_TO || element.type == SVGPathRef.Type.CURVE_TO):

			if (previousElement):
				lineSegment = SVGPathlineSegments.new(previousElement, element)
				lineSegment.continuousAtEnd = true
				new_line_segments.append(lineSegment)
			else:
				push_warning("generate_line_segments could not generate segment from null to " + str(element), self)
		elif (element.type == SVGPathRef.Type.MOVE_TO):

			pathStartElement = element
			if (previousLineSegment):
				previousLineSegment.continuousAtEnd = false
		elif (element.type == SVGPathRef.Type.CLOSE_PATH):

			if (pathStartElement && previousElement):
				if (previousElement.point != pathStartElement.point):

					lineSegment = SVGPathlineSegments.new(previousElement, pathStartElement)
					new_line_segments.append(lineSegment)
					lineSegment.continuousAtEnd = true
					lineSegment.closePathAtEnd = true
				else:
					if (previousLineSegment):
						previousLineSegment.closePathAtEnd = true
				pathStartElement = null
			else:
				if ( !pathStartElement):
					push_warning("generate_line_segments could not close path since pathStartElement is null", self)
				if ( !previousElement):
					push_warning("generate_line_segments could not close path since lastElement is null", self)

		previousElement = element
		previousLineSegment = lineSegment

	return new_line_segments



func addElement(new_type: SVGPathRef.Type, point1_x: float = 0, point1_y: float = 0, point2_x: float = 0, point2_y: float = 0, point3_x: float = 0, point3_y: float = 0) -> void :
	var element: SVGPathRef = SVGPathRef.new(new_type, point1_x, point1_y, point2_x, point2_y, point3_x, point3_y)
	elements.append(element)


	if (new_type == SVGPathRef.Type.CLOSE_PATH):
		isClosed = true
	else:
		if (new_type != SVGPathRef.Type.MOVE_TO):
			isClosed = false


	should_regenerate_line_segments = true
	should_regenerate_svgString = true
	needs_recalculate_bounds = true








func addElementBetweenControlPoints(point1: SVGPathPoints, point2: SVGPathPoints) -> void :
	if (point1.handles_type == SVGPathPoints.HandlesType.NONE && point2.handles_type == SVGPathPoints.HandlesType.NONE):

		addElement(SVGPathRef.Type.LINE_TO, point2.position.x, point2.position.y)
	elif (point1.handle_offset2 == Vector2.ZERO && point2.handle_offset1 == Vector2.ZERO):

		addElement(SVGPathRef.Type.LINE_TO, point2.position.x, point2.position.y)
	else:

		addElement(SVGPathRef.Type.CURVE_TO, point2.position.x, point2.position.y
			, point1.position.x + point1.handle_offset2.x, point1.position.y + point1.handle_offset2.y
			, point2.position.x + point2.handle_offset1.x, point2.position.y + point2.handle_offset1.y)



func addElementsWithControlPoints(control_points: Array[SVGPathPoints]) -> void :
	var start_point: SVGPathPoints = null
	var previous_point: SVGPathPoints = null


	var controls_points_path_open: bool = false
	var first_end_point_index: int = 0
	for point: SVGPathPoints in control_points:
		if ( !point.previous_point):
			controls_points_path_open = true
			break
		first_end_point_index = first_end_point_index + 1

	if (controls_points_path_open):

		var reordered_control_points: Array[SVGPathPoints] = []
		for index: int in control_points.size():
			reordered_control_points.append(control_points[(first_end_point_index + index) % control_points.size()])

		control_points = reordered_control_points

	for point: SVGPathPoints in control_points:
		if ( !point.previous_point || point.previous_point != previous_point):

			if (previous_point):
				if (previous_point.next_point):
					if (start_point):
						addElementBetweenControlPoints(previous_point, start_point)

					addElement(SVGPathRef.Type.CLOSE_PATH)

			addElement(SVGPathRef.Type.MOVE_TO, point.position.x, point.position.y)
			start_point = point
		else:
			addElementBetweenControlPoints(previous_point, point)
		previous_point = point

	if (previous_point):
		if (previous_point.next_point):
			addElementBetweenControlPoints(previous_point, previous_point.next_point)
		if (previous_point.next_point == start_point):

			addElement(SVGPathRef.Type.CLOSE_PATH)



func getControlPoints() -> Array[SVGPathPoints]:
	var control_points: Array[SVGPathPoints]
	var sub_path_start_point: SVGPathPoints = null
	var point: SVGPathPoints = null
	var previous_point: SVGPathPoints = null
	var should_add_start_point: bool = false
	var should_add_end_point: bool = false

	for line_segment: SVGPathlineSegments in line_segments:


		should_add_start_point = false
		if ( !sub_path_start_point):
			should_add_start_point = true

		if (should_add_start_point):

			point = SVGPathPoints.new(line_segment.start.point)
			point.handles_type = SVGPathPoints.HandlesType.INDEPENDENT
			point.handle_offset1 = Vector2(0, 0)
			point.handle_offset2 = Vector2(0, 0)

			control_points.append(point)
			previous_point = point
			if ( !sub_path_start_point):

				sub_path_start_point = point

		should_add_end_point = true
		if (line_segment.closePathAtEnd):

			should_add_end_point = false

		if (should_add_end_point):

			point = SVGPathPoints.new(line_segment.end.point)

			if (line_segment.isCurve):

				if (previous_point):
					previous_point.handle_offset2 = line_segment.end.control_point1 - line_segment.start.point


				point.handle_offset1 = line_segment.end.control_point2 - line_segment.end.point
				point.handles_type = SVGPathPoints.HandlesType.INDEPENDENT
			control_points.append(point)


			if (previous_point):
				point.previous_point = previous_point
		else:

			if (previous_point):
				previous_point.next_point = sub_path_start_point
				if (line_segment.isCurve):
					previous_point.handle_offset2 = line_segment.end.control_point1 - line_segment.start.point
					previous_point.handles_type = SVGPathPoints.HandlesType.INDEPENDENT
				if (sub_path_start_point && line_segment.isCurve):
					sub_path_start_point.handle_offset1 = line_segment.end.control_point2 - line_segment.end.point
					sub_path_start_point.handles_type = SVGPathPoints.HandlesType.INDEPENDENT
		previous_point = point


		if ( !line_segment.continuousAtEnd || line_segment.closePathAtEnd):

			sub_path_start_point = null


	for a_point: SVGPathPoints in control_points:
		if (a_point.handle_offset1.length() == 0 && a_point.handle_offset2.length() == 0):

			a_point.handles_type = SVGPathPoints.HandlesType.NONE
		else:

			if (is_equal_approx(a_point.handle_offset1.x, - a_point.handle_offset2.x) && is_equal_approx(a_point.handle_offset1.y, - a_point.handle_offset2.y)):

				a_point.handles_type = SVGPathPoints.HandlesType.MIRRORED
			elif (is_equal_approx(a_point.handle_offset1.normalized().x, - a_point.handle_offset2.normalized().x) && is_equal_approx(a_point.handle_offset1.normalized().y, - a_point.handle_offset2.normalized().y)):

				a_point.handles_type = SVGPathPoints.HandlesType.MIRRORED_ANGLE
			else:
				a_point.handles_type = SVGPathPoints.HandlesType.INDEPENDENT

	return control_points







func pathLength() -> float:
	var length: float

	for line_segment: SVGPathlineSegments in line_segments:

		length = length + line_segment.segmentLength()

	return length


var path_point_angle: float


func pointAlongPath(target_length: float, calculate_path_point_angle: bool = false) -> Vector2:
	var path_point: Vector2 = Vector2(0, 0)

	var segment_start_length: float = 0
	var segment_length: float = 0
	var found_line_segment: SVGPathlineSegments = null
	var found_segment_start_length: float = 0

	for line_segment: SVGPathlineSegments in line_segments:

		segment_length = line_segment.segmentLength()
		if (target_length >= segment_start_length && target_length < segment_start_length + segment_length):

			found_line_segment = line_segment
			found_segment_start_length = segment_start_length
			break


		segment_start_length = segment_start_length + segment_length

	if (found_line_segment):

		path_point = found_line_segment.pointAlongSegment(target_length - found_segment_start_length)
		if (calculate_path_point_angle):

			path_point_angle = found_line_segment.angleAlongSegment(target_length - found_segment_start_length)
	else:
		if (line_segments.size()):

			path_point = line_segments.back().end.point
			if (calculate_path_point_angle):
				path_point_angle = line_segments.back().angleAlongSegment(line_segments.back().segmentLength())

	return path_point





var needs_recalculate_bounds: bool = true
var cached_bounds: Rect2


func boundingBox() -> Rect2:
	if ( !needs_recalculate_bounds):

		return cached_bounds

	if (elements.size() < 2):
		if (elements.size() == 1):

			return Rect2(elements.front().point, Vector2(0, 0))
		else:

			return Rect2(Vector2(0, 0), Vector2(0, 0))

	var min_point: Vector2 = Vector2(1000000, 1000000)
	var max_point: Vector2 = Vector2(-1000000, -1000000)
	var boundsRect: Rect2

	for line_segment: SVGPathlineSegments in line_segments:

		boundsRect = line_segment.boundingBox()
		if (boundsRect.position.x < min_point.x):
			min_point.x = boundsRect.position.x
		if (boundsRect.end.x > max_point.x):
			max_point.x = boundsRect.end.x
		if (boundsRect.position.y < min_point.y):
			min_point.y = boundsRect.position.y
		if (boundsRect.end.y > max_point.y):
			max_point.y = boundsRect.end.y


	var rect: Rect2 = Rect2(min_point, max_point - min_point)
	if (rect.size.x < 0):
		rect.size.x = 0
	if (rect.size.y < 0):
		rect.size.y = 0

	cached_bounds = rect
	needs_recalculate_bounds = false

	return rect



func closestPointOnPath(point: Vector2) -> Dictionary:
	var result: Dictionary = {}
	if (elements.size() > 0):

		var closest_point_distance: float = elements.front().point.distance_to(point)
		var closest_path_distance: float = 0
		var closest_path_point: Vector2


		var path_distance: float = 0
		var point_distance: float

		var full_path_length: float = pathLength()
		var end_path_distance: float = full_path_length
		var path_distance_step: float = (end_path_distance - path_distance) / 10
		var path_point: Vector2
		if (path_distance_step > 0):
			var iteration: int = 0
			while iteration < 3:



				while path_distance <= end_path_distance:

					path_point = pointAlongPath(path_distance)



					point_distance = path_point.distance_to(point)
					if (point_distance < closest_point_distance):

						closest_point_distance = point_distance

						closest_path_distance = path_distance
						closest_path_point = path_point


					path_distance = path_distance + path_distance_step



				path_distance = max(0, closest_path_distance - path_distance_step)
				end_path_distance = min(closest_path_distance + path_distance_step, full_path_length)
				path_distance_step = (end_path_distance - path_distance) / 10


				iteration = iteration + 1
		else:

			pass


		result.point = closest_path_point
		result.path_distance = closest_path_distance
		result.distance = closest_point_distance

	return result


func pointNearPath(point: Vector2, maxDist: float) -> bool:
	if (elements.size() > 0):
		var distanceToPath: float


		for line_segment: SVGPathlineSegments in line_segments:
			distanceToPath = line_segment.distanceToPoint(point)
			if (distanceToPath < maxDist):

				return true

	return false



func pointInPath(point: Vector2, open_path_fill_area_check: bool = true) -> bool:
	if (elements.size() > 0):
		var farPoint: Vector2 = point + Vector2(1000000, 0)
		var winding_number: int = 0




		for line_segment: SVGPathlineSegments in line_segments:

			winding_number = winding_number + line_segment.lineIntersectionsWindingNumber(point, farPoint)






		if ( !isClosed && open_path_fill_area_check):
			if (SVGPathlineSegments.lines_intersect(point, farPoint, line_segments.front().start.point, line_segments.back().end.point)):

				if (line_segments.back().end.point.y > line_segments.front().start.point.y):
					winding_number = winding_number - 1
				else:
					winding_number = winding_number + 1



		if (winding_number != 0):

			return true

	return false




























func transformedCopy(transform: Transform2D) -> SVGPathRef:
	var transformedPath: SVGPathRef = SVGPathRef.new()

	if (elements):

		for element: SVGPathRef in elements:
			transformedPath.elements.append(element.transformedCopy(transform))
		transformedPath.isClosed = isClosed

	return transformedPath




func reversedCopy() -> SVGPathRef:
	var reversedPath: SVGPathRef = SVGPathRef.new()


	var element_index: int = elements.size() - 1
	var path_element: SVGPathRef
	var previous_path_element: SVGPathRef

	var end_point_x: float
	var end_point_y: float

	var cp1_x: float
	var cp1_y: float
	var cp2_x: float
	var cp2_y: float

	var should_close: bool = false

	while element_index > -1:
		path_element = elements[element_index]
		if (path_element.type == SVGPathRef.Type.CLOSE_PATH):
			previous_path_element = null
			should_close = true
		else:

			end_point_x = path_element.point_x
			end_point_y = path_element.point_y

			if (previous_path_element):

				if (previous_path_element.type == SVGPathRef.Type.LINE_TO):
					reversedPath.elements.append(SVGPathRef.new(SVGPathRef.Type.LINE_TO, end_point_x, end_point_y))

				if (previous_path_element.type == SVGPathRef.Type.CURVE_TO):

					cp1_x = previous_path_element.control_point2_x
					cp1_y = previous_path_element.control_point2_y
					cp2_x = previous_path_element.control_point1_x
					cp2_y = previous_path_element.control_point1_y
					reversedPath.elements.append(SVGPathRef.new(SVGPathRef.Type.CURVE_TO, end_point_x, end_point_y, cp1_x, cp1_y, cp2_x, cp2_y))

			else:

				reversedPath.elements.append(SVGPathRef.new(SVGPathRef.Type.MOVE_TO, end_point_x, end_point_y))


			if (path_element.type == SVGPathRef.Type.MOVE_TO):

				if (should_close):
					reversedPath.elements.append(SVGPathRef.new(SVGPathRef.Type.CLOSE_PATH))

					should_close = false

			previous_path_element = path_element

		element_index = element_index - 1





	reversedPath.isClosed = isClosed

	return reversedPath





var cached_rendering_path_fill_points: PackedVector2Array = []
var cached_rendering_path_points_rendering_scale: float = 0

func draw_stroke(canvas: CanvasItem, color: Color, stroke_width: float = 1, anti_alias: bool = false, rendering_scale: float = 1) -> void :

	var points: PackedVector2Array = []
	for line_segment: SVGPathlineSegments in line_segments:

		if (line_segment.isCurve):
			line_segment.desiredCurvePointScale = rendering_scale
			points.append_array(line_segment.curvePoints)
		else:
			if (points.size() == 0):
				points.append(line_segment.start.point)
			points.append(line_segment.end.point)

		if ( !line_segment.continuousAtEnd || line_segment.closePathAtEnd):

			if (points.size() > 1):
				canvas.draw_polyline(points, color, stroke_width, anti_alias)
			points.clear()


	if (points.size() > 1):
		canvas.draw_polyline(points, color, stroke_width, anti_alias)



func draw_fill(canvas: CanvasItem, color: Color, rendering_scale: float = 1) -> void :

	if ( !cached_rendering_path_fill_points || rendering_scale != cached_rendering_path_points_rendering_scale):

		cached_rendering_path_fill_points = []

		for line_segment: SVGPathlineSegments in line_segments:

			if (line_segment.isCurve):
				line_segment.desiredCurvePointScale = rendering_scale
				cached_rendering_path_fill_points.append_array(line_segment.curvePoints)




			else:

				cached_rendering_path_fill_points.append(line_segment.end.point)


		cached_rendering_path_points_rendering_scale = rendering_scale

	if (cached_rendering_path_fill_points.size() > 2):
		canvas.draw_colored_polygon(cached_rendering_path_fill_points, color)





var should_regenerate_svgString: bool = true
var svgString: String:
	get:
		if ( !svgString || should_regenerate_svgString):
			svgString = generateSvgString()
			should_regenerate_svgString = false
		return svgString



func generateSvgString() -> String:
	var elementsString: String = ""
	if (elements):
		var element_strings: PackedStringArray
		var firstElement: bool = true
		for element: SVGPathRef in elements:
			if (firstElement):

				element_strings.append(element.svgString())
				firstElement = false
			else:

				element_strings.append(" ")
				element_strings.append(element.svgString())

		elementsString = "".join(element_strings)

	return elementsString





func addRect(positionX: float, positionY: float, sizeX: float, sizeY: float) -> void :

	addElement(SVGPathRef.Type.MOVE_TO, positionX, positionY)

	addElement(SVGPathRef.Type.LINE_TO, positionX + sizeX, positionY)
	addElement(SVGPathRef.Type.LINE_TO, positionX + sizeX, positionY + sizeY)
	addElement(SVGPathRef.Type.LINE_TO, positionX, positionY + sizeY)

	addElement(SVGPathRef.Type.CLOSE_PATH)

const CIRCLE_ARC_APPROXIMATION: float = 0.55228474983079


func addOvalInRect(positionX: float, positionY: float, sizeX: float, sizeY: float) -> void :


	var top_x: float = positionX + sizeX / 2
	var top_y: float = positionY
	var right_x: float = positionX + sizeX
	var right_y: float = positionY + sizeY / 2
	var bottom_x: float = positionX + sizeX / 2
	var bottom_y: float = positionY + sizeY
	var left_x: float = positionX
	var left_y: float = positionY + sizeY / 2

	var half_height: float = sizeY / 2
	var half_width: float = sizeX / 2


	addElement(SVGPathRef.Type.MOVE_TO, top_x, top_y)


	addElement(SVGPathRef.Type.CURVE_TO, right_x, right_y, 
			top_x + half_width * CIRCLE_ARC_APPROXIMATION, top_y, 
			right_x, right_y - half_height * CIRCLE_ARC_APPROXIMATION)
	addElement(SVGPathRef.Type.CURVE_TO, bottom_x, bottom_y, 
			right_x, right_y + half_height * CIRCLE_ARC_APPROXIMATION, 
			bottom_x + half_width * CIRCLE_ARC_APPROXIMATION, bottom_y)
	addElement(SVGPathRef.Type.CURVE_TO, left_x, left_y, 
			bottom_x - half_width * CIRCLE_ARC_APPROXIMATION, bottom_y, 
			left_x, left_y + half_height * CIRCLE_ARC_APPROXIMATION)
	addElement(SVGPathRef.Type.CURVE_TO, top_x, top_y, 
			left_x, left_y - half_height * CIRCLE_ARC_APPROXIMATION, 
			top_x - half_width * CIRCLE_ARC_APPROXIMATION, top_y)

	addElement(SVGPathRef.Type.CLOSE_PATH)



func addArcSegment(centerX: float, centerY: float, radius: float, start_angle: float, end_angle: float, new_subpath: bool = true) -> void :

	var start_x: float = centerX + radius * cos(start_angle)
	var start_y: float = centerY + radius * sin(start_angle)

	var end_x: float = centerX + radius * cos(end_angle)
	var end_y: float = centerY + radius * sin(end_angle)


	if (new_subpath):

		addElement(SVGPathRef.Type.MOVE_TO, start_x, start_y)

	if (is_equal_approx(end_angle, start_angle)):


		addElement(SVGPathRef.Type.LINE_TO, end_x, end_y)
	else:



		var ALPHA: float = (end_angle - start_angle) / 2.0
		var COS_ALPHA: float = cos(ALPHA)
		var SIN_ALPHA: float = sin(ALPHA)
		var COT_ALPHA: float = 1.0 / tan(ALPHA)
		var PHI: float = start_angle + ALPHA
		var COS_PHI: float = cos(PHI)
		var SIN_PHI: float = sin(PHI)
		var LAMBDA: float = (4.0 - COS_ALPHA) / 3.0
		var MU: float = SIN_ALPHA + (COS_ALPHA - LAMBDA) * COT_ALPHA


		var cp1: Vector2 = Vector2(centerX + radius * (LAMBDA * COS_PHI + MU * SIN_PHI), centerY + radius * (LAMBDA * SIN_PHI - MU * COS_PHI))
		var cp2: Vector2 = Vector2(centerX + radius * (LAMBDA * COS_PHI - MU * SIN_PHI), centerY + radius * (LAMBDA * SIN_PHI + MU * COS_PHI))

		addElement(SVGPathRef.Type.CURVE_TO, end_x, end_y, cp1.x, cp1.y, cp2.x, cp2.y)



func addArc(centerX: float, centerY: float, radius: float, start_angle: float, end_angle: float, new_subpath: bool = true) -> void :

	start_angle = start_angle - PI / 2
	end_angle = end_angle - PI / 2

	if ( !new_subpath):
		var start_x: float = centerX + radius * cos(start_angle)
		var start_y: float = centerY + radius * sin(start_angle)

		if (elements):
			var lastElement: SVGPathRef = elements.back()
			if ( !is_equal_approx(lastElement.point.x, start_x) || !is_equal_approx(lastElement.point.y, start_y)):


				addElement(SVGPathRef.Type.LINE_TO, start_x, start_y)

	var angle_delta: float = end_angle - start_angle

	if (absf(angle_delta) <= PI / 2):

		addArcSegment(centerX, centerY, radius, start_angle, end_angle, new_subpath)
	else:

		if (angle_delta > 0):
			while angle_delta > 0:

				addArcSegment(centerX, centerY, radius, start_angle, start_angle + minf(angle_delta, PI / 2), new_subpath)
				start_angle = start_angle + PI / 2
				angle_delta = angle_delta - PI / 2
				new_subpath = false
		else:

			while angle_delta < 0:

				addArcSegment(centerX, centerY, radius, start_angle, start_angle + maxf(angle_delta, - PI / 2), new_subpath)
				start_angle = start_angle - PI / 2
				angle_delta = angle_delta + PI / 2
				new_subpath = false



func addArcWedge(centerX: float, centerY: float, radius: float, start_angle: float, end_angle: float, inner_radius: float = 0) -> void :

	addArc(centerX, centerY, radius, start_angle, end_angle)

	if (inner_radius > 0):

		addArc(centerX, centerY, inner_radius, end_angle, start_angle, false)
	else:

		addElement(SVGPathRef.Type.LINE_TO, centerX, centerY)


	addElement(SVGPathRef.Type.CLOSE_PATH)



func addRoundedRect(positionX: float, positionY: float, sizeX: float, sizeY: float, radius: float) -> void :
	if (radius > sizeX / 2):
		radius = sizeX / 2
	if (radius > sizeY / 2):
		radius = sizeY / 2

	var top_left_x: float = positionX
	var top_left_y: float = positionY
	var top_right_x: float = positionX + sizeX
	var top_right_y: float = positionY
	var bottom_left_x: float = positionX
	var bottom_left_y: float = positionY + sizeY
	var bottom_right_x: float = positionX + sizeX
	var bottom_right_y: float = positionY + sizeY

	var half_height: float = radius
	var half_width: float = radius




	addElement(SVGPathRef.Type.MOVE_TO, top_right_x - radius, top_right_y)

	addElement(SVGPathRef.Type.CURVE_TO, top_right_x, top_right_y + radius, 
			top_right_x - radius + half_width * CIRCLE_ARC_APPROXIMATION, top_right_y, 
			top_right_x, top_right_y + radius - half_height * CIRCLE_ARC_APPROXIMATION)

	addElement(SVGPathRef.Type.LINE_TO, bottom_right_x, bottom_right_y - radius)

	addElement(SVGPathRef.Type.CURVE_TO, bottom_right_x - radius, bottom_right_y, 
			bottom_right_x, bottom_right_y - radius + half_height * CIRCLE_ARC_APPROXIMATION, 
			bottom_right_x - radius + half_width * CIRCLE_ARC_APPROXIMATION, bottom_right_y)

	addElement(SVGPathRef.Type.LINE_TO, bottom_left_x + radius, bottom_left_y)

	addElement(SVGPathRef.Type.CURVE_TO, bottom_left_x, bottom_left_y - radius, 
			bottom_left_x + radius - half_width * CIRCLE_ARC_APPROXIMATION, bottom_left_y, 
			bottom_left_x, bottom_left_y - radius + half_height * CIRCLE_ARC_APPROXIMATION)

	addElement(SVGPathRef.Type.LINE_TO, top_left_x, top_left_y + radius)

	addElement(SVGPathRef.Type.CURVE_TO, top_left_x + radius, top_left_y, 
			top_left_x, top_left_y + radius - half_height * CIRCLE_ARC_APPROXIMATION, 
			top_left_x + radius - half_width * CIRCLE_ARC_APPROXIMATION, top_left_y)


	addElement(SVGPathRef.Type.CLOSE_PATH)



func addSmoothPolygon(radius: float, sides: int, rounding: float = 0) -> void :
	if (sides > 2):

		var smooth: float = (rounding) * (PI / (sides * 2)) * radius * sqrt(2)


		var point_x: float
		var point_y: float
		var c_point1_x: float
		var c_point1_y: float
		var c_point2_x: float
		var c_point2_y: float
		var angleStart: float = - PI / 2
		var angleStep: float = PI * 2.0 / sides

		var steps: int = sides + 1
		if (rounding == 0):

			steps = steps - 1

		for i: int in range(0, steps):
			point_x = cos(angleStart + angleStep * i) * radius
			point_y = sin(angleStart + angleStep * i) * radius

			if (i == 0):

				addElement(SVGPathRef.Type.MOVE_TO, point_x, point_y)
			else:
				if (smooth == 0):

					addElement(SVGPathRef.Type.LINE_TO, point_x, point_y)
				else:
					if (smooth > 0):

						c_point1_x = cos(angleStart + angleStep * (i - 1)) * radius - cos(angleStart + angleStep * (i - 1) - PI / 2.0) * smooth
						c_point1_y = sin(angleStart + angleStep * (i - 1)) * radius - sin(angleStart + angleStep * (i - 1) - PI / 2.0) * smooth

						c_point2_x = point_x + cos(angleStart + angleStep * i - PI / 2.0) * smooth
						c_point2_y = point_y + sin(angleStart + angleStep * i - PI / 2.0) * smooth
					else:

						c_point1_x = cos(angleStart + angleStep * (i - 1)) * radius + cos(angleStart + angleStep * (i - 1)) * smooth
						c_point1_y = sin(angleStart + angleStep * (i - 1)) * radius + sin(angleStart + angleStep * (i - 1)) * smooth

						c_point2_x = point_x + cos(angleStart + angleStep * i) * smooth
						c_point2_y = point_y + sin(angleStart + angleStep * i) * smooth

					addElement(SVGPathRef.Type.CURVE_TO, point_x, point_y, c_point1_x, c_point1_y, c_point2_x, c_point2_y)


		addElement(SVGPathRef.Type.CLOSE_PATH)




func addSmoothStar(outer_radius: float, inner_radius: float, sides: int, outer_rounding: float = 0, inner_rounding: float = 0) -> void :
	if (sides > 2):

		var outer_smooth: float = (outer_rounding) * (PI / (sides * 4)) * outer_radius * sqrt(2)
		var inner_smooth: float = (inner_rounding) * (PI / (sides * 4)) * inner_radius * sqrt(2)


		var point_x: float
		var point_y: float
		var c_point1_x: float
		var c_point1_y: float
		var c_point2_x: float
		var c_point2_y: float
		var angleStart: float = - PI / 2
		var angleStep: float = PI * 2.0 / sides


		var steps: int = sides * 2
		steps = steps + 1
		angleStep = angleStep / 2


		if (outer_rounding == 0 && inner_rounding == 0):

			steps = steps - 1

		var is_outer_point: bool = true
		var radius: float = inner_radius
		var smooth: float = inner_smooth
		var last_radius: float
		var last_smooth: float

		for i: int in range(0, steps):

			last_radius = radius
			last_smooth = smooth
			if (is_outer_point):
				radius = outer_radius
				smooth = outer_smooth
			else:
				radius = inner_radius
				smooth = inner_smooth
			is_outer_point = !is_outer_point

			point_x = cos(angleStart + angleStep * i) * radius
			point_y = sin(angleStart + angleStep * i) * radius

			if (i == 0):

				addElement(SVGPathRef.Type.MOVE_TO, point_x, point_y)
			else:
				if (smooth == 0 && last_smooth == 0):

					addElement(SVGPathRef.Type.LINE_TO, point_x, point_y)
				else:
					if (last_smooth > 0):

						c_point1_x = cos(angleStart + angleStep * (i - 1)) * last_radius - cos(angleStart + angleStep * (i - 1) - PI / 2.0) * last_smooth
						c_point1_y = sin(angleStart + angleStep * (i - 1)) * last_radius - sin(angleStart + angleStep * (i - 1) - PI / 2.0) * last_smooth
					else:

						c_point1_x = cos(angleStart + angleStep * (i - 1)) * last_radius + cos(angleStart + angleStep * (i - 1)) * last_smooth
						c_point1_y = sin(angleStart + angleStep * (i - 1)) * last_radius + sin(angleStart + angleStep * (i - 1)) * last_smooth

					if (smooth > 0):

						c_point2_x = point_x + cos(angleStart + angleStep * i - PI / 2.0) * smooth
						c_point2_y = point_y + sin(angleStart + angleStep * i - PI / 2.0) * smooth
					else:

						c_point2_x = point_x + cos(angleStart + angleStep * i) * smooth
						c_point2_y = point_y + sin(angleStart + angleStep * i) * smooth

					addElement(SVGPathRef.Type.CURVE_TO, point_x, point_y, c_point1_x, c_point1_y, c_point2_x, c_point2_y)



		addElement(SVGPathRef.Type.CLOSE_PATH)



func addPolygon(points: Array[Vector2], closed: bool = true) -> void :
	if (points.size() > 1):
		var firstPoint: bool = true
		for point: Vector2 in points:
			if (firstPoint):

				addElement(SVGPathRef.Type.MOVE_TO, point.x, point.y)
				firstPoint = false
			else:

				addElement(SVGPathRef.Type.LINE_TO, point.x, point.y)

		if (closed):
			addElement(SVGPathRef.Type.CLOSE_PATH)
	else:
		push_warning("addPolygon expected at least 2 points", self)








func _to_string() -> String:
	var closedString: String = "closed"
	if ( !isClosed): closedString = "open"
	return "<SVGPathRef #" + ("%X" % get_instance_id()).substr(5) + " (" + closedString + " " + str(elements.size()) + " elements)>"
