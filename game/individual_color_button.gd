@tool
extends Button

@onready var particle_component: ParticleComponent = $ParticleComponent

var target_color: Color:
	set(value):
		target_color = value
		set_meta("target_color", value) # Store for HUD to find
		modulate = value

func _ready() -> void:
	custom_minimum_size = Vector2(50, 50)
	
	pressed.connect(GlobalAudioExports.I.play_ui_sound.bind(GlobalAudioExports.Sound.Click))
	mouse_entered.connect(GlobalAudioExports.I.play_ui_sound.bind(GlobalAudioExports.Sound.Hover))
	
	#theme_type_variation = "LevelButton"

#func _process(delta: float) -> void:
	#particle_component.emit_selection_particles(modulate, position)
