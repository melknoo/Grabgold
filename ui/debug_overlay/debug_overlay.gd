extends CanvasLayer
## Debug-Overlay (F1 schaltet die Box-Visualisierung). Ohne diese Zahlen ist Combat-Feel nicht
## beurteilbar — Kickoff, "Debug-Overlay ab Tag eins".

@onready var label: Label = $Label

var _player: Player = null
## Raum-Zustand (Phase 6). Optional: die Testszenen laden main.tscn zwar mit, aber das Overlay
## soll auch in einer Szene ohne Raum funktionieren.
var _room: Room = null

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
	var figure: String = _player.profile.display_name if _player.profile != null else "?"
	var reif: Reif = _player.reif
	label.text = (
		"FPS: %d\nFigur: %s  HP: %d/%d  Gewicht: %.1f\nState: %s\nFacing: %s\nAnim: %s [%d]\n"
		+ "REIF: %s  Stufe %d\nKorruption: %.1f %%\nDash-CD: %d  Phasing: %s\n"
		+ "Raum: %s\nDebugBoxes: %s"
	) % [
		Engine.get_frames_per_second(),
		figure,
		_player.get_health(), _player.stats.max_health,
		_player.stats.weight,
		state_name,
		_player.facing,
		_player.sprite.animation,
		_player.sprite.frame,
		"AN" if reif.is_channeling() else "aus",
		reif.level(),
		100.0 * _player.get_corruption() / reif.stats.corruption_max,
		reif.dash_cooldown_left(),
		str(reif.is_phasing()),
		_room_text(),
		str(Debug.show_boxes),
	]


## Platte + Tuer in einer Zeile — die beiden Werte, an denen die Feel-Abnahme von Phase 6 haengt
## (ist das Fenster fair, ist die Platte als "schwer" lesbar?).
func _room_text() -> String:
	if _room == null or not is_instance_valid(_room):
		_room = get_tree().get_first_node_in_group(&"room") as Room
	if _room == null:
		return "-"
	return "Platte %s  Tuer %s" % [
		"GEDRUECKT" if _room.plate.is_pressed() else "offen",
		("OFFEN %.1fs" % (_room.door.frames_left() / 60.0)) if _room.door.is_open() else "zu",
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle"):
		Debug.toggle_boxes()
