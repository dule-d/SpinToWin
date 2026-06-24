extends Node
class_name State
signal Transitioned(state: State, new_signal_name: String)

func enter():
	pass

func exit():
	pass

func process(delta: float) -> void:
	pass

func physics_process(delta: float) -> void:
	pass
