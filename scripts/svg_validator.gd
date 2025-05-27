@tool
class_name SVGValidator
extends RefCounted

# Validation results
class ValidationResult:
	var is_valid: bool = true
	var warnings: Array[String] = []
	var errors: Array[String] = []
	var unsupported_features: Array[String] = []

static func validate_svg_file(file_path: String) -> ValidationResult:
	var result = ValidationResult.new()
	
	if not FileAccess.file_exists(file_path):
		result.is_valid = false
		result.errors.append("SVG file does not exist: " + file_path)
		return result
	
	var parser = XMLParser.new()
	if parser.open(file_path) != OK:
		result.is_valid = false
		result.errors.append("Failed to parse SVG file: " + file_path)
		return result
	
	_validate_svg_content(parser, result)
	return result

static func _validate_svg_content(parser: XMLParser, result: ValidationResult) -> void:
	var svg_found = false
	var supported_elements = ["svg", "g", "rect", "circle", "ellipse", "path"]
	var partially_supported = ["line", "polyline", "polygon"]
	var unsupported_elements = ["text", "image", "use", "defs", "clipPath", "mask"]
	
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var tag_name = parser.get_node_name()
			
			if tag_name == "svg":
				svg_found = true
				_validate_svg_root(parser, result)
			elif tag_name in supported_elements:
				# Fully supported
				pass
			elif tag_name in partially_supported:
				result.warnings.append("Element '" + tag_name + "' has limited support")
			elif tag_name in unsupported_elements:
				result.unsupported_features.append("Element '" + tag_name + "' is not supported")
			else:
				result.warnings.append("Unknown SVG element: " + tag_name)
	
	if not svg_found:
		result.is_valid = false
		result.errors.append("No <svg> root element found")

static func _validate_svg_root(parser: XMLParser, result: ValidationResult) -> void:
	var has_dimensions = false
	
	for i in range(parser.get_attribute_count()):
		var attr_name = parser.get_attribute_name(i)
		match attr_name:
			"width", "height", "viewBox":
				has_dimensions = true
			"xmlns":
				# Good practice but not required
				pass
			_:
				# Other attributes are fine
				pass
	
	if not has_dimensions:
		result.warnings.append("SVG lacks explicit dimensions (width, height, or viewBox)")
