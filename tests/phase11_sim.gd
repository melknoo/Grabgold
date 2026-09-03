extends Node
## Headless-Verifikation Phase 11 (Huelle: Hauptmenue, Slot-Auswahl, Optionen, Pause).
## Aufruf: $GODOT --headless --path . res://tests/phase11_sim.tscn
##
## Laeuft als SZENE, nicht per --script (siehe phase4..10_sim: bei --script fehlen die Autoloads).
##
## Diese Suite haengt `boot.tscn` als Kind unter sich — nicht `main.tscn` wie die sechs vorher.
## Genau darum geht es: die Weltszene ist seit dieser Phase nicht mehr der Startpunkt, sondern
## etwas, das die Huelle aufbaut und wieder wegwirft.
##
## WICHTIG, zwei Verzeichnisse:
##  * `SaveManager.save_dir` zeigt auf `user://saves_phase11` (Muster aus Phase 9, sonst
##    ueberschreibt ein Testlauf die echten Spielstaende).
##  * `Settings.path` zeigt auf eine eigene `.cfg` — aus demselben Grund. Der Autoload hat die
##    ECHTE Datei beim Hochkommen schon gelesen und angewandt; der Test setzt darum als Erstes
##    `reset()`, damit die Pegel deterministisch auf der Vorgabe des Mixes stehen.
##
## Ton ist aus (Phase 10: ein laufendes Ogg laesst Godot beim Beenden zwei Fehlerzeilen stehen,
## und das Hauptmenue wirft sofort ein Ogg an). Die Buchfuehrung des AudioManagers laeuft stumm
## unveraendert weiter — Abschnitt 11 schaltet fuer die Menue-Klaenge echten Ton ein, das sind
## ausschliesslich WAV.

const TEST_DIR := "user://saves_phase11"
const TEST_CFG := "user://settings_phase11.cfg"

var _fails: int = 0

## Signal-Mitschriften als MEMBER, nicht als lokale Variablen in einem Lambda: GDScript faengt
## lokale Variablen `by value` ein (Merker aus Phase 7).
var _settings_changed: int = 0
var _new_game: Array[int] = []
var _loads: Array[int] = []

func _on_settings_changed() -> void:
	_settings_changed += 1

func _on_new_game(slot: int) -> void:
	_new_game.append(slot)

func _on_load(slot: int) -> void:
	_loads.append(slot)

## Notbremse, gleicher Grund wie in phase9/phase10_sim: der Lauf wartet an vielen Stellen auf
## Blenden und Signale, und ein Fehler darin wuerde headless nicht fehlschlagen, sondern haengen.
const FRAME_BUDGET := 7000

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

func section(title: String) -> void:
	_section = title
	print("\n== %s ==" % title)
	printerr("-> %s" % title)

func check(label: String, ok: bool, detail: String = "") -> void:
	print("  %s %s%s" % ["[OK]  " if ok else "[FAIL]", label, ("  -> " + detail) if detail != "" else ""])
	if not ok:
		_fails += 1


func _ready() -> void:
	AudioManager.enabled = false
	SaveManager.save_dir = TEST_DIR
	Settings.path = TEST_CFG
	_wipe_saves()
	_wipe_cfg()
	Settings.reset()

	var boot: Boot = (load("res://scenes/boot.tscn") as PackedScene).instantiate() as Boot
	add_child(boot)
	var menu: MainMenu = boot.main_menu
	var pause: PauseMenu = boot.pause_menu
	var options: OptionsMenu = boot.options_menu
	# Kurze Blenden: der Test prueft Ablaeufe, nicht Feel-Dauern.
	RoomManager.fade_frames = 6
	AudioManager.music_fade_frames = 4
	Settings.changed.connect(_on_settings_changed)
	menu.new_game_requested.connect(_on_new_game)
	menu.load_requested.connect(_on_load)
	await physics(3)

	# --------------------------------------------------------------------------------------
	section("1. Einstellungen (Settings)")
	check("Drei Busse in fester Reihenfolge",
		Settings.BUSES.size() == 3 and Settings.BUSES[0] == &"Master"
		and Settings.BUSES[1] == &"Music" and Settings.BUSES[2] == &"SFX", str(Settings.BUSES))
	check("Nach reset() steht jeder Regler auf Vorgabe",
		Settings.volume_step(&"Master") == Settings.STEPS
		and Settings.volume_step(&"Music") == Settings.STEPS
		and Settings.volume_step(&"SFX") == Settings.STEPS)
	check("Vorgabe zeigt 100 %", Settings.volume_percent(&"Music") == 100,
		str(Settings.volume_percent(&"Music")))
	# Der Nullpunkt jedes Reglers ist die Mischung aus dem generierten Bus-Layout, nicht 0 dB:
	# Stufe 10 heisst "wie der Autor es gemischt hat" (Musik -9 dB, Phase 10).
	check("Stufe 10 = Pegel des Mixes (Master 0 dB)",
		is_equal_approx(Settings.db_for(&"Master"), 0.0), "%.2f" % Settings.db_for(&"Master"))
	check("Stufe 10 = Pegel des Mixes (Musik -9 dB)",
		is_equal_approx(Settings.db_for(&"Music"), -9.0), "%.2f" % Settings.db_for(&"Music"))
	check("Und er steht so auch im AudioServer",
		is_equal_approx(AudioManager.bus_db(&"Music"), -9.0), "%.2f" % AudioManager.bus_db(&"Music"))

	var expected_half: float = -9.0 + linear_to_db(0.5)
	_settings_changed = 0
	Settings.set_volume_step(&"Music", 5)
	check("Halbe Stufe halbiert die Amplitude, relativ zum Mix",
		is_equal_approx(Settings.db_for(&"Music"), expected_half),
		"%.2f vs %.2f" % [Settings.db_for(&"Music"), expected_half])
	check("Der AudioServer folgt sofort",
		is_equal_approx(AudioManager.bus_db(&"Music"), expected_half))
	check("50 % angezeigt", Settings.volume_percent(&"Music") == 50,
		str(Settings.volume_percent(&"Music")))
	check("changed gemeldet", _settings_changed == 1, str(_settings_changed))
	_settings_changed = 0
	Settings.set_volume_step(&"Music", 5)
	check("Derselbe Wert meldet nichts", _settings_changed == 0, str(_settings_changed))
	Settings.set_volume_step(&"Music", 0)
	check("Stufe 0 ist echte Stille, nicht -inf",
		is_equal_approx(Settings.db_for(&"Music"), Settings.SILENT_DB),
		"%.2f" % Settings.db_for(&"Music"))
	Settings.set_volume_step(&"Music", 99)
	check("Nach oben geklemmt", Settings.volume_step(&"Music") == Settings.STEPS,
		str(Settings.volume_step(&"Music")))
	Settings.set_volume_step(&"Music", -5)
	check("Nach unten geklemmt", Settings.volume_step(&"Music") == 0,
		str(Settings.volume_step(&"Music")))
	Settings.set_volume_step(&"SFX", 4)
	check("Datei liegt auf Platte", Settings.has_file())

	# Frisch von Platte lesen: der Wert muss den Weg raus und zurueck ueberleben.
	Settings.set_volume_step(&"Music", 7)
	Settings.set_volume_step(&"Master", 2)
	check("Vor dem Lesen: 2 / 7 / 4",
		Settings.volume_step(&"Music") == 7 and Settings.volume_step(&"Master") == 2
		and Settings.volume_step(&"SFX") == 4)
	check("load_from_disk() meldet Erfolg", Settings.load_from_disk())
	check("Werte unveraendert nach dem Lesen",
		Settings.volume_step(&"Music") == 7 and Settings.volume_step(&"Master") == 2
		and Settings.volume_step(&"SFX") == 4,
		"%d/%d/%d" % [Settings.volume_step(&"Master"), Settings.volume_step(&"Music"),
			Settings.volume_step(&"SFX")])
	# Eine kaputte Datei kostet hier eine Lautstaerke, kein Spiel — anders als beim Spielstand
	# (Phase 9) wird darum NICHT abgebrochen, sondern nur das uebernommen, was brauchbar ist.
	# `ConfigFile` ueberliest Zeilen, die es nicht versteht, und meldet trotzdem OK: entscheidend
	# ist also nicht der Rueckgabewert, sondern dass die laufenden Werte stehen bleiben.
	var f: FileAccess = FileAccess.open(TEST_CFG, FileAccess.WRITE)
	f.store_string("{ das ist kein ConfigFile")
	f.close()
	Settings.load_from_disk()
	check("Kaputte Datei laesst die laufenden Werte stehen",
		Settings.volume_step(&"Music") == 7 and Settings.volume_step(&"Master") == 2,
		"%d/%d" % [Settings.volume_step(&"Master"), Settings.volume_step(&"Music")])
	# Ein Schluessel mit unbrauchbarem Wert wird uebersprungen, die anderen kommen an.
	f = FileAccess.open(TEST_CFG, FileAccess.WRITE)
	f.store_line("[audio]")
	f.store_line("Master=6")
	f.store_line('Music="laut"')
	f.close()
	Settings.load_from_disk()
	check("Brauchbarer Wert kommt an", Settings.volume_step(&"Master") == 6,
		str(Settings.volume_step(&"Master")))
	check("Unbrauchbarer Wert wird uebersprungen, nicht auf 0 gesetzt",
		Settings.volume_step(&"Music") == 7, str(Settings.volume_step(&"Music")))
	check("Fehlender Schluessel laesst den laufenden Wert stehen",
		Settings.volume_step(&"SFX") == 4, str(Settings.volume_step(&"SFX")))
	_wipe_cfg()
	check("Fehlende Datei: Fehlschlag, keine Aenderung",
		not Settings.load_from_disk() and Settings.volume_step(&"Music") == 7)
	Settings.reset()
	check("reset() stellt die Vorgabe wieder her",
		Settings.volume_step(&"Music") == Settings.STEPS
		and is_equal_approx(AudioManager.bus_db(&"Music"), -9.0))

	# --------------------------------------------------------------------------------------
	section("2. Startzustand der Huelle")
	check("Hauptmenue offen", menu.is_open())
	check("Und sichtbar", menu.visible)
	check("Keine Welt", not boot.has_world())
	check("Kein Raum gebunden", not RoomManager.is_bound())
	check("Kein Pausenmenue", not pause.is_open())
	check("Keine Optionen", not options.is_open())
	check("Titelstueck laeuft", AudioManager.current_music() == &"title",
		str(AudioManager.current_music()))
	check("Erster Slot vorausgewaehlt", menu.selected() == 0, str(menu.selected()))
	check("Slot 1 zeigt 'leer'", menu.row_text(0).ends_with("leer"), menu.row_text(0))
	check("Slot 3 zeigt 'leer'", menu.row_text(2).ends_with("leer"), menu.row_text(2))
	check("Nichts zum Loeschen geladen", menu.armed_slot() == 0)
	# Ohne Welt hat die Pausentaste nichts zu pausieren.
	await tap(&"pause")
	check("pause ohne Welt tut nichts", not pause.is_open())
	check("Am oberen Listenrand passiert nichts", _no_move(menu, -1))
	menu.move_selection(99)
	check("Beenden ist der letzte Eintrag", menu.selected() == menu.quit_index(),
		"%d von %d" % [menu.selected(), menu.quit_index()])
	check("Am unteren Listenrand passiert nichts", _no_move(menu, 1))
	# Bestaetigt wird der Eintrag NICHT: `boot` haengt daran `get_tree().quit()`, und ein Test,
	# der sich hier selbst beendet, prueft die restlichen zehn Abschnitte nie. Geprueft wird die
	# Zustaendigkeit, nicht der Rueckzug aus dem Prozess.
	check("Beenden-Eintrag ist verdrahtet",
		menu.quit_requested.get_connections().size() > 0)

	# --------------------------------------------------------------------------------------
	section("3. Neues Spiel in Slot 2")
	menu.move_selection(-99)
	menu.move_selection(1)
	check("Slot 2 gewaehlt", menu.selected() == 1, str(menu.selected()))
	menu.confirm()
	check("new_game_requested(2)", str(_new_game) == "[2]", str(_new_game))
	await settle()
	check("Welt steht", boot.has_world())
	check("Hauptmenue zu", not menu.is_open() and not menu.visible)
	check("Raum gebunden", RoomManager.is_bound())
	check("Aktiver Slot ist 2", SaveManager.active_slot == 2, str(SaveManager.active_slot))
	check("Startraum betreten", RoomManager.current_room_id() == &"room_01",
		str(RoomManager.current_room_id()))
	check("Raummusik statt Titelstueck", AudioManager.current_music() == &"dungeon",
		str(AudioManager.current_music()))
	check("Input frei", not boot.world().player.is_input_locked())
	var t0: int = SaveManager.playtime_frames()
	await physics(5)
	check("Spielzeit laeuft", SaveManager.playtime_frames() > t0,
		"%d -> %d" % [t0, SaveManager.playtime_frames()])

	# --------------------------------------------------------------------------------------
	section("4. Speichern, Pause, zurueck ins Hauptmenue")
	check("Speichern in Slot 2", SaveManager.save_to_slot(2, &"start"))
	check("Slot 2 liegt auf Platte", SaveManager.has_slot(2))
	boot.open_pause()
	check("Pausenmenue offen", pause.is_open())
	check("Raum eingefroren", RoomManager.is_room_frozen())
	check("Player-Input gesperrt", boot.world().player.is_input_locked())
	check("'Weiter' vorausgewaehlt", pause.selected() == PauseMenu.Option.RESUME,
		str(pause.selected()))
	pause.move_selection(2)
	check("'Hauptmenue' gewaehlt", pause.selected() == PauseMenu.Option.MAIN_MENU)
	pause.confirm()
	await physics(3)
	check("Welt weggeworfen", not boot.has_world())
	check("Und abgemeldet", not RoomManager.is_bound())
	check("Hauptmenue wieder offen", menu.is_open())
	check("Pausenmenue zu", not pause.is_open())
	check("Titelstueck wieder da", AudioManager.current_music() == &"title",
		str(AudioManager.current_music()))
	check("Blende des Raumwechsels ist klar", is_zero_approx(RoomManager.fade_alpha()),
		"%.2f" % RoomManager.fade_alpha())
	check("Slot 2 zeigt jetzt Kopfdaten", menu.row_text(1).contains("room_01"), menu.row_text(1))
	check("Slot 1 bleibt leer", menu.row_text(0).ends_with("leer"), menu.row_text(0))

	# --------------------------------------------------------------------------------------
	section("5. Laden aus dem Hauptmenue")
	menu.move_selection(1)
	check("Slot 2 gewaehlt", menu.selected() == 1)
	menu.confirm()
	check("load_requested(2)", str(_loads) == "[2]", str(_loads))
	await settle()
	check("Welt steht", boot.has_world())
	check("Raum aus dem Spielstand", RoomManager.current_room_id() == &"room_01",
		str(RoomManager.current_room_id()))
	check("Hauptmenue zu", not menu.is_open())
	check("Input nach dem Aufbau frei", not boot.world().player.is_input_locked())

	# --------------------------------------------------------------------------------------
	section("6. Slot loeschen")
	boot.open_main_menu()
	await physics(3)
	menu.move_selection(1)
	menu.toggle_delete()
	check("Loeschung geladen", menu.armed_slot() == 2, str(menu.armed_slot()))
	check("Die Zeile fragt nach", menu.row_text(1).contains("loeschen?"), menu.row_text(1))
	menu.move_selection(1)
	check("Wegbewegen nimmt sie zurueck", menu.armed_slot() == 0)
	menu.move_selection(-1)
	menu.toggle_delete()
	menu.toggle_delete()
	check("Zweiter Druck bricht ab", menu.armed_slot() == 0)
	menu.toggle_delete()
	check("Wieder geladen", menu.armed_slot() == 2)
	menu.confirm()
	check("Slot 2 ist weg", not SaveManager.has_slot(2))
	check("Loeschung nicht mehr geladen", menu.armed_slot() == 0)
	check("Die Zeile zeigt 'leer'", menu.row_text(1).ends_with("leer"), menu.row_text(1))
	check("Kein Laden ausgeloest (der Druck galt der Loeschung)", str(_loads) == "[2]",
		str(_loads))
	menu.toggle_delete()
	check("Ein leerer Slot hat nichts zu loeschen", menu.armed_slot() == 0)
	menu.move_selection(2)
	check("Optionen-Eintrag erreicht", menu.selected() == menu.options_index())
	menu.toggle_delete()
	check("Loeschen wirkt nicht auf Optionen/Beenden", menu.armed_slot() == 0)

	# --------------------------------------------------------------------------------------
	section("7. Optionen aus dem Hauptmenue")
	menu.confirm()
	await physics(3)
	check("Optionen offen", options.is_open() and options.visible)
	check("Hauptmenue ausgeblendet", not menu.is_open() and not menu.visible)
	check("Erster Regler vorausgewaehlt", options.selected() == 0)
	check("Ein Regler je Bus plus Zurueck",
		options.back_index() == Settings.BUSES.size(), str(options.back_index()))
	_settings_changed = 0
	options.adjust(-1)
	check("Links senkt den ersten Regler", Settings.volume_step(&"Master") == Settings.STEPS - 1,
		str(Settings.volume_step(&"Master")))
	check("changed gemeldet", _settings_changed == 1)
	options.adjust(1)
	check("Rechts hebt ihn wieder", Settings.volume_step(&"Master") == Settings.STEPS)
	_settings_changed = 0
	options.adjust(1)
	check("Am Anschlag passiert nichts", _settings_changed == 0)
	options.move_selection(1)
	options.adjust(-3)
	check("Der zweite Regler ist die Musik", Settings.volume_step(&"Music") == Settings.STEPS - 3,
		str(Settings.volume_step(&"Music")))
	check("Master davon unberuehrt", Settings.volume_step(&"Master") == Settings.STEPS)
	options.move_selection(99)
	check("Zurueck ist der letzte Eintrag", options.selected() == options.back_index())
	_settings_changed = 0
	options.adjust(-1)
	check("Links/rechts auf 'Zurueck' ist ein No-Op", _settings_changed == 0)
	options.close()
	await physics(3)
	check("Optionen zu", not options.is_open())
	check("Hauptmenue wieder da", menu.is_open() and menu.visible)
	check("Und auf dem Eintrag 'Optionen'", menu.selected() == menu.options_index(),
		str(menu.selected()))
	Settings.reset()

	# --------------------------------------------------------------------------------------
	section("8. Pause und Optionen im laufenden Spiel")
	menu.move_selection(-99)
	menu.confirm()  # Slot 1, leer -> neues Spiel
	await settle()
	check("Neues Spiel in Slot 1", SaveManager.active_slot == 1 and boot.has_world())
	check("Nicht eingefroren", not RoomManager.is_room_frozen())
	await tap(&"pause")
	check("Die Pausentaste oeffnet", pause.is_open())
	check("Raum steht", RoomManager.is_room_frozen())
	var enemy_pos: Vector2 = _enemy_position()
	await physics(10)
	check("Und der Gegner bewegt sich nicht mehr", _enemy_position() == enemy_pos,
		"%s -> %s" % [enemy_pos, _enemy_position()])
	await tap(&"pause")
	check("Dieselbe Taste schliesst wieder", not pause.is_open())
	check("Raum laeuft", not RoomManager.is_room_frozen())
	check("Input frei", not boot.world().player.is_input_locked())

	boot.open_pause()
	pause.move_selection(1)
	check("'Optionen' gewaehlt", pause.selected() == PauseMenu.Option.OPTIONS)
	pause.confirm()
	await physics(3)
	check("Optionen offen", options.is_open())
	check("Pausenmenue ausgeblendet", not pause.is_open())
	check("Die Pause laeuft weiter: Raum steht", RoomManager.is_room_frozen())
	check("Und der Input bleibt gesperrt", boot.world().player.is_input_locked())
	# Die Musik laeuft in der Pause absichtlich weiter — sonst waere der Musikregler nicht zu
	# hoeren, waehrend man ihn zieht.
	check("Musik laeuft in der Pause", AudioManager.current_music() == &"dungeon",
		str(AudioManager.current_music()))
	options.move_selection(1)
	options.adjust(-2)
	check("Der Regler wirkt auch aus der Pause",
		is_equal_approx(AudioManager.bus_db(&"Music"), Settings.db_for(&"Music")))
	await tap(&"pause")
	check("Escape verlaesst die Optionen", not options.is_open())
	check("Zurueck im Pausenmenue", pause.is_open())
	check("Auf dem Eintrag, den man gedrueckt hat",
		pause.selected() == PauseMenu.Option.OPTIONS, str(pause.selected()))
	check("Die Welt steht immer noch", RoomManager.is_room_frozen())
	pause.move_selection(-1)
	pause.confirm()
	await physics(3)
	check("'Weiter' laesst die Welt wieder laufen", not RoomManager.is_room_frozen())
	check("Pausenmenue zu", not pause.is_open())
	check("Input frei", not boot.world().player.is_input_locked())
	Settings.reset()

	# --------------------------------------------------------------------------------------
	section("9. Wann die Pause NICHT aufgeht")
	RoomManager.transition_to(&"room_02", &"start")
	await physics(2)
	check("Vorbedingung: Raumwechsel laeuft", RoomManager.is_transitioning())
	await tap(&"pause")
	check("Nicht waehrend der Blende", not pause.is_open())
	await settle()
	check("Raum 02 erreicht", RoomManager.current_room_id() == &"room_02",
		str(RoomManager.current_room_id()))

	var world: World = boot.world()
	check("Vorbedingung: Pause ist erlaubt", world.accepts_pause())
	await _wipe_party(world)
	check("Party ausgefallen", not world.accepts_pause())
	await tap(&"pause")
	check("Nicht im Game Over", not pause.is_open())
	var gom: GameOverMenu = world.game_over_menu
	while not gom.is_open():
		await get_tree().physics_frame
	check("Game-Over-Menue offen", gom.is_open())
	await tap(&"pause")
	check("Auch nicht ueber dem Game-Over-Menue", not pause.is_open())

	# --------------------------------------------------------------------------------------
	section("10. Game-Over-Menue: dritter Eintrag")
	check("Slot 1 leer -> 'Neu beginnen' vorausgewaehlt",
		gom.selected() == GameOverMenu.Option.RESTART, str(gom.selected()))
	gom.move_selection(1)
	check("'Hauptmenue' erreichbar", gom.selected() == GameOverMenu.Option.MENU,
		str(gom.selected()))
	gom.move_selection(1)
	check("Und es ist der letzte Eintrag", gom.selected() == GameOverMenu.Option.MENU)
	gom.confirm()
	await physics(4)
	check("Welt weggeworfen", not boot.has_world())
	check("Hauptmenue offen", menu.is_open())
	check("Titelstueck laeuft", AudioManager.current_music() == &"title",
		str(AudioManager.current_music()))
	check("Kein Jingle darunter", not AudioManager.is_jingle_playing())

	# --------------------------------------------------------------------------------------
	section("11. Die Menues klingen (echter Ton, nur WAV)")
	AudioManager.enabled = true
	menu.move_selection(-99)
	var n: int = AudioManager.play_count(&"menu_move")
	menu.move_selection(1)
	await physics(1)
	check("Navigation klickt", AudioManager.play_count(&"menu_move") == n + 1,
		str(AudioManager.play_count(&"menu_move")))
	menu.move_selection(-1)
	await physics(1)
	n = AudioManager.play_count(&"menu_move")
	menu.move_selection(-1)
	await physics(1)
	check("Am Listenrand bleibt es still", AudioManager.play_count(&"menu_move") == n)
	n = AudioManager.play_count(&"menu_move")
	menu.toggle_delete()
	await physics(1)
	check("Loeschen auf einem leeren Slot bleibt still",
		AudioManager.play_count(&"menu_move") == n)
	menu.move_selection(menu.options_index())
	await physics(1)
	n = AudioManager.play_count(&"menu_confirm")
	menu.confirm()
	await physics(3)
	check("Bestaetigen klickt", AudioManager.play_count(&"menu_confirm") == n + 1)
	n = AudioManager.play_count(&"menu_move")
	options.adjust(-1)
	await physics(1)
	check("Der Regler klickt beim Verstellen", AudioManager.play_count(&"menu_move") == n + 1)
	n = AudioManager.play_count(&"menu_back")
	options.close()
	await physics(2)
	check("Zurueck aus den Optionen klingt nach Abbruch",
		AudioManager.play_count(&"menu_back") == n + 1)
	check("Ein Abspieler laeuft wirklich", AudioManager.active_sfx_count() > 0)
	AudioManager.enabled = false
	Settings.reset()
	# Ein Abspieler, der beim Prozessende noch laeuft, hinterlaesst im Log geleakte Playbacks
	# (Phase 10 — dort war es ein Ogg, es gilt genauso fuer WAV). `enabled = false` haelt sie an,
	# aber der AudioServer laesst sie erst ein paar Frames spaeter los. Also abwarten, statt die
	# Zeilen als "harmlos" zu erklaeren.
	var guard: int = 0
	while AudioManager.active_sfx_count() > 0 and guard < 120:
		guard += 1
		await get_tree().physics_frame
	await physics(30)

	# --------------------------------------------------------------------------------------
	section("12. Aufraeumen")
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)
	var left: int = 0
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		if SaveManager.has_slot(slot):
			left += 1
	check("Testverzeichnis leer", left == 0, "%d Slots uebrig" % left)
	_wipe_cfg()
	check("Test-Einstellungsdatei weg", not Settings.has_file())
	# Der Lauf endet stumm — kein laufendes Ogg beim Beenden (Begruendung im Kopf).
	check("Lauf endet ohne Ton", not AudioManager.enabled)
	check("Kein Abspieler mehr aktiv", AudioManager.active_sfx_count() == 0)

	_done = true
	print("\n%s (%d Fehler)" % ["ALLES GRUEN" if _fails == 0 else "FEHLER", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


## Bewegt sich die Auswahl NICHT? Prueft die Invariante "am Rand der Liste passiert nichts",
## die im ganzen Projekt daran haengt, dass dort auch nichts klingt.
func _no_move(menu: MainMenu, step: int) -> bool:
	var before: int = menu.selected()
	menu.move_selection(step)
	return menu.selected() == before


## Position des ersten Skeletts im laufenden Raum, oder ZERO. Der Nachweis, dass die Pause den
## Raum wirklich anhaelt und nicht nur den Input sperrt.
func _enemy_position() -> Vector2:
	var room: Room = RoomManager.current_room()
	if room == null:
		return Vector2.ZERO
	for child: Node in room.get_children():
		var skeleton := child as Skeleton
		if skeleton != null:
			return skeleton.global_position
	return Vector2.ZERO


## Jede Figur ausschalten, bis die Party ausfaellt. Auf das Ende der I-Frames warten ist
## Pflicht: sie ueberleben den Figurenwechsel (gleicher Player-Node, Phase 4).
func _wipe_party(world: World) -> void:
	var guard: int = 0
	while world.party.standing_count() > 0 and guard < 600:
		guard += 1
		var player: Player = world.player
		if player.hurtbox.is_invulnerable() or player.is_defeated():
			await get_tree().physics_frame
			continue
		player.hurtbox.take_hit(player.stats.max_health, Vector2.ZERO)
		await physics(3)
	await physics(3)


## Eine Taste antippen. Die Menues lesen den `Input`-Singleton per Polling (Projektmuster), ein
## Test kann sie damit ohne Eingabegeraet fahren.
func tap(action: StringName) -> void:
	Input.action_press(action)
	await physics(2)
	Input.action_release(action)
	await physics(2)


## Wartet, bis keine Transition mehr laeuft (plus Frames fuer queue_free des alten Raums).
func settle() -> void:
	await physics(2)
	while RoomManager.is_transitioning():
		await get_tree().physics_frame
	await physics(3)


func physics(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _wipe_saves() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		DirAccess.make_dir_recursive_absolute(TEST_DIR)
		return
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)


func _wipe_cfg() -> void:
	if FileAccess.file_exists(TEST_CFG):
		DirAccess.remove_absolute(TEST_CFG)
