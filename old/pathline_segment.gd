class_name SVGPathlineSegments
extends RefCounted





var start: SVGPathRef
var end: SVGPathRef

var continuousAtEnd: bool = false
var closePathAtEnd: bool = false

var isCurve: bool:
	get:
		if (end):
			return end.type == SVGPathRef.Type.CURVE_TO
		else:
			return false



func _init(start_element: SVGPathRef, end_element: SVGPathRef) -> void :
	start = start_element
	end = end_element
	if ( !end || !start):
		push_error("init with invalid start or end element", self)





func findDotAtSegment(p1x: float, p1y: float, c1x: float, c1y: float, c2x: float, c2y: float, p2x: float, p2y: float, t: float) -> Vector2:
	var t1: float = 1.0 - t;
	return Vector2(t1 * t1 * t1 * p1x + t1 * t1 * 3 * t * c1x + t1 * 3 * t * t * c2x + t * t * t * p2x, 
				t1 * t1 * t1 * p1y + t1 * t1 * 3 * t * c1y + t1 * 3 * t * t * c2y + t * t * t * p2y)

func _curveBoundingBox() -> Rect2:
	var p1x: float = start.point.x
	var p1y: float = start.point.y
	var c1x: float = end.control_point1.x
	var c1y: float = end.control_point1.y
	var c2x: float = end.control_point2.x
	var c2y: float = end.control_point2.y
	var p2x: float = end.point.x
	var p2y: float = end.point.y


	var y_values: Array[float] = [p1y, p2y]
	var x_values: Array[float] = [p1x, p2x]


	var a: float = (c2x - 2.0 * c1x + p1x) - (p2x - 2.0 * c2x + c1x)
	var b: float = 2.0 * (c1x - p1x) - 2 * (c2x - c1x)
	var c: float = p1x - c1x
	var t1: float = (( - b + sqrt(b * b - 4 * a * c)) / 2.0) / a
	var t2: float = (( - b - sqrt(b * b - 4 * a * c)) / 2.0) / a

	var dot: Vector2




	if (t1 > 0 && t1 < 1):
		dot = findDotAtSegment(p1x, p1y, c1x, c1y, c2x, c2y, p2x, p2y, t1);
		x_values.append(dot.x)
		y_values.append(dot.y)


	if (t2 > 0 && t2 < 1):
		dot = findDotAtSegment(p1x, p1y, c1x, c1y, c2x, c2y, p2x, p2y, t2);
		x_values.append(dot.x);
		y_values.append(dot.y);




	a = (c2y - 2.0 * c1y + p1y) - (p2y - 2.0 * c2y + c1y)
	b = 2.0 * (c1y - p1y) - 2.0 * (c2y - c1y)
	c = p1y - c1y
	t1 = (( - b + sqrt(b * b - 4.0 * a * c)) / 2) / a
	t2 = (( - b - sqrt(b * b - 4.0 * a * c)) / 2) / a





	if (t1 > 0 && t1 < 1):
		dot = findDotAtSegment(p1x, p1y, c1x, c1y, c2x, c2y, p2x, p2y, t1);
		x_values.append(dot.x)
		y_values.append(dot.y)

	if (t2 > 0 && t2 < 1):
		dot = findDotAtSegment(p1x, p1y, c1x, c1y, c2x, c2y, p2x, p2y, t2);
		x_values.append(dot.x);
		y_values.append(dot.y);


	dot = findDotAtSegment(p1x, p1y, c1x, c1y, c2x, c2y, p2x, p2y, 0.5);
	x_values.append(dot.x);
	y_values.append(dot.y);



	var min_point: Vector2 = Vector2(1000000, 1000000)
	var max_point: Vector2 = Vector2(-1000000, -1000000)

	for x: float in x_values:
		if (x < min_point.x):
			min_point.x = x
		if (x > max_point.x):
			max_point.x = x
	for y: float in y_values:
		if (y < min_point.y):
			min_point.y = y
		if (y > max_point.y):
			max_point.y = y


	return Rect2(min_point, max_point - min_point)




func boundingBox() -> Rect2:
	if ( !isCurve):

		var minPoint: Vector2 = Vector2(min(start.point.x, end.point.x), min(start.point.y, end.point.y))
		var maxPoint: Vector2 = Vector2(max(start.point.x, end.point.x), max(start.point.y, end.point.y))
		return Rect2(minPoint, maxPoint - minPoint)
	else:

		return _curveBoundingBox()






func lineToPointDistance(line_start: Vector2, line_end: Vector2, point: Vector2) -> float:

	var AB: Vector2 = line_end - line_start
	var BE: Vector2 = point - line_end
	var AE: Vector2 = point - line_start

	var AB_BE: float = AB.dot(BE)
	var AB_AE: float = AB.dot(AE)

	var minDist: float = 0
	var x: float
	var y: float

	if (AB_BE > 0):

		y = point.y - line_end.y
		x = point.x - line_end.x
		minDist = sqrt(x * x + y * y)

	elif (AB_AE < 0):
		y = point.y - line_start.y
		x = point.x - line_start.x
		minDist = sqrt(x * x + y * y)

	else:

		var x1: float = AB.x
		var y1: float = AB.y
		var x2: float = AE.x
		var y2: float = AE.y
		var mod: float = sqrt(x1 * x1 + y1 * y1)
		minDist = absf(x1 * y2 - y1 * x2) / mod

	return minDist


func distanceToPoint(point: Vector2) -> float:

	var distance: float = 99999999
	if (isCurve):
		var segmentDistance: float

		if (curvePoints.size()):
			var previousPoint: Vector2 = curvePoints[0]
			for segmentPoint: Vector2 in curvePoints:
				if (segmentPoint != previousPoint):
					segmentDistance = lineToPointDistance(previousPoint, segmentPoint, point)
					if (segmentDistance < distance):
						distance = segmentDistance
				previousPoint = segmentPoint

	else:

		distance = lineToPointDistance(start.point, end.point, point)

	return distance










static func point_set_orientation(p: Vector2, q: Vector2, r: Vector2) -> int:



	var val: float = ((q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y))
	if (is_zero_approx(val)):
		return 0
	if (val > 0):
		return 1
	return 2



static func point_on_segment(p: Vector2, q: Vector2, r: Vector2) -> bool:
	if (q.x <= max(p.x, r.x) && q.x >= min(p.x, r.x) && q.y <= max(p.y, r.y) && q.y >= min(p.y, r.y)):
		return true
	return false


static func lines_intersect(p1: Vector2, q1: Vector2, p2: Vector2, q2: Vector2) -> bool:


	var o1: int = point_set_orientation(p1, q1, p2)
	var o2: int = point_set_orientation(p1, q1, q2)
	var o3: int = point_set_orientation(p2, q2, p1)
	var o4: int = point_set_orientation(p2, q2, q1)


	if (o1 != o2 && o3 != o4):

		return true



	if (o1 == 0 && point_on_segment(p1, p2, q1)): return true

	if (o2 == 0 && point_on_segment(p1, q2, q1)): return true

	if (o3 == 0 && point_on_segment(p2, p1, q2)): return true

	if (o4 == 0 && point_on_segment(p2, q1, q2)): return true


	return false






func lineIntersections(p1: Vector2, q1: Vector2) -> int:
	var intersect_count: int = 0
	if (start && end):
		if (isCurve):
			var index: int = 0

			while index < (curvePoints.size() - 1):
				if (lines_intersect(p1, q1, curvePoints[index], curvePoints[index + 1])):



					intersect_count = intersect_count + 1
				index = index + 1
		else:
			if (lines_intersect(p1, q1, start.point, end.point)):
				intersect_count = 1



	return intersect_count




func lineIntersectionsWindingNumber(p1: Vector2, q1: Vector2) -> int:
	var winding_number: int = 0
	if (start && end):
		if (isCurve):
			var index: int = 0

			while index < (curvePoints.size() - 1):
				if (lines_intersect(p1, q1, curvePoints[index], curvePoints[index + 1])):
					if (curvePoints[index].y > curvePoints[index + 1].y):
						winding_number = winding_number - 1
					else:
						winding_number = winding_number + 1

				index = index + 1
		else:
			if (lines_intersect(p1, q1, start.point, end.point)):

				if (start.point.y > end.point.y):
					winding_number = winding_number - 1
				else:
					winding_number = winding_number + 1



	return winding_number



var desiredCurvePointScale: float = 1
var curvePointScale: float = -1

var curvePoints: Array[Vector2]:
	get:
		var scaleQuote: float = curvePointScale / desiredCurvePointScale
		if (scaleQuote > 1.4 || scaleQuote < 0.9):


			curvePoints = generateCurvePoints()


			curvePointScale = desiredCurvePointScale

		return curvePoints


func generateCurvePoints(segment_length: float = 5) -> Array[Vector2]:

	var newCurvePoints: Array[Vector2] = []


	segment_length = segment_length / desiredCurvePointScale


	var length: float = segmentLength()
	var points: float = ceil(length / segment_length)
	if (points < 2): points = 2
	var index: float = 0


	while index <= points:
		newCurvePoints.append(curveFunctionPointOnSegment(index / points))
		index = index + 1

	return newCurvePoints


func curveFunctionPointOnSegment(t: float) -> Vector2:
	return Vector2(_cubicCurveFunction(t, start.point.x, end.control_point1.x, end.control_point2.x, end.point.x), _cubicCurveFunction(t, start.point.y, end.control_point1.y, end.control_point2.y, end.point.y))


func relativePointOnSegment(t: float) -> Vector2:
	if (start && end):
		if (isCurve):
			return _cubicCurvePoint(t, start.point, end.control_point1, end.control_point2, end.point)

	return start.point + t * (end.point - start.point)


var cached_last_search_start_index: int = 0
var cached_last_search_start_length: float = 0


func angleAlongSegment(target_length: float) -> float:
	if ( !cached_length):

		segmentLength()

	if (cached_length > 0):

		if ( !isCurve):

			return (end.point - start.point).angle()
		else:
			var angle: float

			if (absf(target_length) < 0.001):
				angle = (end.control_point1 - start.point).angle()
				if (start.point == end.control_point1):
					angle = (end.control_point2 - start.point).angle()
				return angle
			elif (absf(target_length - cached_length) < 0.001):
				angle = (end.point - end.control_point2).angle()
				if (end.point == end.control_point2):
					angle = (end.point - end.control_point1).angle()
				return angle


			var bezier_points: Array[Vector2] = SVGPathlineSegments.trimmed_bezier_curve(start.point, end.control_point1, end.control_point2, end.point, target_length / cached_length)
			return (bezier_points[3] - bezier_points[2]).angle()


	return 0




func pointAlongSegment(target_length: float) -> Vector2:
	if ( !cached_length):

		segmentLength()

	if (cached_length > 0 && target_length > 0):

		if ( !isCurve):

			var lineVector: Vector2 = (end.point - start.point).normalized()
			return start.point + lineVector * target_length

		var index: int = 0
		if (target_length > cached_last_search_start_length):



			index = cached_last_search_start_index

		var found_index_after: int = 0

		while index < cached_segment_point_total_lengths.size():
			if (cached_segment_point_total_lengths[index] > target_length):
				found_index_after = index
				break
			index = index + 1

		if (found_index_after > 0):


			var found_start_length: float = cached_segment_point_total_lengths[found_index_after - 1]
			var found_end_length: float = cached_segment_point_total_lengths[found_index_after]


			cached_last_search_start_index = found_index_after - 1
			cached_last_search_start_length = found_start_length

			var span_relative_position: float = (target_length - found_start_length) / (found_end_length - found_start_length)



			return cached_segment_points[found_index_after - 1] + span_relative_position * (cached_segment_points[found_index_after] - cached_segment_points[found_index_after - 1])


		else:
			return end.point
	else:

		if (start):
			return start.point
		else:
			push_error("pointAlongSegment with no start", self)
			return Vector2(0, 0)


var cached_length: float = 0
var cached_segment_points: Array[Vector2] = []
var cached_segment_point_total_lengths: Array[float] = []

func segmentLength() -> float:
	if (cached_length):
		return cached_length

	var length: float = 0

	if (isCurve):
		cached_segment_points = []
		cached_segment_point_total_lengths = []


		cached_segment_points.append(start.point)
		cached_segment_point_total_lengths.append(0)


		var segment_precision: float = 15
		var points: float = ceil((start.point.distance_to(end.control_point1) + end.point.distance_to(end.control_point2) + end.control_point1.distance_to(end.control_point2) * 0.2) / segment_precision)


		var index: float = 0

		var p1: Vector2 = start.point
		var p2: Vector2


		while index < points:



			p2 = curveFunctionPointOnSegment((index + 1.0) / points)

			length = length + (p1.distance_to(p2))


			cached_segment_points.append(p2)
			cached_segment_point_total_lengths.append(length)

			index = index + 1
			p1 = p2
	else:

		length = start.point.distance_to(end.point)


	cached_length = length
	return length



func _cubicCurvePoint(t: float, p0: Vector2, c1: Vector2, c2: Vector2, p1: Vector2) -> Vector2:
	return Vector2(_cubicCurveFunction(t, p0.x, c1.x, c2.x, p1.x), _cubicCurveFunction(t, p0.y, c1.y, c2.y, p1.y))


func _cubicCurveFunction(t: float, a: float, b: float, c: float, d: float) -> float:
	var t2: float = t * t
	var t3: float = t2 * t
	return a + ( - a * 3 + t * (3 * a - a * t)) * t + (3 * b + t * (-6 * b + b * 3 * t)) * t + (c * 3 - c * 3 * t) * t2 + d * t3














static func trimmed_bezier_curve(point1: Vector2, control_point1: Vector2, control_point2: Vector2, point2: Vector2, t: float) -> Array[Vector2]:
	var x1: float = point1.x
	var y1: float = point1.y
	var x2: float = control_point1.x
	var y2: float = control_point1.y
	var x3: float = control_point2.x
	var y3: float = control_point2.y
	var x4: float = point2.x
	var y4: float = point2.y

	var x12: float = (x2 - x1) * t + x1
	var y12: float = (y2 - y1) * t + y1

	var x23: float = (x3 - x2) * t + x2
	var y23: float = (y3 - y2) * t + y2

	var x34: float = (x4 - x3) * t + x3
	var y34: float = (y4 - y3) * t + y3

	var x123: float = (x23 - x12) * t + x12
	var y123: float = (y23 - y12) * t + y12

	var x234: float = (x34 - x23) * t + x23
	var y234: float = (y34 - y23) * t + y23

	var x1234: float = (x234 - x123) * t + x123
	var y1234: float = (y234 - y123) * t + y123

	return [Vector2(x1, y1), Vector2(x12, y12), Vector2(x123, y123), Vector2(x1234, y1234)]




func draw_stroke(canvas: CanvasItem, color: Color, stroke_width: float = 1, anti_alias: bool = false) -> void :
	if (start && end):
		if (isCurve):

			canvas.draw_polyline(PackedVector2Array(curvePoints), color, stroke_width, anti_alias)

		else:

			canvas.draw_line(start.point, end.point, color, stroke_width, anti_alias)





func _to_string() -> String:
	return "<SVGPathlineSegments #" + ("%X" % get_instance_id()).substr(5) + " (" + str(start) + " to " + str(end) + ")>"
