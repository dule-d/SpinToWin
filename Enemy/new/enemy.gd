extends CharacterBody3D

@export var WalkSpeed: float = 1.0
@export var RunSpeed: float = 2.0
@export var AttackReach: float = 2.0
@export var ChaseDistance: float = 15.0


@onready var health_component: Node = $HealthComponent
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D


var player: CharacterBody3D = null

func _ready() -> void:
	player = get_tree().get_nodes_in_group("player")[0]

func _physics_process(delta: float) -> void:
	move_and_slide()

func on_death() -> void:
	#queue_free() if i want it deleted
	pass
