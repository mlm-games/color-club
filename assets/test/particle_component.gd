@tool
class_name ParticleComponent extends Node2D

@export_tool_button("Emit particles", "ParticleProcessMaterial") var p = emit_selection_particles.bind(modulate, position)


#var particles: Array = []

func emit_selection_particles(color: Color, pos: Vector2 = position) -> void:
	for i in range(10):
		var particle = Sprite2D.new()
		particle.texture = preload("res://assets/art/particles/star.svg")
		particle.modulate = color
		#particle.position = pos
		particle.scale = Vector2(0.5, 0.5)
		add_child(particle)
		
		var direction = Vector2.from_angle(randf() * TAU)
		var distance = randf_range(50, 100)
		
		var tween = particle.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(particle, "position", pos + direction * distance, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "scale", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.chain().tween_callback(particle.queue_free)
