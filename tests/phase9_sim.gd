extends Node
## Headless-Verifikation Phase 9 (Speichern, Laden, Game Over). Prueft den Speicherpunkt, den
## Inhalt des Slots auf Platte, das Laden (Raum, Spawn, Ensemble, Flags, Spielzeit), die drei
## unabhaengigen Slots, das Verhalten bei kaputten Spielstaenden, persistente Gegner-Kills und
## das Game-Over-Menue mit beiden Eintraegen.
## Aufruf: $GODOT --headless --path . res://tests/phase9_sim.tscn
##
## Laeuft als SZENE, nicht per --script (siehe phase4..8_sim: bei --script fehlen die Autoloads).
##
## WICHTIG: der Test schreibt in `user://saves_test`, NICHT in `user://saves`. Sonst wuerde ein
## Testlauf die echten Spielstaende des Entwicklers ueberschreiben — darum ist
## `SaveManager.save_dir` zur Laufzeit setzbar.

const TEST_DIR := "user://saves_test"

var _fails: int = 0

## Signal-Mitschriften als MEMBER, nicht als lokale Variablen in einem Lambda: GDScript faengt
## lokale Variablen `by value` ein (Merker aus Phase 7).
var _saved: Array[int] = []
var _loaded: Array[int] = []
var _load_failed: Array[int] = []
var _restarted: int = 0
var _restored: int = 0
var _wiped: bool = false
## Wie oft Game Over gemeldet wurde. Bis Phase 9 lief das mehrfach, weil der Gegner hinter der
## Blende weiter zuschlug.
var _wipe_count: int = 0

func _on_saved(slot: int) -> void:
	_saved.append(slot)

func _on_loaded(slot: int) -> void:
	_loaded.append(slot)

func _on_load_failed(slot: int) -> void:
	_load_failed.append(slot)

func _on_restarted() -> void:
	_restarted += 1

func _on_restored() -> void:
	_restored += 1

func _on_wiped() -> void:
	_wiped = true
	_wipe_count += 1

## Notbremse. Der Test wartet an mehreren Stellen auf Signale und Zustaende (Blenden,
## I-Frames, Todesanimation); ein Fehler darin wuerde headless nicht fehlschlagen, sondern
## ewig laufen. Nach diesem Budget bricht der Lauf mit Fehlercode ab und nennt den letzten
## erreichten Abschnitt.
const FRAME_BUDGET := 6000

var _frames: int = 0
var _section: String = "Aufbau"
var _done: bool = false

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frames += 1
	if _frames < FRAME_BUDGET:
		return
	_done = true
	printerr("ABBRUCH: Frame-Budget (%d) erschoepft in Abschnitt '%s'." % [FRAME_BUDGET, _section])
	get_tree().quit(2)

## Abschnittsmarke. Zusaetzlich auf stderr, weil stdout bei Umleitung in eine Datei gepuffert
## wird — bei einem Haenger sieht man sonst gar nicht, wie weit der Lauf gekommen ist.
func section(title: String) -> void:
	_section = title
	print("\n== %s ==" % title)
	printerr("-> %s" % title)

func check(label: String, ok: bool, detail: String = "") -> void:
	print("  %s %s%s" % ["[OK]  " if ok else "[FAIL]", label, ("  -> " + detail) if detail != "" else ""])
	if not ok:
		_fails += 1


func _ready() -> void:
	# Kein Ton (Phase 10). Ein LAUFENDES Ogg laesst Godot beim Beenden zwei Fehlerzeilen im Log
	# stehen ("resources still in use") — Engine-Verhalten, nachgestellt ohne eine Zeile des
	# AudioManagers und auch mit `stop()` nicht abstellbar. Diese Suite prueft keinen Ton, also
	# soll sie die Zeilen auch nicht erben. Die Buchfuehrung des Managers laeuft trotzdem weiter,
	# der Test verhaelt sich also identisch. MUSS vor `add_child(main)` stehen: dort betritt der
	# Bootstrap den Startraum und der haette schon Musik angeworfen.
	AudioManager.enabled = false
	# Testverzeichnis statt der echten Spielstaende, und leer in den Lauf hinein.
	SaveManager.save_dir = TEST_DIR
	_wipe_dir()

	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var host: Node2D = main.get_node("RoomHost")
	var player: Player = main.get_node("Player")
	var party: PartyManager = main.get_node("PartyManager")
	var fade: GameOverFade = main.get_node("GameOverFade")
	var menu: GameOverMenu = main.get_node("GameOverMenu")
	# Kurze Blenden: der Test prueft Ablaeufe, nicht Feel-Dauern (18 F bzw. 60 F im Spiel).
	RoomManager.fade_frames = 6
	fade.fade_frames = 6
	SaveManager.saved.connect(_on_saved)
	SaveManager.loaded.connect(_on_loaded)
	SaveManager.load_failed.connect(_on_load_failed)
	SaveManager.game_restarted.connect(_on_restarted)
	party.party_restored.connect(_on_restored)
	party.party_wiped.connect(_on_wiped)
	await physics(3)

	section("1. Frischer Start: kein Spielstand")
	check("aktiver Slot ist 1", SaveManager.active_slot == 1, str(SaveManager.active_slot))
	check("Slot 1 leer", not SaveManager.has_slot(1))
	check("slot_info(1) == null", SaveManager.slot_info(1) == null)
	check("keine Flags", SaveManager.flag_count() == 0, str(SaveManager.flag_count()))
	var playtime_early: int = SaveManager.playtime_frames()
	await physics(5)
	check("Spielzeit laeuft", SaveManager.playtime_frames() > playtime_early,
		"%d -> %d" % [playtime_early, SaveManager.playtime_frames()])
	check("Startraum ist room_01", RoomManager.current_room_id() == &"room_01",
		str(RoomManager.current_room_id()))

	section("2. Speicherpunkt: heilt, holt zurueck, schreibt den Slot")
	var save_point: SavePoint = RoomManager.current_room().get_node("SavePoint")
	# Zustand aufbauen, den der Punkt reparieren soll: verletzt, korrumpiert, zweite Figur weg.
	player.set_health(player.stats.max_health - 3)
	player.set_corruption(40.0)
	party.apply_state(0, [player.stats.max_health - 3, 0], [40.0, 12.0])
	await physics(2)
	check("Vorbedingung: zweite Figur ausgefallen", party.is_downed(1))
	check("Vorbedingung: nur eine Figur steht", party.standing_count() == 1,
		str(party.standing_count()))
	player.global_position = save_point.global_position
	await physics(2)
	check("noch nichts gespeichert (kein Tastendruck)", _saved.is_empty(), str(_saved))
	await press(&"interact")
	check("Slot 1 geschrieben", _saved.size() == 1 and _saved[0] == 1, str(_saved))
	check("Datei liegt in %s" % TEST_DIR, FileAccess.file_exists(SaveManager.slot_path(1)),
		SaveManager.slot_path(1))
	check("Speicherpunkt leuchtet", save_point.is_flashing())
	check("Ensemble aufgefrischt gemeldet", _restored == 1, str(_restored))
	check("Health voll", player.get_health() == player.stats.max_health,
		"%d/%d" % [player.get_health(), player.stats.max_health])
	check("ausgefallene Figur steht wieder", not party.is_downed(1) and party.standing_count() == 2,
		str(party.standing_count()))
	# DIE Entscheidung dieser Phase: der Punkt heilt, aber er wascht den Reif nicht ab.
	check("Korruption der aktiven Figur BLEIBT", absf(player.get_corruption() - 40.0) < 1.0,
		"%.2f" % player.get_corruption())
	check("Korruption der inaktiven Figur BLEIBT", absf(party.corruption_of(1) - 12.0) < 0.01,
		"%.2f" % party.corruption_of(1))

	section("3. Inhalt des Slots auf Platte")
	var raw: Variant = JSON.parse_string(FileAccess.open(SaveManager.slot_path(1),
		FileAccess.READ).get_as_text())
	check("gueltiges JSON", raw is Dictionary)
	var data: SaveData = SaveData.from_dict(raw)
	check("als SaveData lesbar", data != null)
	check("version == %d" % SaveData.VERSION, data.version == SaveData.VERSION, str(data.version))
	check("room_id == room_01", data.room_id == &"room_01", str(data.room_id))
	# Nicht der Raumeingang, sondern der SpawnPoint NEBEN dem Speicherpunkt.
	check("spawn_id == save_a", data.spawn_id == &"save_a", str(data.spawn_id))
	check("figure_index == 0", data.figure_index == 0, str(data.figure_index))
	# Nicht hart hingeschrieben: die Werte stehen in den Figuren-`.tres` (Kurier 6, Zwerg 9) und
	# duerfen sich dort aendern, ohne diesen Test zu brechen.
	var full: String = str([party.figures[0].stats.max_health, party.figures[1].stats.max_health])
	check("health beider Figuren voll", str(data.health) == full,
		"%s (erwartet %s)" % [data.health, full])
	# JSON kennt keinen Integer — ohne die Wandlung in from_dict stuenden hier Floats.
	check("health-Werte sind Ints", data.health.size() == 2 and typeof(data.health[0]) == TYPE_INT)
	check("Korruption mitgespeichert", absf(data.corruption[0] - 40.0) < 1.0
		and absf(data.corruption[1] - 12.0) < 0.01, str(data.corruption))
	check("Spielzeit mitgespeichert", data.playtime_frames > 0, str(data.playtime_frames))
	check("Zeitstempel gesetzt", data.saved_at > 0, str(data.saved_at))
	check("Spielzeit-Text als mm:ss", data.playtime_text().length() == 5, data.playtime_text())

	section("4. Laden holt Raum, Position, Ensemble, Flags und Zeit zurueck")
	# Alles verstellen, was der Spielstand festhaelt.
	SaveManager.set_flag(&"nach_dem_speichern")
	await transition(&"room_02", &"start")
	player.set_health(2)
	player.set_corruption(70.0)
	party.switch_next()
	await physics(2)
	check("Vorbedingung: zweite Figur aktiv, anderer Raum", party.active_index() == 1
		and RoomManager.current_room_id() == &"room_02")
	var ok: bool = SaveManager.load_from_slot(1)
	check("load_from_slot meldet Erfolg", ok)
	await settle()
	check("loaded-Signal", _loaded.size() == 1 and _loaded[0] == 1, str(_loaded))
	check("zurueck in room_01", RoomManager.current_room_id() == &"room_01",
		str(RoomManager.current_room_id()))
	check("Spieler auf dem Spawn save_a",
		player.global_position.is_equal_approx(Vector2(136, 264)), str(player.global_position))
	check("genau ein Raum in RoomHost", host.get_child_count() == 1, str(host.get_child_count()))
	check("aktive Figur wieder Index 0", party.active_index() == 0, str(party.active_index()))
	check("Health wiederhergestellt", player.get_health() == player.stats.max_health,
		"%d/%d" % [player.get_health(), player.stats.max_health])
	check("Korruption wiederhergestellt", absf(player.get_corruption() - 40.0) < 1.0,
		"%.2f" % player.get_corruption())
	check("Korruption der inaktiven Figur wiederhergestellt",
		absf(party.corruption_of(1) - 12.0) < 0.01, "%.2f" % party.corruption_of(1))
	# Ein Flag, das NACH dem Speichern gesetzt wurde, darf das Laden nicht ueberleben.
	check("Flag von nach dem Speichern ist weg", not SaveManager.get_flag(&"nach_dem_speichern"))
	check("Blende offen", is_zero_approx(RoomManager.fade_alpha()))
	check("Input frei", not player.is_input_locked())
	check("Spielzeit auf den Stand zurueckgesetzt",
		absi(SaveManager.playtime_frames() - data.playtime_frames) < 40,
		"%d (Slot: %d)" % [SaveManager.playtime_frames(), data.playtime_frames])
	# Gegenprobe, dass die Welt nach dem Laden wirklich laeuft.
	Input.action_press(&"move_right")
	var pos_before: Vector2 = player.global_position
	await physics(10)
	Input.action_release(&"move_right")
	check("Welt nach dem Laden spielbar", player.global_position.x > pos_before.x + 5.0,
		"%.1f px" % (player.global_position.x - pos_before.x))
	await physics(2)

	section("5. Drei unabhaengige Slots")
	await transition(&"room_02", &"start")
	check("Slot 2 geschrieben", SaveManager.save_to_slot(2))
	check("aktiver Slot folgt dem Schreiben", SaveManager.active_slot == 2,
		str(SaveManager.active_slot))
	check("Slot 1 unveraendert (room_01)", SaveManager.slot_info(1).room_id == &"room_01",
		str(SaveManager.slot_info(1).room_id))
	check("Slot 2 haelt room_02", SaveManager.slot_info(2).room_id == &"room_02",
		str(SaveManager.slot_info(2).room_id))
	check("Slot 3 leer", not SaveManager.has_slot(3))
	SaveManager.load_from_slot(1)
	await settle()
	check("Slot 1 laedt weiterhin room_01", RoomManager.current_room_id() == &"room_01",
		str(RoomManager.current_room_id()))
	check("Slot 2 geloescht", SaveManager.delete_slot(2) and not SaveManager.has_slot(2))
	check("Loeschen eines leeren Slots meldet false", not SaveManager.delete_slot(2))
	check("Slot 0 und 4 werden abgewiesen",
		not SaveManager.save_to_slot(0) and not SaveManager.save_to_slot(4))

	section("6. Kaputte Spielstaende aendern die Welt nicht")
	check("from_dict(null) == null", SaveData.from_dict(null) == null)
	check("from_dict('kein Dictionary') == null", SaveData.from_dict("nope") == null)
	var room_before: StringName = RoomManager.current_room_id()
	var pos_stable: Vector2 = player.global_position
	for bad: Array in [
		["Muell", "{ das ist kein json"],
		["falsche Version", '{"version": 99, "room_id": "room_01"}'],
		["unbekannter Raum", '{"version": 1, "room_id": "gibt_es_nicht", "spawn_id": "start"}'],
		["ohne Raum", '{"version": 1, "spawn_id": "start"}'],
	]:
		_write_slot(3, bad[1])
		var before: int = _load_failed.size()
		check("%s: Laden schlaegt fehl" % bad[0], not SaveManager.load_from_slot(3))
		check("  load_failed gemeldet", _load_failed.size() == before + 1)
		await physics(2)
		check("  Welt unveraendert", RoomManager.current_room_id() == room_before
			and player.global_position.is_equal_approx(pos_stable), str(RoomManager.current_room_id()))
		check("  Input frei", not player.is_input_locked())
	SaveManager.delete_slot(3)
	SaveManager.active_slot = 1

	section("7. Persistente Gegner-Kills ueber world_flags")
	# Normaler Gegner (ohne persist_id) respawnt weiter — das ist die Regel seit Phase 8.
	await transition(&"room_02", &"start")
	var plain: Skeleton = RoomManager.current_room().get_node("Skeleton")
	check("Gegner in B hat keine persist_id", plain.persist_id == &"", str(plain.persist_id))
	await kill(plain)
	await transition(&"room_03", &"start")
	await transition(&"room_02", &"start")
	check("Gegner ohne persist_id ist wieder da",
		RoomManager.current_room().get_node_or_null("Skeleton") != null)
	# Markierter Gegner bleibt weg.
	await transition(&"room_03", &"start")
	var boss: Skeleton = RoomManager.current_room().get_node("Waechter")
	check("Gegner in C hat persist_id", boss.persist_id == &"skeleton_c", str(boss.persist_id))
	check("noch nicht als erledigt vermerkt", not SaveManager.is_killed(&"skeleton_c"))
	await kill(boss)
	check("Flag kill:skeleton_c gesetzt", SaveManager.is_killed(&"skeleton_c"))
	check("Speicherpunkt in C vorhanden",
		RoomManager.current_room().get_node_or_null("SavePoint") != null)
	check("Slot 1 mit dem Flag geschrieben", SaveManager.save_to_slot(1, &"save_c"))
	await transition(&"room_02", &"start")
	await transition(&"room_03", &"start")
	await physics(2)
	check("markierter Gegner bleibt weg",
		RoomManager.current_room().get_node_or_null("Waechter") == null)
	# Neues Spiel raeumt die Flags -> er steht wieder.
	SaveManager.new_game()
	await settle()
	check("game_restarted gemeldet", _restarted == 1, str(_restarted))
	check("Flags nach Neuanfang leer", SaveManager.flag_count() == 0,
		str(SaveManager.flag_count()))
	check("Spielzeit nach Neuanfang klein", SaveManager.playtime_frames() < 60,
		str(SaveManager.playtime_frames()))
	check("Neuanfang steht im Startraum", RoomManager.current_room_id() == &"room_01",
		str(RoomManager.current_room_id()))
	await transition(&"room_02", &"start")
	await transition(&"room_03", &"start")
	check("Gegner nach Neuanfang wieder da",
		RoomManager.current_room().get_node_or_null("Waechter") != null)
	# Und der Spielstand bringt das Flag zurueck.
	SaveManager.load_from_slot(1)
	await settle()
	check("Slot bringt das Flag zurueck", SaveManager.is_killed(&"skeleton_c"))
	check("und den Raum C", RoomManager.current_room_id() == &"room_03",
		str(RoomManager.current_room_id()))
	check("Gegner nach dem Laden wieder weg",
		RoomManager.current_room().get_node_or_null("Waechter") == null)
	check("Spieler auf dem Spawn save_c",
		player.global_position.is_equal_approx(Vector2(312, 128)), str(player.global_position))

	section("8. Game Over haelt die Welt an")
	check("Menue geschlossen, solange das Spiel laeuft", not menu.is_open())
	check("Raum laeuft", not RoomManager.is_room_frozen())
	check("Spieler verwundbar", not player.is_defeated() and player.hurtbox.monitorable)
	# In einem Raum MIT Gegner sterben, und zwar in dessen Aggro-Reichweite: nur ein Gegner, der
	# gerade laeuft, kann beweisen, dass er danach steht.
	await transition(&"room_02", &"start")
	var watcher: Skeleton = RoomManager.current_room().get_node("Skeleton")
	watcher.global_position = player.global_position + Vector2(40, 0)
	await physics(6)
	var moved: float = watcher.global_position.distance_to(player.global_position)
	await physics(6)
	check("Vorbedingung: Gegner ist in Bewegung",
		absf(watcher.global_position.distance_to(player.global_position) - moved) > 0.1,
		"%.2f px" % absf(watcher.global_position.distance_to(player.global_position) - moved))
	await down_active(player)
	await down_active(player)
	check("party_wiped gemeldet", _wiped)
	# DAS ist der Kern dieses Abschnitts: bis der Fix kam, lief der Raum hinter der Blende weiter
	# und das Skelett schlug auf die gefallene Figur ein — jeder Treffer feuerte erneut
	# `downed` -> `party_wiped`.
	check("Raum sofort eingefroren", RoomManager.is_room_frozen())
	check("Spieler als ausgefallen markiert", player.is_defeated())
	check("Input sofort gesperrt (nicht erst nach der Blende)", player.is_input_locked())
	await physics(2)
	check("Hurtbox nimmt nichts mehr an", not player.hurtbox.monitorable)
	var frozen_at: Vector2 = watcher.global_position
	var wipes_before: int = _wipe_count
	await physics(20)
	check("Gegner steht still", watcher.global_position.is_equal_approx(frozen_at),
		"%s -> %s" % [frozen_at, watcher.global_position])
	check("kein zweites party_wiped", _wipe_count == wipes_before,
		"%d -> %d" % [wipes_before, _wipe_count])
	await physics(fade.fade_frames + 3)
	check("Menue offen", menu.is_open())
	check("Bild ist schwarz", is_equal_approx(fade.alpha(), 1.0), "%.2f" % fade.alpha())
	check("Input beim Spieler gesperrt", player.is_input_locked())
	check("Speicherstand anwaehlbar", menu.can_load())
	check("Ladeeintrag vorausgewaehlt", menu.selected() == GameOverMenu.Option.LOAD,
		str(menu.selected()))
	await press(&"move_down")
	check("runter waehlt Neu beginnen", menu.selected() == GameOverMenu.Option.RESTART,
		str(menu.selected()))
	await press(&"move_up")
	check("hoch waehlt den Speicherstand", menu.selected() == GameOverMenu.Option.LOAD,
		str(menu.selected()))
	var loads_before: int = _loaded.size()
	await press(&"attack")
	check("Bestaetigen laedt", _loaded.size() == loads_before + 1, str(_loaded))
	check("Menue geschlossen", not menu.is_open())
	await settle()
	check("im Raum des Spielstands", RoomManager.current_room_id() == &"room_03",
		str(RoomManager.current_room_id()))
	check("beide Figuren stehen wieder", party.standing_count() == 2, str(party.standing_count()))
	check("Health voll", player.get_health() == player.stats.max_health,
		"%d/%d" % [player.get_health(), player.stats.max_health])
	check("Game-Over-Blende zurueckgenommen", is_zero_approx(fade.alpha()), "%.2f" % fade.alpha())
	check("Transitions-Blende offen", is_zero_approx(RoomManager.fade_alpha()))
	check("Input frei", not player.is_input_locked())
	check("Menue unsichtbar", not menu.visible)
	check("Raum laeuft wieder", not RoomManager.is_room_frozen())
	check("Spieler wieder verwundbar", not player.is_defeated() and player.hurtbox.monitorable)

	section("9. Game-Over-Menue: Neu beginnen")
	player.set_corruption(60.0)
	SaveManager.set_flag(&"vor_dem_neuanfang")
	_wiped = false
	await down_active(player)
	await down_active(player)
	await physics(fade.fade_frames + 3)
	check("Menue offen", menu.is_open())
	await press(&"move_down")
	check("Neu beginnen gewaehlt", menu.selected() == GameOverMenu.Option.RESTART)
	await press(&"interact")
	check("Menue geschlossen", not menu.is_open())
	await settle()
	check("game_restarted gemeldet", _restarted == 2, str(_restarted))
	check("im Startraum", RoomManager.current_room_id() == &"room_01",
		str(RoomManager.current_room_id()))
	check("am Startspawn",
		player.global_position.is_equal_approx(RoomManager.current_room().spawn_point(&"start")),
		str(player.global_position))
	check("beide Figuren stehen", party.standing_count() == 2, str(party.standing_count()))
	# Nach Phase 7: der Neuanfang MUSS die Korruption mitnehmen, sonst startet man auf Stufe 4.
	check("Korruption beider Figuren 0", is_zero_approx(player.get_corruption())
		and is_zero_approx(party.corruption_of(1)), "%.2f" % player.get_corruption())
	check("Flags geraeumt", not SaveManager.get_flag(&"vor_dem_neuanfang")
		and SaveManager.flag_count() == 0, str(SaveManager.flag_count()))
	check("Spielzeit von vorn", SaveManager.playtime_frames() < 120,
		str(SaveManager.playtime_frames()))
	check("Slot bleibt liegen (Neu beginnen loescht nicht)", SaveManager.has_slot(1))
	check("Input frei", not player.is_input_locked())

	section("10. Game Over ohne Spielstand")
	SaveManager.delete_slot(1)
	_wiped = false
	await down_active(player)
	await down_active(player)
	await physics(fade.fade_frames + 3)
	check("Menue offen", menu.is_open())
	check("Speicherstand nicht anwaehlbar", not menu.can_load())
	check("Neu beginnen vorausgewaehlt", menu.selected() == GameOverMenu.Option.RESTART,
		str(menu.selected()))
	await press(&"move_up")
	check("hoch bleibt auf Neu beginnen (leerer Slot)",
		menu.selected() == GameOverMenu.Option.RESTART, str(menu.selected()))
	await press(&"interact")
	await settle()
	check("Neuanfang trotzdem moeglich", RoomManager.current_room_id() == &"room_01"
		and not player.is_input_locked(), str(RoomManager.current_room_id()))

	# Testverzeichnis aufraeumen: ein Testlauf hinterlaesst keine Spielstaende.
	_wipe_dir()
	check("Testverzeichnis leer", not SaveManager.has_slot(1) and not SaveManager.has_slot(2)
		and not SaveManager.has_slot(3))

	print("\n%s (%d Fehler)" % ["ALLES GRUEN" if _fails == 0 else "FEHLER", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


## Eine Action einen Frame druecken und wieder loslassen. `is_action_just_pressed` liest den
## Flankenwechsel — ohne das Loslassen wuerde ein zweiter Druck nie erkannt.
func press(action: StringName) -> void:
	Input.action_press(action)
	await physics(2)
	Input.action_release(action)
	await physics(2)


## Ein vollstaendiger Raumwechsel inklusive Blende.
func transition(room_id: StringName, spawn_id: StringName) -> void:
	RoomManager.transition_to(room_id, spawn_id)
	await settle()


## Wartet, bis keine Transition mehr laeuft (plus zwei Frames fuer queue_free des alten Raums).
func settle() -> void:
	while RoomManager.is_transitioning():
		await get_tree().physics_frame
	await physics(2)


## Gegner erledigen und das Ende der Todesanimation abwarten (45 F, siehe states/dead.gd) —
## erst danach ist der Node aus dem Baum.
func kill(enemy: Skeleton) -> void:
	enemy.hurtbox.take_hit(enemy.get_health(), Vector2.ZERO)
	await physics(50)


## Die aktive Figur ausschalten. Auf das Ende der I-Frames warten ist Pflicht: sie ueberleben
## den Figurenwechsel (gleicher Player-Node, Phase 4) — der zweite Todesstoss prallte sonst
## stumm ab (Merker aus Phase 7).
func down_active(player: Player) -> void:
	while player.hurtbox.is_invulnerable():
		await get_tree().physics_frame
	player.hurtbox.take_hit(player.stats.max_health, Vector2.ZERO)
	await physics(4)


func _write_slot(slot: int, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var file: FileAccess = FileAccess.open(SaveManager.slot_path(slot), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _wipe_dir() -> void:
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)


func physics(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame
