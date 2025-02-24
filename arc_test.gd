class_name ArcTest extends Node2D

@export var point1 : Vector2 = Vector2(0, 0)
@export_range(1, 1000) var segments : int = 100
@export var width : int = 10
@export var color : Color = Color.GREEN
@export var antialiasing : bool = false

var _point2 : Vector2

func _draw() -> void:
	# Calculate the arc parameters.
	var center : Vector2 = Vector2((_point2.x - point1.x) / 2,
								   (_point2.y - point1.y) / 2)
	var radius : float = point1.distance_to(_point2) / 2
	var start_angle : float = (_point2 - point1).angle()
	var end_angle : float = (point1 - _point2).angle()
	if end_angle < 0:  # end_angle is likely negative, normalize it.
		end_angle += TAU

	# Finally, draw the arc.
	draw_arc(center, radius, start_angle, end_angle, segments, color,
			 width, antialiasing)
