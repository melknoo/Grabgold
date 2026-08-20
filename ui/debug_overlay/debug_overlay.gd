extends CanvasLayer

@onready var label: Label = $Label

var _player: Player = null

func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player

func _process(_dt: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return
	var state_name: String = ""
	if _player.state_machine != null and _player.state_machine.current_state != null:
		state_name = _player.state_machine.current_state.name
	label.text = (
		"FPS: %d\nState: %s\nFacing: %s\nAnim: %s [%d]\nDebugBoxes: %s" % [
			Engine.get_frames_per_second(),
			state_name,
			_player.facing,
			_player.sprite.animation,
			_player.sprite.frame,
			str(Debug.show_boxes)
		]
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle"):
		Debug.toggle_boxes()
