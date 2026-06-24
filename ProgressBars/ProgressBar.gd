extends CanvasLayer

@onready var stamina_bar: TextureProgressBar = %StaminaBar
@onready var stress_bar: ProgressBar = %Stress
@onready var stress_icon: TextureRect = %StressIcon

# Reference the parent control container that holds your UI elements
@onready var ui_pivot: Control = $UIPivot

@export var stress_textures: Array[Texture2D] = []

const PHASE_COLORS: Array[Color] = [
	Color(0.2,  0.85, 0.2),   # 0 — calm:    green
	Color(0.95, 0.85, 0.1),   # 1 — uneasy:  yellow
	Color(1.0,  0.50, 0.05),  # 2 — stressed: orange
	Color(0.90, 0.10, 0.10),  # 3 — max:      red
]

# Shake configuration variables
@export var shake_intensity: float = 8.0  # How far the UI can jump in pixels

var _current_phase: int = -1
var _is_shaking: bool = false
var _original_ui_position: Vector2


func _ready() -> void:
	# Save where the UI naturally sits so we can return to it exactly
	_original_ui_position = ui_pivot.position
	call_deferred("_connect_player")


func _physics_process(_delta: float) -> void:
	if _is_shaking:
		# Generate a completely random offset within our intensity range
		var random_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		ui_pivot.position = _original_ui_position + random_offset


func _connect_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.stamina_changed.connect(_on_stamina_changed)
		player.stress_changed.connect(_on_stress_changed)
	else:
		push_warning("HUD: no node found in group 'player'")


func _on_stamina_changed(current: float, max_value: float) -> void:
	stamina_bar.max_value = max_value
	stamina_bar.value     = current


func _on_stress_changed(current: float, max_value: float, phase: int) -> void:
	stress_bar.max_value = max_value
	stress_bar.value     = current

	if phase != _current_phase:
		_current_phase = phase
		_set_stress_colour(PHASE_COLORS[phase])
		_update_stress_icon(phase)
		_handle_ui_effects(phase)


func _set_stress_colour(color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	stress_bar.add_theme_stylebox_override("fill", style)


func _update_stress_icon(phase: int) -> void:
	if phase >= 0 and phase < stress_textures.size():
		if stress_textures[phase]:
			stress_icon.texture = stress_textures[phase]


# Monitors the phase to handle turning the shake loop on or off
func _handle_ui_effects(phase: int) -> void:
	if phase == 3:
		_is_shaking = true
	else:
		_is_shaking = false
		# Snap the UI immediately back to its original stable position
		ui_pivot.position = _original_ui_position
