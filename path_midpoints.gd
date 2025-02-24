class_name SVGPathPoints
extends RefCounted




signal pointHoveredChanged()
signal pointSelectedChanged()
signal pointChanged()

var layer#: PopUp

enum HandlesType{
	NONE, 
	MIRRORED, 
	MIRRORED_ANGLE, 
	INDEPENDENT, 
}

var handles_type: HandlesType:
	set(new_type):
		if (new_type != handles_type):
			if (layer):

				layer.generatorNode.store_point_undo_operation(self, "handles_type")

			handles_type = new_type
			adjust_handles_with_new_handle_type()
			pointChanged.emit()

var position: Vector2:
	set(new_point):
		if (new_point != position):
			if (layer):

				layer.generatorNode.store_point_undo_operation(self, "position")
			position = new_point
			pointChanged.emit()

var is_selected: bool:
	set(new_state):
		if (new_state != is_selected):
			is_selected = new_state
			pointSelectedChanged.emit()

var is_hovered: bool:
	set(new_state):
		if (new_state != is_hovered):
			is_hovered = new_state
			pointHoveredChanged.emit()

var is_pressed: bool:
	set(new_state):
		if (new_state != is_pressed):
			is_pressed = new_state
			pointHoveredChanged.emit()


var hovered_handle_index: int = 0


var handle_offset1: Vector2:
	set(new_point):
		if (new_point != handle_offset1):
			if (layer):

				layer.generatorNode.store_point_undo_operation(self, "handle_offset1")
			handle_offset1 = new_point
			update_handle2_contraint()

			if (handles_type != HandlesType.NONE):
				pointChanged.emit()
	get:
		if (handles_type != HandlesType.NONE):
			return handle_offset1
		else:
			return Vector2.ZERO

var handle_offset2: Vector2:
	set(new_point):
		if (new_point != handle_offset2):
			if (layer):

				layer.generatorNode.store_point_undo_operation(self, "handle_offset2")
			handle_offset2 = new_point
			update_handle1_contraint()

			if (handles_type != HandlesType.NONE):
				pointChanged.emit()
	get:
		if (handles_type != HandlesType.NONE):
			return handle_offset2
		else:
			return Vector2.ZERO


var handle_offset1_angle: float:
	get:
		if (handle_offset1.length()):
			handle_offset1_angle = handle_offset1.angle()
		return handle_offset1_angle

var handle_offset2_angle: float:
	get:
		if (handle_offset2.length()):
			handle_offset2_angle = handle_offset2.angle()
		return handle_offset2_angle


func update_handle1_contraint() -> void :
	if (handles_type == HandlesType.MIRRORED):
		handle_offset1 = handle_offset2 * -1
	if (handles_type == HandlesType.MIRRORED_ANGLE):
		if (handle_offset1.length()):
			var angle: float = handle_offset2_angle
			handle_offset1 = Vector2(cos(angle + PI) * handle_offset1.length(), sin(angle + PI) * handle_offset1.length())


func update_handle2_contraint() -> void :
	if (handles_type == HandlesType.MIRRORED):
		handle_offset2 = handle_offset1 * -1
	if (handles_type == HandlesType.MIRRORED_ANGLE):
		if (handle_offset2.length()):
			var angle: float = handle_offset1_angle
			handle_offset2 = Vector2(cos(angle + PI) * handle_offset2.length(), sin(angle + PI) * handle_offset2.length())



var previous_point: SVGPathPoints = null:
	set(new_point):
		if (new_point != previous_point):




			previous_point = new_point


			if (previous_point):
				previous_point.next_point = self

var next_point: SVGPathPoints = null:
	set(new_point):
		if (new_point != next_point):




			next_point = new_point


			if (next_point):
				next_point.previous_point = self




func _init(a_position: Vector2, a_handle_offset1: Vector2 = Vector2.ZERO, a_handle_offset2: Vector2 = Vector2.ZERO) -> void :
	position = a_position

	handle_offset1 = a_handle_offset1
	handle_offset2 = a_handle_offset2


	if (handle_offset1 == Vector2.ZERO && handle_offset2 == Vector2.ZERO):

		handles_type = HandlesType.NONE
	elif (is_equal_approx(handle_offset1.length(), handle_offset2.length()) && is_equal_approx(handle_offset1.angle_to(handle_offset2), PI)):
		handles_type = HandlesType.MIRRORED
	elif (is_equal_approx(handle_offset1.angle_to(handle_offset2), PI)):
		handles_type = HandlesType.MIRRORED_ANGLE
	else:
		handles_type = HandlesType.INDEPENDENT




func set_handle1_length(new_length: float) -> void :
	handle_offset1 = Vector2(cos(handle_offset1_angle) * new_length, sin(handle_offset1_angle) * new_length)

func set_handle2_length(new_length: float) -> void :
	handle_offset2 = Vector2(cos(handle_offset2_angle) * new_length, sin(handle_offset2_angle) * new_length)



func adjust_handles_with_new_handle_type() -> void :
	if (handles_type != HandlesType.NONE):
		if (handle_offset1.length() == 0 && handle_offset2.length() == 0):
			var angle: float = 0
			var angle_dist: float = 0
			var point_angle: float
			var length: float = 10

			if (handles_type == HandlesType.MIRRORED || handles_type == HandlesType.MIRRORED_ANGLE):

				if (next_point):
					point_angle = position.angle_to_point(next_point.position)
					angle = position.angle_to_point(next_point.position)
					length = position.distance_to(next_point.position) / 2
					if (previous_point):
						point_angle = previous_point.position.angle_to_point(position)
						angle = (angle + point_angle) / 2
						length = (length + (position.distance_to(previous_point.position) / 2)) / 2
				elif (previous_point):
					angle = (previous_point.position.angle_to_point(position))
					length = (position.distance_to(previous_point.position) / 2)

				if (next_point):
					angle_dist = angle_difference(angle, position.angle_to_point(next_point.position))

					if (absf(angle_dist) > PI / 2):

						angle = angle + PI


				if (handles_type == HandlesType.MIRRORED_ANGLE):

					set_handle1_length(length)
				handle_offset2 = Vector2(cos(angle) * length, sin(angle) * length)
			else:

				angle = PI
				if (previous_point):
					angle = position.angle_to_point(previous_point.position)
					length = position.distance_to(previous_point.position) / 2
				handle_offset1 = Vector2(cos(angle) * length, sin(angle) * length)
				angle = 0
				if (next_point):
					angle = position.angle_to_point(next_point.position)
					length = position.distance_to(next_point.position) / 2
				handle_offset2 = Vector2(cos(angle) * length, sin(angle) * length)

		else:

			if (handle_offset2.length()):
				update_handle1_contraint()
			else:
				update_handle2_contraint()







func draw_handle(canvas: CanvasItem, zoomIndependentScale: float, transformed_position: Vector2, transformed_handle_position: Vector2, handle_hovered: bool, handle_pressed: bool) -> void :
	var width: float = 1.0 * zoomIndependentScale

	canvas.draw_line(transformed_position, transformed_handle_position, Color.WHITE, width * 0.5, true)

	var mark_size: float = 5.0 * zoomIndependentScale


	var fillColor: Color = Color.WHITE
	if (handle_pressed):
		fillColor = Color.WHITE.lightened(0.2)
	elif (handle_hovered):
		fillColor = Color.WHITE.lightened(0.7)

	canvas.draw_circle(transformed_handle_position, mark_size * 0.5, fillColor, true)



	canvas.draw_circle(transformed_handle_position, mark_size * 0.5, Color.WHITE, false, width * 0.5, true)



func should_show_handle1() -> bool:
	if (handles_type != HandlesType.NONE):
		if (is_selected):
			return true
		elif (previous_point):
			if (previous_point.is_selected):
				return true
	return false

func should_show_handle2() -> bool:
	if (handles_type != HandlesType.NONE):
		if (is_selected):
			return true
		elif (next_point):
			if (next_point.is_selected):
				return true
	return false


func draw(canvas: CanvasItem, zoomIndependentScale: float, point_transform: Transform2D) -> void :

	var mark_size: float = 7.0 * zoomIndependentScale


	var width: float = 1.0 * zoomIndependentScale


	var transformed_position: Vector2 = point_transform * position


	if (should_show_handle1()):
		var transformed_handle1_position: Vector2 = point_transform * (position + handle_offset1)
		draw_handle(canvas, zoomIndependentScale, transformed_position, transformed_handle1_position, hovered_handle_index == 1 && is_hovered, hovered_handle_index == 1 && is_pressed)
	if (should_show_handle2()):
		var transformed_handle2_position: Vector2 = point_transform * (position + handle_offset2)
		draw_handle(canvas, zoomIndependentScale, transformed_position, transformed_handle2_position, hovered_handle_index == 2 && is_hovered, hovered_handle_index == 2 && is_pressed)


	var fillColor: Color = Color.WHITE
	if (is_selected):
		fillColor = Color.WHITE
	elif (is_hovered && hovered_handle_index == 0):
		fillColor = Color.WHITE.lightened(0.7)

	canvas.draw_circle(transformed_position, mark_size * 0.5, fillColor, true)

	canvas.draw_circle(transformed_position, mark_size * 0.5, Color.WHITE, false, width * 0.5, true)







const hit_radius = 7
