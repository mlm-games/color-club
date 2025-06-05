class_name SVGPathParser
extends RefCounted

# Path command state
class PathState:
	var current_pos: Vector2 = Vector2.ZERO
	var subpath_start: Vector2 = Vector2.ZERO
	var last_control_point: Vector2 = Vector2.ZERO
	var last_command: String = ""

# Parse path data into a series of commands
static func parse_path_commands(path_data: String) -> Array:
	var commands = []
	var tokens = _tokenize_path(path_data)
	var i = 0
	
	while i < tokens.size():
		var cmd = tokens[i]
		i += 1
		
		var params = []
		while i < tokens.size() and _is_number(tokens[i]):
			params.append(float(tokens[i]))
			i += 1
		
		commands.append({
			"command": cmd,
			"params": params
		})
	
	return commands

static func _tokenize_path(data: String) -> Array[String]:
	var tokens: Array[String] = []
	var current_token = ""
	var in_number = false
	
	for i in range(data.length()):
		var chr = data[i]
		
		if chr in " ,\t\n\r":
			if not current_token.is_empty():
				tokens.append(current_token)
				current_token = ""
				in_number = false
		elif chr in "MmLlHhVvCcSsQqTtAaZz":
			if not current_token.is_empty():
				tokens.append(current_token)
			tokens.append(chr)
			current_token = ""
			in_number = false
		elif chr == "-" and in_number:
			# Start of new negative number
			tokens.append(current_token)
			current_token = "-"
		elif chr == "." and "." in current_token:
			# Start of new decimal number
			tokens.append(current_token)
			current_token = "."
		else:
			current_token += chr
			if chr in "0123456789.-":
				in_number = true
	
	if not current_token.is_empty():
		tokens.append(current_token)
	
	return tokens

static func _is_number(token: String) -> bool:
	if token.is_empty():
		return false
	
	# Handle negative numbers and decimals
	var has_decimal = false
	var has_digit = false
	
	for i in range(token.length()):
		var chr = token[i]
		if chr == "-":
			if i != 0:
				return false
		elif chr == ".":
			if has_decimal:
				return false
			has_decimal = true
		elif chr in "0123456789":
			has_digit = true
		else:
			return false
	
	return has_digit
