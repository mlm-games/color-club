# Interactive Coloring Area
class_name ColoringArea
extends Area2D

signal area_clicked(area: Area2D)

var area_data: SVGColorExtractor.ColorArea
var current_color: Color = Color.WHITE
var mesh_instance: MeshInstance2D

func initialize(data: SVGColorExtractor.ColorArea) -> void:
	area_data = data
	#create_collision_shape()
	#create_fill_mesh()
	
	# Set initial color
	if area_data.fill_color != Color.TRANSPARENT:
		set_color(area_data.fill_color)

func create_collision_shape() -> void:
	var collision = CollisionPolygon2D.new()
	collision.polygon = SVGPathParser.path_to_points(area_data.path_data)
	add_child(collision)

func create_fill_mesh() -> void:
	mesh_instance = MeshInstance2D.new()
	mesh_instance.mesh = create_polygon_mesh(
		SVGPathParser.path_to_points(area_data.path_data)
	)
	add_child(mesh_instance)

func set_color(color: Color) -> void:
	current_color = color
	update_mesh_color()

func update_mesh_color() -> void:
	var material = ShaderMaterial.new()
	#FIXME: material.shader = preload("res://shaders/fill_color.gdshader")
	material.set_shader_parameter("fill_color", current_color)
	mesh_instance.material = material
