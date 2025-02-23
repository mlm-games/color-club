class_name SVGPathElement
extends SVGElementBase

var path_data: String
var parsed_commands: Array[SVGPathCommand] = []

func _init(path_data: String) -> void:
	super._init("path")
	self.path_data = path_data
	parse_path_data()

func parse_path_data() -> void:
	var parser := SVGPathParser.new()
	parsed_commands = parser.parse(path_data)

func calculate_bounds(include_stroke: bool) -> Rect2:
	var bounds := Rect2()
	var current_pos := Vector2.ZERO
	
	for command in parsed_commands:
		match command.type:
			"M", "L":
				bounds = bounds.expand(command.points[0])
				current_pos = command.points[0]
			"C":
				var curve_bounds = _get_cubic_bezier_bounds(
					current_pos,
					command.points[0],
					command.points[1],
					command.points[2]
				)
				bounds = bounds.merge(curve_bounds)
				current_pos = command.points[2]
	
	if include_stroke:
		bounds = bounds.grow(stroke_width / 2.0)
	
	return bounds
