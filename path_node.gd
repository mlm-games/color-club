class_name SVGPathRef
extends RefCounted

enum Type{
	MOVE_TO, 
	LINE_TO, 
	CLOSE_PATH, 
	CURVE_TO, 
}

var type: SVGPathRef.Type

var point: Vector2:
	set(new_point):
		point_x = new_point.x
		point_y = new_point.y
		print("set point vector used, use set point_x")
	get:
		return Vector2(point_x, point_y)
var point_x: float
var point_y: float


var control_point1: Vector2:
	set(new_point):
		control_point1_x = new_point.x
		control_point1_y = new_point.y
		print("set control_point1 vector used, use set point_x")
	get:
		return Vector2(control_point1_x, control_point1_y)
var control_point1_x: float
var control_point1_y: float

var control_point2: Vector2:
	set(new_point):
		control_point2_x = new_point.x
		control_point2_y = new_point.y
		print("set control_point2 vector used, use set point_x")
	get:
		return Vector2(control_point2_x, control_point2_y)
var control_point2_x: float
var control_point2_y: float


func _init(new_type: SVGPathRef.Type, point1_x: float = 0, point1_y: float = 0, point2_x: float = 0, point2_y: float = 0, point3_x: float = 0, point3_y: float = 0) -> void :
	type = new_type
	point_x = point1_x
	point_y = point1_y
	control_point1_x = point2_x
	control_point1_y = point2_y
	control_point2_x = point3_x
	control_point2_y = point3_y
