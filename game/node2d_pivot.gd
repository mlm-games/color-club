class_name Node2DPivot
extends RefCounted

## Helpers for scaling/rotating a Node2D around a point of its own
## artwork (instead of its transform origin), so animated elements
## stay centered while they pulse, wiggle, or spin.


## Returns the bounding-box center of a Polygon2D/Line2D's points,
## expressed in the node's own local space. Falls back to Vector2.ZERO.
static func shape_local_center(node: Node2D) -> Vector2:
	var points: PackedVector2Array

	if node is Polygon2D:
		points = node.polygon
	elif node is Line2D:
		points = node.points

	if points.is_empty():
		return Vector2.ZERO

	var min_point := points[0]
	var max_point := points[0]

	for point in points:
		min_point = min_point.min(point)
		max_point = max_point.max(point)

	return (min_point + max_point) * 0.5


## Sets node.transform so that scaling/rotating happens visually
## around `center` (a point in the node's own local space at rest),
## while the node's rest transform is preserved as the baseline.
static func apply_motion(
		node: Node2D,
		rest: Transform2D,
		center: Vector2,
		scale_factor: Vector2,
		rotation_rad: float
) -> void:
	var pivot := rest * center
	var motion := Transform2D(rotation_rad, scale_factor, 0.0, pivot)
	var inv_pivot := Transform2D(0.0, Vector2.ONE, 0.0, -pivot)

	node.transform = motion * inv_pivot * rest


## Appends an interpolation of scale/rotation around `center` to an
## existing Tween. `target_scale` and `target_rotation` are relative to
## the node's rest state; the node always ends exactly back on it when
## both targets are neutral (ONE / 0.0).
static func tween_around(
		tween: Tween,
		node: Node2D,
		center: Vector2,
		target_scale: Vector2 = Vector2.ONE,
		target_rotation: float = 0.0,
		duration: float = 0.2,
		trans: int = Tween.TRANS_SINE,
		ease_type: int = Tween.EASE_IN_OUT
) -> void:
	var rest := node.transform

	var stepper := tween.tween_method(
		func(weight: float) -> void:
			apply_motion(
				node,
				rest,
				center,
				Vector2.ONE.lerp(target_scale, weight),
				target_rotation * weight
			),
		0.0,
		1.0,
		duration
	)

	stepper.set_trans(trans)
	stepper.set_ease(ease_type)

	# The tween's last frame may stop a hair short of weight 1.0;
	# snap the node onto the exact target state when the step ends.
	tween.tween_callback(
		func() -> void:
			apply_motion(node, rest, center, target_scale, target_rotation)
	)
