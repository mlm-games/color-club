class_name ThemeManager extends Node #  Add to Autoload.tscn

@export var main_theme: Theme = ProjectSettings.get_setting("gui/theme/custom")
@export var current_accent_color: Color = Color("#FF6B6B")

const COLOR_SCHEMES = {
	"default": {
		"primary": Color("#FF6B6B"),
		"secondary": Color("#4ECDC4"),
		"accent": Color("#FFE66D")
	},
	"ocean": {
		"primary": Color("#006BA6"),
		"secondary": Color("#0496FF"),
		"accent": Color("#FFD23F")
	},
	"forest": {
		"primary": Color("#2D6A4F"),
		"secondary": Color("#52B788"),
		"accent": Color("#D8F3DC")
	},
	"sunset": {
		"primary": Color("#F72585"),
		"secondary": Color("#7209B7"),
		"accent": Color("#F72585")
	}
}

func apply_color_scheme(scheme_name: String) -> void:
	if scheme_name in COLOR_SCHEMES:
		var scheme = COLOR_SCHEMES[scheme_name]
		
		var button_normal := main_theme.get_stylebox("normal", "Button")
		if button_normal:
			button_normal.bg_color = scheme["secondary"]
			
		var button_hover := main_theme.get_stylebox("hover", "Button")
		if button_hover:
			button_hover.bg_color = scheme["accent"]
			button_hover.border_color = scheme["primary"]
			
		var progress_fill := main_theme.get_stylebox("fill", "ProgressBar")
		if progress_fill:
			progress_fill.bg_color = scheme["secondary"]
			
		theme_changed.emit(scheme)

signal theme_changed(color_scheme: Dictionary)
