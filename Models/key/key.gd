extends CharacterBody3D

@onready var key: Node3D = $key
@onready var OutlineMesh: MeshInstance3D = $key/group76944799/MeshInstance3D
@onready var glowMesh: MeshInstance3D = $key/Glow

@export var world_scale: Vector3 = Vector3(2.5, 2.5, 2.5)
@export var held_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var held_rotation_offset: Vector3 = Vector3.ZERO

@onready var collision_shape: CollisionShape3D = %CollisionShape3D

var gravity = 9.8
var selected = false
var outlineWidth = 0.01
var isHeld = false

var player


func _ready() -> void:
	add_to_group("pickable")
	player = get_tree().get_first_node_in_group("player")
	player.interact_object.connect(_set_selected)
	OutlineMesh.visible = false
	glowMesh.visible = true
	
	key.scale = world_scale
	collision_shape.scale = world_scale


func _set_selected(object):
	selected = self == object


func set_held(value: bool) -> void:
	isHeld = value
	if isHeld:
		key.scale = held_scale
		collision_shape.scale = held_scale
		key.rotation_degrees = held_rotation_offset
		glowMesh.visible = false
	else:
		key.scale = world_scale
		collision_shape.scale = world_scale
		glowMesh.visible = true

func _physics_process(delta: float) -> void:
	if isHeld:
		velocity = Vector3.ZERO
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()


func _process(delta: float) -> void:
	%CollisionShape3D.disabled = isHeld
	OutlineMesh.visible = selected and not isHeld
	
	if selected:
		key.position.y = outlineWidth
	else:
		key.position.y = 0
