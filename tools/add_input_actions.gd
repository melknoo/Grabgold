extends SceneTree
## Schreibt die KOMPLETTE Tastenbelegung nach project.godot.
## Aufruf: $GODOT --headless --path . --script res://tools/add_input_actions.gd
##
## Warum per Skript: project.godot wird von der Engine serialisiert, nicht von Hand editiert.
## Das Tool ist die EINZIGE Quelle der Belegung — es legt Actions nicht nur an, sondern
## ueberschreibt sie auch. Wer eine Taste aendern will, aendert sie hier und laesst das Tool
## laufen; ein zweiter Lauf erzeugt exakt dasselbe Ergebnis.
##
## Layout-Leitgedanke (User-Entscheidung): steuern mit WASD, austeilen mit der Maus. Alles, was
## im Kampf gedrueckt oder GEHALTEN wird, muss die linke Hand auf WASD oder die rechte auf der
## Maus erreichen. J und L bleiben als Zweitbelegung fuers Pfeiltasten-Spiel erhalten.

func _initialize() -> void:
	_write(&"move_up",    [_key(KEY_W), _key(KEY_UP)])
	_write(&"move_down",  [_key(KEY_S), _key(KEY_DOWN)])
	_write(&"move_left",  [_key(KEY_A), _key(KEY_LEFT)])
	_write(&"move_right", [_key(KEY_D), _key(KEY_RIGHT)])

	# Angriff: Maus zuerst. E liegt fuer die WASD-Hand direkt neben W.
	_write(&"attack", [
		_mouse(MOUSE_BUTTON_LEFT),
		_key(KEY_E),
		_key(KEY_J),
	])

	# Phase-Dash. Leertaste (Daumen) und Shift (kleiner Finger) — beides ohne Griffwechsel
	# erreichbar. Wirkt nur, solange der Reif kanalisiert wird; es gibt bewusst keinen
	# Dodge-Roll als Grundfaehigkeit (Kickoff).
	_write(&"dash", [
		_key(KEY_SPACE),
		_key(KEY_SHIFT),
		_pad(JOY_BUTTON_A),
	])

	# Reif kanalisieren — wird DAUERHAFT GEHALTEN, darum die rechte Maustaste bzw. der rechte
	# Trigger. Die Schultertasten sind schon vom Figurenwechsel belegt.
	_write(&"reif_channel", [
		_mouse(MOUSE_BUTTON_RIGHT),
		_key(KEY_L),
		_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0),
	])

	# Kickoff: "Schultertaste wechselt durch". Q fuer die Dev-Arbeit an der Tastatur.
	_write(&"switch_figure", [
		_key(KEY_Q),
		_pad(JOY_BUTTON_RIGHT_SHOULDER),
		_pad(JOY_BUTTON_LEFT_SHOULDER),
	])

	# Weltinteraktion (ab Phase 8): Raum-Tueren mit `auto_enter = false`, ab Phase 9 die
	# Speicherpunkte, ab Phase 11 die NPCs. F liegt fuer die WASD-Hand in Reichweite, ohne mit
	# Angriff (E) oder Dash (Space/Shift) zu kollidieren; Enter ist die Tastatur-Zweitbelegung.
	# Gamepad Y, weil A der Dash und die Schultertasten der Figurenwechsel sind.
	_write(&"interact", [
		_key(KEY_F),
		_key(KEY_ENTER),
		_pad(JOY_BUTTON_Y),
	])

	_write(&"debug_toggle", [_key(KEY_F1)])

	ProjectSettings.save()
	quit()

func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev

func _mouse(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	return ev

func _pad(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev

func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev

## Setzt die Action auf genau diese Events — auch wenn sie schon existiert.
func _write(action: StringName, events: Array) -> void:
	ProjectSettings.set_setting("input/%s" % action, {"deadzone": 0.5, "events": events})
	print("Action '%s' gesetzt (%d Events)." % [action, events.size()])
