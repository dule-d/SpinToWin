extends CharacterBody3D

var speed
const WALK_SPEED = 3.0
const CROUCH_SPEED = 1.0
const SPRINT_SPEED = 5.0
const JUMP_VELOCITY = 3.2
const SENSITIVITY = 0.0019

#crouch
var crouch_height = 1.0
var stand_height = 2.0
var crouching = false

#bob variables
const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob = 0.0

#fov variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5


var gravity = 9.8

@onready var head = $head
@onready var camera = $head/Camera3D

@onready var flashlight = $head/Camera3D/SpotLight3D


@onready var ray_cast_3d: RayCast3D = $head/Camera3D/RayCast3D
signal interact_object
var pickedObject


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("player")


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		#print("mouse moved: ", event.relative)
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(60))


func _process(delta: float) -> void:
	if ray_cast_3d.is_colliding():
		var collider = ray_cast_3d.get_collider()
		interact_object.emit(collider)
	else: interact_object.emit(null)

func _physics_process(delta):
	#crouch
	crouch()
	
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Handle Sprint.
	if Input.is_action_just_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED
		
	
		

	# Get the input direction and handle the movement/deceleration.
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
	
	# Head bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
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
	
	
func crouch():
	if Input.is_action_just_pressed("ctrl"):
		crouching = !crouching
		if crouching:
			$CollisionShape3D.shape.height = crouch_height
			speed = CROUCH_SPEED
		else:
			$CollisionShape3D.shape.height = stand_height
			speed = WALK_SPEED
