extends Node
## Raumwechsel (Phase 8). Autoload — DER einzige Weg von einem Raum in einen anderen.
##
## Warum ein Autoload und nicht ein Node in der Weltszene: die Blende und der Wechsel muessen
## den Raum ueberleben, um den es geht. Die Weltszene (`scenes/main.tscn`) wird dabei NICHT
## gewechselt: sie ist persistent und haelt Player, PartyManager und die Overlays als
## Geschwister des Raums. Getauscht wird nur das eine Kind von `RoomHost`.
##
## Der Autoload kennt die Weltszene nicht statisch, sondern wird von ihr REGISTRIERT
## (`bind_world`). Ein absoluter Pfad wie "/root/Main/Player" waere in den Testszenen falsch —
## die haengen `main.tscn` als Kind unter sich (Muster seit phase4_sim).

## Der Raum steht, der Spieler ist gesetzt, die Kamera ausgerichtet — noch waehrend der Blende.
## Andockpunkt des `AudioManager` (Phase 10, liest `Room.music_id`): Autoloads koordinieren sich
## ueber Signale, nicht ueber direkte Referenzen aufeinander. Der RoomManager kennt den
## AudioManager darum nicht — die Abhaengigkeit laeuft nur in die andere Richtung.
signal room_changed(room_id: StringName)
## Blende ist wieder offen und der Input frei.
signal transition_finished

const REGISTRY_PATH := "res://resources/room_registry.tres"
const FADE_SCENE := "res://ui/transition_fade/transition_fade.tscn"

## Dauer je Blendenhaelfte. 18 F = 0,3 s bei 60 Hz. Kein `.tres`-Wert, weil er nicht zu einer
## Figur oder einem Gegenstand gehoert — aber zur Laufzeit setzbar (die Tests kuerzen ihn).
var fade_frames: int = 18

var _registry: RoomRegistry
var _fade: TransitionFade

var _host: Node2D
var _player: Player
var _party: PartyManager

var _room: Room = null
var _room_id: StringName = &""
var _spawn_id: StringName = &""
var _transitioning: bool = false

func _ready() -> void:
	_registry = load(REGISTRY_PATH) as RoomRegistry
	if _registry == null:
		push_error("RoomManager: %s fehlt oder ist keine RoomRegistry." % REGISTRY_PATH)
	_fade = (load(FADE_SCENE) as PackedScene).instantiate() as TransitionFade
	add_child(_fade)

## Die Weltszene meldet sich an. Wird bei jedem Aufbau von main.tscn erneut aufgerufen (auch nach
## einem Szenen-Reload), darum idempotent.
func bind_world(host: Node2D, player: Player, party: PartyManager) -> void:
	_host = host
	_player = player
	_party = party
	# Referenzen loslassen, wenn die Weltszene verschwindet — sonst zeigt der Autoload nach einem
	# Szenenwechsel auf freigegebene Nodes.
	if not host.tree_exiting.is_connected(_on_world_exiting):
		host.tree_exiting.connect(_on_world_exiting)

func _on_world_exiting() -> void:
	_host = null
	_player = null
	_party = null
	_room = null
	_room_id = &""

func is_bound() -> bool:
	return _host != null and is_instance_valid(_host)

func current_room() -> Room:
	return _room

## Die registrierte Welt (Phase 9). Der SaveManager braucht Ensemble-Zustand und den Player,
## kennt die Weltszene aber selbst nicht — statt eines zweiten `bind_world` fragt er hier.
## Die Abhaengigkeit laeuft nur in diese Richtung: der RoomManager ruft den SaveManager nie.
func player() -> Player:
	return _player

func party() -> PartyManager:
	return _party

## Kennt die Registry diesen Raum? Der SaveManager prueft damit einen Spielstand, BEVOR er ihn
## anwendet — eine unbekannte Raum-ID darf kein halb geladenes Spiel hinterlassen.
func has_room(room_id: StringName) -> bool:
	return _registry != null and _registry.has_room(room_id)

## Fuer Phase 9 (`SaveData.room_id` / `spawn_id`).
func current_room_id() -> StringName:
	return _room_id

func current_spawn_id() -> StringName:
	return _spawn_id

func is_transitioning() -> bool:
	return _transitioning

## Den Raum anhalten (Phase 9). Gegner, Tueren und Platten stehen still, Player und Overlays
## laufen weiter — sie haengen als Geschwister des Raums in der Weltszene, nicht darin.
##
## Gebraucht beim Game Over: bis Phase 9 lief der Raum hinter der Blende ungebremst weiter und
## das Skelett schlug auf die gefallene Figur ein. `process_mode` statt `Engine.time_scale` oder
## `get_tree().paused` — dasselbe Mittel wie im HitstopManager, und aus demselben Grund: es
## trifft genau die gewuenschten Nodes und laesst UI und Blenden in Ruhe.
##
## Zurueckgenommen wird das NICHT hier, sondern in `_swap_room`: der naechste Raum laeuft immer.
func set_room_frozen(frozen: bool) -> void:
	if not is_bound():
		return
	_host.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT

func is_room_frozen() -> bool:
	return is_bound() and _host.process_mode == Node.PROCESS_MODE_DISABLED

func fade_alpha() -> float:
	return _fade.alpha() if _fade != null else 0.0

## Spielstart: Startraum ohne Blende. Es gibt nichts wegzublenden.
func enter_start_room() -> void:
	if _registry == null:
		return
	_swap_room(_registry.start_room, _registry.start_spawn)

## Neustart nach Game Over. Ersetzt den `reload_current_scene()` aus Phase 7: der Raum ist seit
## Phase 8 wegwerfbar, also wird er weggeworfen statt die ganze Szene neu aufzubauen. Gegner
## respawnen dabei von selbst, weil der Raum frisch instanziert wird.
##
## KEINE Ausblende, sondern sofort schwarz: die Game-Over-Blende hat das Bild schon zugezogen.
## Ein zweites Ausblenden von 0 nach 1 haette den toten Raum fuer 18 Frames wieder sichtbar
## gemacht, sobald der Aufrufer seine eigene Blende zuruecksetzt.
func restart_at_start() -> void:
	if _registry == null or _party == null or not is_bound():
		return
	if _transitioning:
		return
	_party.revive_all()
	enter_from_black(_registry.start_room, _registry.start_spawn)

## In einen Raum HINEIN blenden, ohne vorher hinaus zu blenden. Zwei Aufrufer: der
## Game-Over-Neustart (Phase 7) und das Laden eines Spielstands (Phase 9) — in beiden Faellen
## ist das Bild schon zu, und ein Ausblenden von 0 nach 1 haette die tote Welt fuer `fade_frames`
## noch einmal gezeigt. Ist es nicht zu (ein Laden mitten im Spiel), ist es ein harter Schnitt
## nach Schwarz: es gibt keinen Zustand, in dem die alte Welt beim Laden noch etwas zu sagen hat.
func enter_from_black(room_id: StringName, spawn_id: StringName) -> void:
	if not is_bound():
		push_error("RoomManager: keine Weltszene registriert (bind_world fehlt).")
		return
	if _registry == null or not _registry.has_room(room_id):
		push_error("RoomManager: unbekannte Raum-ID '%s'." % room_id)
		return
	if _transitioning:
		return
	_transitioning = true
	_player.set_input_locked(true)
	_fade.set_black(true)
	_swap_room(room_id, spawn_id)
	_fade.fade_in(fade_frames)
	await _fade.fade_finished
	_transitioning = false
	if _player != null:
		_player.set_input_locked(false)
	transition_finished.emit()

## Der einzige oeffentliche Weg in einen anderen Raum.
func transition_to(room_id: StringName, spawn_id: StringName) -> void:
	if _transitioning:
		return  # Doppelausloesung (zwei Trigger, zwei Frames) ist ein No-Op
	if not is_bound():
		push_error("RoomManager: keine Weltszene registriert (bind_world fehlt).")
		return
	if _registry == null or not _registry.has_room(room_id):
		push_error("RoomManager: unbekannte Raum-ID '%s'." % room_id)
		return

	_transitioning = true
	# Input an der Quelle sperren: Player, Reif und PartyManager lesen alle denselben Schalter.
	_player.set_input_locked(true)

	_fade.fade_out(fade_frames)
	await _fade.fade_finished

	# Erst JETZT — bei voller Schwaerze — wird getauscht. Genau deshalb kein
	# `change_scene_to_file`: das gaebe die alte Szene frei, bevor die Blende zu ist (und wuerde
	# hier den Player mitnehmen, der den Wechsel ueberleben muss).
	_swap_room(room_id, spawn_id)

	_fade.fade_in(fade_frames)
	await _fade.fade_finished

	_transitioning = false
	if _player != null:
		_player.set_input_locked(false)
	transition_finished.emit()

## Alten Raum weg, neuen rein, Spieler und Kamera setzen. Laeuft immer hinter der Blende (oder
## beim Spielstart, wo noch nichts zu sehen ist).
func _swap_room(room_id: StringName, spawn_id: StringName) -> void:
	if _room != null and is_instance_valid(_room):
		# remove_child ZUSAETZLICH zu queue_free: queue_free laesst den Node bis zum Frame-Ende
		# im Baum, es haetten also kurz zwei Raeume in `RoomHost` gehangen.
		_host.remove_child(_room)
		_room.queue_free()
	_room = null

	var path: String = _registry.scene_path(room_id)
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_error("RoomManager: '%s' laedt nicht (%s)." % [room_id, path])
		return
	# Synchron statt load_threaded_request: die Raeume sind zwei TileMapLayer plus eine Handvoll
	# Nodes, der Ladevorgang liegt komplett hinter der schwarzen Blende, und `load()` cacht. Ein
	# Threaded-Load mit Polling waere im headless-Test nicht deterministisch.
	_room = scene.instantiate() as Room
	if _room == null:
		push_error("RoomManager: '%s' ist keine Room-Szene." % room_id)
		return
	# Ein frisch aufgebauter Raum laeuft immer — sonst traegt ein Game-Over-Freeze (Phase 9) in
	# den naechsten Raum hinein und man stuende in einer stehenden Welt.
	_host.process_mode = Node.PROCESS_MODE_INHERIT
	_host.add_child(_room)
	_room_id = room_id
	_spawn_id = spawn_id

	if _player != null:
		_player.global_position = _room.spawn_point(spawn_id)
		# Die neue Figur startet aus dem Stand — sonst traegt das Tempo aus dem alten Raum in den
		# neuen hinein (gleiche Begruendung wie beim Figurenwechsel, Phase 4).
		_player.velocity = Vector2.ZERO
		_apply_camera_limits()

	room_changed.emit(room_id)

## Die Kamera darf nie ueber die Aussenwand hinausschauen. Stand bis Phase 7 in scenes/main.gd —
## dort lief es genau einmal beim Start; es muss bei JEDEM Raumwechsel laufen, weil die Raeume
## unterschiedlich gross sind.
##
## Smoothing bleibt aus (CLAUDE.md > Auflösung & Look): es erzeugt Sub-Pixel-Kamerapositionen und
## damit Tile-Seams.
func _apply_camera_limits() -> void:
	var b: Rect2i = _room.bounds()
	var cam: Camera2D = _player.camera
	cam.limit_left = b.position.x
	cam.limit_top = b.position.y
	cam.limit_right = b.end.x
	cam.limit_bottom = b.end.y
	cam.limit_smoothed = false
	cam.position_smoothing_enabled = false
