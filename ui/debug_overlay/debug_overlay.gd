extends CanvasLayer
## Debug-Overlay (F1 schaltet die Box-Visualisierung). Ohne diese Zahlen ist Combat-Feel nicht
## beurteilbar — Kickoff, "Debug-Overlay ab Tag eins".

@onready var label: Label = $Label

var _player: Player = null
## Aktueller Raum. Wird jeden Frame gegen den RoomManager geprueft, weil er sich seit Phase 8
## unter dem Overlay weg tauschen kann. Optional: das Overlay soll auch ohne Raum funktionieren.
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
		+ "REIF: %s  Stufe %d%s\nKorruption: %.1f %%\nDash-CD: %d  Phasing: %s\n"
		+ "Raum: %s\nSlot %d%s  Zeit %s  Flags %d\n"
		+ "Musik: %s%s  SFX: %s (%d)  Loop: %s\nDebugBoxes: %s"
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
		_reif_flags(reif),
		100.0 * _player.get_corruption() / reif.stats.corruption_max,
		reif.dash_cooldown_left(),
		str(reif.is_phasing()),
		_room_text(),
		SaveManager.active_slot,
		"" if SaveManager.has_slot(SaveManager.active_slot) else " (leer)",
		SaveManager.playtime_text(),
		SaveManager.flag_count(),
		_or_dash(AudioManager.current_music()),
		"  BLENDE" if AudioManager.is_music_fading() else "",
		_or_dash(AudioManager.last_played()),
		AudioManager.active_sfx_count(),
		_or_dash(AudioManager.loop_id()),
		str(Debug.show_boxes),
	]


## Leere StringName lesbar machen. Ohne das steht im Overlay eine Leerstelle, und eine
## Leerstelle sieht wie ein Fehler aus statt wie "gerade nichts".
func _or_dash(id: StringName) -> String:
	return String(id) if id != &"" else "-"


## Was die hohen Korruptionsstufen gerade tun (Phase 7). Ohne das sieht ein Zwangsangriff wie
## ein Eingabefehler aus und eine gesperrte Taste wie ein Bug.
func _reif_flags(reif: Reif) -> String:
	var flags: Array[String] = []
	if reif.is_compelled():
		flags.append("ZWANG")
	if reif.switch_locked():
		flags.append("WECHSEL GESPERRT")
	return ("  " + " · ".join(flags)) if not flags.is_empty() else ""


## Raum-ID, Transitions-Zustand und die raumspezifische Zeile (Raum 01: Platte + Tuer).
##
## Das Overlay kennt Platte und Tuer seit Phase 8 NICHT mehr selbst — es fragt `debug_text()`.
## Sonst waere es in Raum 02/03, die beides nicht haben, an `null` gescheitert.
func _room_text() -> String:
	if _room == null or not is_instance_valid(_room):
		_room = RoomManager.current_room()
	if _room == null:
		return "-"
	var extra: String = _room.debug_text()
	return "%s%s%s" % [
		_room.room_id,
		"  WECHSEL %.2f" % RoomManager.fade_alpha() if RoomManager.is_transitioning() else "",
		("  " + extra) if extra != "" else "",
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle"):
		Debug.toggle_boxes()
