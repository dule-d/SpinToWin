extends Node

@export var MaxHealth: float = 100.0

var health: float = MaxHealth

func damage(attack: Attack) -> void:
	health -= attack.damage

	var parent: Node3D = get_parent()
	if parent.has_method("on_damage"):
		parent.on_damage(attack)

	if health <= 0:
		parent.on_death()
