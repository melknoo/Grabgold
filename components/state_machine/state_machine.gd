class_name StateMachine
extends Node
## Erwartet: direktes Kind von Player oder Enemy; States sind direkte Kinder dieser Node.

@export var initial_state: State

var current_state: State
var _states: Dictionary = {}

func _ready() -> void:
	var actor := get_parent()
	for child in get_children():
		if child is State:
			_states[child.name.to_lower()] = child
			child.actor = actor
			child.state_machine = self
	current_state = initial_state if initial_state != null else get_child(0) as State
	# Defer enter() so that Player's @onready vars are resolved first.
	current_state.enter.call_deferred()

func _process(delta: float) -> void:
	current_state.update(delta)

func _physics_process(delta: float) -> void:
	current_state.physics_update(delta)

func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	var key: String = String(state_name).to_lower()
	if not _states.has(key):
		push_warning("StateMachine: unknown state '%s'" % key)
		return
	current_state.exit()
	current_state = _states[key]
	current_state.enter(msg)
