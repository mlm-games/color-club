extends Node

static var tree : SceneTree = Engine.get_main_loop()


static func find_nodes_by_type(start_node: Node, types: Array) -> Array:
	var results: Array
	if not is_instance_valid(start_node):
		return results
	
	for type in types:
		if start_node.is_class(type):
			results.append(start_node)
			break
	
	for child in start_node.get_children():
		results.append_array(find_nodes_by_type(child, types))
	
	return results
	
static func find_nodes_with_script(start_node: Node, script_path: String) -> Array:
	var results: Array
	if not is_instance_valid(start_node):
		return results
		
	if is_instance_valid(start_node.get_script()) and start_node.get_script().resource_path == script_path:
		results.append(start_node)
	
	for child in start_node.get_children():
		results.append_array(find_nodes_with_script(child, script_path))
		
	return results

static func get_last_point(points: PackedVector2Array):
	return points.get(points.size() - 1)
