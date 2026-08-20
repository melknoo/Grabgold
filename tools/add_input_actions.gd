extends SceneTree
## Fuegt fehlende Input-Actions in project.godot ein (idempotent).
## Aufruf: $GODOT --headless --path . --script res://tools/add_input_actions.gd
## Warum per Skript: project.godot wird von der Engine serialisiert, nicht von Hand editiert.

func _initialize() -> void:
	# Kickoff: "Schultertaste wechselt durch". Tastatur-Aequivalent Q fuer die Dev-Arbeit.
	_ensure(&"switch_figure", [
		_key(KEY_Q),
		_pad(JOY_BUTTON_RIGHT_SHOULDER),
		_pad(JOY_BUTTON_LEFT_SHOULDER),
	])
	ProjectSettings.save()
	quit()

func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev

func _pad(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev

func _ensure(action: StringName, events: Array) -> void:
	var key := "input/%s" % action
	if ProjectSettings.has_setting(key):
		print("Action '%s' existiert bereits — unveraendert." % action)
		return
	ProjectSettings.set_setting(key, {"deadzone": 0.5, "events": events})
	print("Action '%s' angelegt (%d Events)." % [action, events.size()])
