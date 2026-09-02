extends Node
## Speichern und Laden (Phase 9). Autoload — DER einzige Weg auf die Platte und der Halter des
## laufenden Weltzustands (`world_flags`, Spielzeit).
##
## Aufteilung gegen den RoomManager: der besitzt den RAUM (welcher steht gerade, wie kommt man
## in einen anderen), dieser hier besitzt den FORTSCHRITT (was ist passiert, wo setzt man wieder
## auf). Die Abhaengigkeit laeuft nur in eine Richtung — SaveManager ruft RoomManager, nie
## umgekehrt. Wer Weltzustand braucht (ein erledigter Boss), fragt diesen Autoload direkt.
##
## Die Welt selbst kennt der Autoload nicht: er holt Player und PartyManager beim RoomManager,
## der von der Weltszene REGISTRIERT wird (`bind_world`). Damit funktioniert er in den
## Testszenen, die `main.tscn` als Kind unter sich haengen, genauso wie im Spiel.

## Ein Slot wurde geschrieben.
signal saved(slot: int)
## Ein Slot wurde erfolgreich angewandt — der Raum steht, die Blende laeuft noch.
signal loaded(slot: int)
## Laden abgebrochen (Datei fehlt, kaputt, falsche Version, unbekannter Raum). Die Welt ist
## unveraendert. Ohne dieses Signal waere ein kaputter Slot ein stummes Nichts im Menue.
signal load_failed(slot: int)
## Neues Spiel — Flags und Spielzeit sind zurueck auf Null.
signal game_restarted

const SLOT_COUNT := 3
const DEFAULT_DIR := "user://saves"

## Zur Laufzeit umsetzbar, damit die Testszenen NICHT die echten Spielstaende des Users
## ueberschreiben (phase9_sim zeigt auf `user://saves_test` und raeumt hinterher auf).
var save_dir: String = DEFAULT_DIR

## In welchen Slot ein Speicherpunkt schreibt und welchen das Game-Over-Menue anbietet.
## Slot-Auswahl-UI gibt es in Phase 9 nicht — die drei Slots sind angelegt und adressierbar.
var active_slot: int = 1

## Weltzustand des LAUFENDEN Spiels. Liegt hier und nicht im Raum: der Raum wird bei jedem
## Betreten neu instanziert (Phase 8), er kann sich nichts merken.
var _flags: Dictionary[StringName, bool] = {}
var _playtime_frames: int = 0


## Spielzeit laeuft, solange eine Welt steht — auch hinter einer Blende. Frames, wie jeder
## Zeitwert im Projekt (Tuer, Gegner-KI, Blenden), damit der Wert deterministisch bleibt.
func _physics_process(_delta: float) -> void:
	if RoomManager.is_bound():
		_playtime_frames += 1


# --- Weltzustand ------------------------------------------------------------------------------

func get_flag(flag: StringName) -> bool:
	return _flags.get(flag, false)


func set_flag(flag: StringName, value: bool = true) -> void:
	if value:
		_flags[flag] = true
	else:
		_flags.erase(flag)  # false und "nie gesetzt" sind dasselbe -> Savefile bleibt klein


func flag_count() -> int:
	return _flags.size()


## Erledigter Gegner mit `persist_id` (Bosse/Quest-Kills). Der Praefix haelt den
## Flag-Namensraum sortiert, sobald Schalter und Truhen dazukommen.
func mark_killed(persist_id: StringName) -> void:
	set_flag(&"kill:" + persist_id)


func is_killed(persist_id: StringName) -> bool:
	return get_flag(&"kill:" + persist_id)


func playtime_frames() -> int:
	return _playtime_frames


func playtime_text() -> String:
	var seconds: int = _playtime_frames / 60
	return "%02d:%02d" % [seconds / 60, seconds % 60]


# --- Slots ------------------------------------------------------------------------------------

func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [save_dir, slot]


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Kopfdaten eines Slots fuer die Anzeige (Raum, Spielzeit). `null` = leer oder unbrauchbar.
## Liest die ganze Datei — ein Spielstand ist ein paar hundert Byte, ein separater Header
## waere eine zweite Wahrheit ueber denselben Slot.
func slot_info(slot: int) -> SaveData:
	return _read(slot)


func delete_slot(slot: int) -> bool:
	if not has_slot(slot):
		return false
	return DirAccess.remove_absolute(slot_path(slot)) == OK


# --- Speichern --------------------------------------------------------------------------------

## Zustand der laufenden Welt als SaveData. Ohne Datei-IO — so kann der Test den Inhalt pruefen,
## ohne die Platte zu befragen.
##
## `spawn_id` leer = der Spawn, ueber den der Raum betreten wurde. Ein Speicherpunkt nennt
## stattdessen den SpawnPoint neben sich, damit man dort wieder aufsetzt und nicht am Raumeingang.
func capture(spawn_id: StringName = &"") -> SaveData:
	var party: PartyManager = RoomManager.party()
	if party == null:
		return null
	var data := SaveData.new()
	data.room_id = RoomManager.current_room_id()
	data.spawn_id = spawn_id if spawn_id != &"" else RoomManager.current_spawn_id()
	data.figure_index = party.active_index()
	data.health = party.health_array()
	data.corruption = party.corruption_array()
	data.world_flags = _flags.duplicate()
	data.playtime_frames = _playtime_frames
	data.saved_at = int(Time.get_unix_time_from_system())
	return data


func save_to_slot(slot: int, spawn_id: StringName = &"") -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		push_error("SaveManager: Slot %d liegt ausserhalb 1..%d." % [slot, SLOT_COUNT])
		return false
	var data: SaveData = capture(spawn_id)
	if data == null:
		push_error("SaveManager: keine Welt gebunden — nichts zu speichern.")
		return false
	if not DirAccess.dir_exists_absolute(save_dir):
		if DirAccess.make_dir_recursive_absolute(save_dir) != OK:
			push_error("SaveManager: '%s' laesst sich nicht anlegen." % save_dir)
			return false
	var file: FileAccess = FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: '%s' nicht schreibbar (%d)." % [slot_path(slot),
			FileAccess.get_open_error()])
		return false
	# Eingerueckt geschrieben: ein Spielstand wird im Dev-Alltag gelesen, nicht nur geparst.
	file.store_string(JSON.stringify(data.to_dict(), "\t"))
	file.close()
	active_slot = slot
	saved.emit(slot)
	return true


# --- Laden ------------------------------------------------------------------------------------

## Slot anwenden. Reihenfolge ist Absicht: erst die Flags, DANN der Raum — ein erledigter Boss
## liest sein Flag in `_ready()`, also muss es stehen, bevor der Raum instanziert wird.
##
## Geladen wird immer als harter Schnitt nach Schwarz (`RoomManager.enter_from_black`): es gibt
## keinen Zustand, in dem die alte Welt beim Laden noch etwas zu zeigen haette.
func load_from_slot(slot: int) -> bool:
	var data: SaveData = _read(slot)
	if data == null:
		push_error("SaveManager: Slot %d ist leer oder unbrauchbar." % slot)
		load_failed.emit(slot)
		return false
	if not RoomManager.is_bound():
		push_error("SaveManager: keine Welt gebunden — nichts zu laden.")
		load_failed.emit(slot)
		return false
	if not RoomManager.has_room(data.room_id):
		push_error("SaveManager: Slot %d nennt den unbekannten Raum '%s'." % [slot, data.room_id])
		load_failed.emit(slot)
		return false
	var party: PartyManager = RoomManager.party()
	if party == null:
		load_failed.emit(slot)
		return false

	active_slot = slot
	_flags = data.world_flags.duplicate()
	_playtime_frames = data.playtime_frames
	party.apply_state(data.figure_index, data.health, data.corruption)
	RoomManager.enter_from_black(data.room_id, data.spawn_id)
	loaded.emit(slot)
	return true


## Neues Spiel: Weltzustand weg, Ensemble komplett zurueck, Startraum. Der Slot auf Platte
## bleibt stehen — "Neu beginnen" im Game-Over-Menue ist kein Loeschen.
func new_game() -> void:
	_flags.clear()
	_playtime_frames = 0
	# Erst danach der Raum: `restart_at_start` instanziert ihn, und die Flags muessen schon
	# geraeumt sein (gleicher Grund wie beim Laden).
	RoomManager.restart_at_start()
	game_restarted.emit()


func _read(slot: int) -> SaveData:
	if not has_slot(slot):
		return null
	var file: FileAccess = FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()
	# `parse_string` gibt bei Muell `null` zurueck; `from_dict` faengt alles ab, was danach noch
	# nicht passt (falsche Version, fehlender Raum). Ein kaputter Slot darf nie halb angewandt
	# werden — darum liegt die gesamte Pruefung VOR der ersten Zuweisung an die Welt.
	return SaveData.from_dict(JSON.parse_string(text))
