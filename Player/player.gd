extends CharacterBody3D
class_name Player
# MOVEMENT
var speed
const WALK_SPEED = 3.0
const CROUCH_SPEED = 1.2
const SPRINT_SPEED = 5.0
const JUMP_VELOCITY = 3.2
const SENSITIVITY = 0.0019


# CROUCH
var crouch_height = 1.0
var stand_height = 2.0
var crouching = false


# HEAD BOB
const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob = 0.0


# FOV
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

var gravity = 9.8


# STAMINA
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 18.0        # per second while sprinting
@export var stamina_regen_rate: float = 12.0         # per second while not sprinting
@export var stamina_regen_delay: float = 1.0         # seconds after sprinting stops before regen starts
@export var out_of_breath_recovery_pct: float = 0.3  # stamina must refill to this % before you can sprint again

var stamina: float = max_stamina
var out_of_breath: bool = false
var _stamina_regen_timer: float = 0.0

signal stamina_changed(current: float, max_value: float)


# STRESS (4 phases: 0 = calm ... 3 = max / "going crazy")
@export var max_stress: float = 100.0
@export var stress_gain_rate: float = 30.0
@export var stress_decay_rate: float = 1.5
# DEBUG: no enemy yet, so this cycles stress up and down automatically
# so you can preview all 4 UI phases. Set to false once your enemy
# starts calling set_being_seen() on the player.
@export var debug_auto_stress: bool = true
@export var debug_cycle_seconds: float = 20.0
var _debug_time: float = 0.0

var stress: float = 0.0
var stress_phase: int = 0
var _being_seen: bool = false

signal stress_changed(current: float, max_value: float, phase: int)
signal stress_phase_entered(phase: int)


# CAMERA CHAOS at max stress phase

const SHAKE_STRENGTH = 0.04  # meters of jitter at phase 3


#health system
@onready var health_label: Label = $HealthComponent/Health
@onready var health_component: Node = $HealthComponent




# NODES
@onready var head = $head
@onready var camera = $head/Camera3D
@onready var flashlight = $head/Camera3D/SpotLight3D
@onready var ray_cast_3d: RayCast3D = $head/Camera3D/RayCast3D

# Add these 3 nodes to the Player scene (see notes at the bottom of the chat reply):
@onready var footstep_player: AudioStreamPlayer3D = $SoundEffects/FootstepPlayer
@onready var tired_player: AudioStreamPlayer = $SoundEffects/TiredPlayer
@onready var breathing_player: AudioStreamPlayer = $SoundEffects/BreathingPlayer

signal interact_object
var pickedObject

# footstep timing
var _footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL_WALK = 0.55
const FOOTSTEP_INTERVAL_SPRINT = 0.35
const FOOTSTEP_INTERVAL_CROUCH = 0.8


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("player")


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(60))


func _process(delta: float) -> void:
	health_label.text = str(health_component.health)
	
	if ray_cast_3d.is_colliding():
		var collider = ray_cast_3d.get_collider()
		interact_object.emit(collider)
	else:
		interact_object.emit(null)

	_update_stress(delta)
	_update_max_stress_effects(delta)


func _physics_process(delta):
	_update_crouch_and_speed()

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)

	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)

	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	_update_stamina(delta, input_dir)
	_update_footsteps(delta, input_dir)

	move_and_slide()


func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos


func _input(event):
	if event.is_action_pressed("F"):
		flashlight.visible = !flashlight.visible

	if event.is_action_pressed("E"):
		if pickedObject:
			var obj = pickedObject
			%CarryObjectMarker.remove_child(obj)
			get_tree().current_scene.add_child(obj)
			obj.global_transform.origin = %CarryObjectMarker.global_position
			obj.velocity = Vector3.ZERO
			obj.set_held(false)
			obj.set_physics_process(true)
			pickedObject = null
		elif ray_cast_3d.is_colliding():
			var collider = ray_cast_3d.get_collider()
			if collider and collider.is_in_group("pickable"):
				pick_up_object(collider)


func pick_up_object(object):
	if object.get_parent():
		object.get_parent().remove_child(object)
	object.get_node("%CollisionShape3D").disabled = true
	%CarryObjectMarker.add_child(object)
	object.position = Vector3.ZERO
	object.rotation = Vector3.ZERO
	object.velocity = Vector3.ZERO
	object.set_physics_process(false)
	object.set_held(true)
	pickedObject = object



# CROUCH 
func _update_crouch_and_speed():
	if Input.is_action_just_pressed("ctrl"):
		crouching = !crouching
		$CollisionShape3D.shape.height = crouch_height if crouching else stand_height

	if crouching:
		speed = CROUCH_SPEED
	elif Input.is_action_pressed("sprint") and not out_of_breath:
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED


# STAMINA
func _update_stamina(delta, input_dir):
	var is_sprinting = (
		Input.is_action_pressed("sprint")
		and not crouching
		and input_dir.length() > 0.1
		and not out_of_breath
	)

	if is_sprinting and stamina > 0:
		stamina -= stamina_drain_rate * delta
		_stamina_regen_timer = stamina_regen_delay
		if stamina <= 0:
			stamina = 0
			out_of_breath = true
			tired_player.play()
	else:
		if _stamina_regen_timer > 0:
			_stamina_regen_timer -= delta
		else:
			stamina = min(stamina + stamina_regen_rate * delta, max_stamina)
			if stamina >= max_stamina * out_of_breath_recovery_pct:
				out_of_breath = false

	stamina_changed.emit(stamina, max_stamina)



# FOOTSTEPS
func _update_footsteps(delta, input_dir):
	var moving = is_on_floor() and input_dir.length() > 0.1 and velocity.length() > 0.1
	if not moving:
		_footstep_timer = 0.0
		return

	var interval: float
	if crouching:
		interval = FOOTSTEP_INTERVAL_CROUCH
		footstep_player.volume_db = -40.0  # quieter
		footstep_player.pitch_scale = 0.85  # softer thud
	elif Input.is_action_pressed("sprint") and not out_of_breath:
		interval = FOOTSTEP_INTERVAL_SPRINT
		footstep_player.volume_db = -25.0    # slightly louder
		footstep_player.pitch_scale = 1.15  # higher urgency
	else:
		interval = FOOTSTEP_INTERVAL_WALK
		footstep_player.volume_db = -30.0
		footstep_player.pitch_scale = 1.0

	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		footstep_player.play()
		_footstep_timer = interval


# STRESS
# Call this from your enemy's vision check once it exists:
#   player.set_being_seen(true)   /   player.set_being_seen(false)
func set_being_seen(seen: bool):
	_being_seen = seen


func add_stress(amount: float):
	stress = clamp(stress + amount, 0.0, max_stress)


func _update_stress(delta):
	if debug_auto_stress:
		# smoothly cycles 0 -> max -> 0 so you can preview all 4 phases
		# without an enemy. Turn off once you wire up set_being_seen().
		_debug_time += delta
		stress = (sin(_debug_time * TAU / debug_cycle_seconds) * 0.5 + 0.5) * max_stress
	elif _being_seen:
		stress = clamp(stress + stress_gain_rate * delta, 0.0, max_stress)
	else:
		stress = clamp(stress - stress_decay_rate * delta, 0.0, max_stress)

	var new_phase = _phase_for_stress(stress)
	if new_phase != stress_phase:
		stress_phase = new_phase
		stress_phase_entered.emit(stress_phase)

	stress_changed.emit(stress, max_stress, stress_phase)


func _phase_for_stress(value: float) -> int:
	var pct = value / max_stress
	if pct < 0.25:
		return 0
	elif pct < 0.5:
		return 1
	elif pct < 0.75:
		return 2
	else:
		return 3



func _update_max_stress_effects(delta):
	if stress_phase == 3:
		var shake = Vector3(
			randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH),
			randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH),
			0.0
		)
		camera.position = _headbob(t_bob) + shake

		if not breathing_player.playing:
			breathing_player.play()
	else:
		# Smoothly un-roll z if it was ever set (safety reset)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, delta * 5.0)
		camera.position = _headbob(t_bob)

		if breathing_player.playing:
			breathing_player.stop()	


func on_death() -> void:
	get_tree().quit()
