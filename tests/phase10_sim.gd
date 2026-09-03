extends Node
## Headless-Verifikation Phase 10 (Audio). Prueft Busse, Bank, Abspiel-Mechanik (Dedup, Pool,
## Pitch, gehaltener Klang), die Musikverwaltung samt "gleiche ID startet nicht neu" und dass
## jedes Ereignis, das bisher stumm war, jetzt einen Klang anwirft.
## Aufruf: $GODOT --headless --path . res://tests/phase10_sim.tscn
##
## Laeuft als SZENE, nicht per --script (siehe phase4..9_sim: bei --script fehlen die Autoloads).
##
## ZWEI BETRIEBSARTEN, und das ist Absicht:
##  * Abschnitt 2 laeuft mit `AudioManager.enabled = true` und wirft echte Abspieler an — aber
##    ausschliesslich WAV-Effekte. Das ist der Nachweis, dass der Manager wirklich Ton macht.
##  * Alle anderen Abschnitte laufen STUMM. Grund ist die Musik: ein LAUFENDES Ogg laesst Godot
##    beim Beenden zwei Fehlerzeilen im Log stehen ("resources still in use" plus geleakte
##    Ogg-Instanzen) — Engine-Verhalten, in einem Projekt aus zwoelf Zeilen nachgestellt und auch
##    mit `stop()` kurz vor dem Ende nicht abstellbar. Die Buchfuehrung des Managers laeuft stumm
##    unveraendert weiter (`current_music`, `music_starts`, `play_count`, Dedup, Pitch), die
##    Verdrahtung ist also vollstaendig pruefbar, ohne dem Lauf Fehlerzeilen anzuhaengen.

## Notbremse (Muster aus phase9_sim): der Test wartet an mehreren Stellen auf Zustaende
## (Blenden, I-Frames, Todesanimation, Telegraph). Ein Fehler darin wuerde headless nicht
## fehlschlagen, sondern ewig laufen.
const FRAME_BUDGET := 6000

## Ein Schluck ueber die Schwelle — dieselbe Konstante wie in phase7_sim.
const OVER := 0.1

## Jede Klang-ID, die irgendeine Stelle im Spiel anwirft. Die Liste ist die Gegenprobe zur
## Tabelle im Bau-Tool: fehlt hier etwas in der Bank, ist das Ereignis im Spiel stumm und
## meldet nur einen Fehler ins Log, wenn es zufaellig eintritt.
const USED_SOUNDS: Array[StringName] = [
	&"attack_swing", &"hit_enemy", &"hit_player", &"enemy_dead", &"enemy_alert",
	&"dash", &"reif_loop", &"reif_compel", &"corruption_up",
	&"switch_figure", &"switch_refused", &"figure_down",
	&"plate_press", &"plate_release", &"door_move", &"save_point",
	&"menu_move", &"menu_confirm",
]

## Jede Musik-ID, die eine Szene oder der Bootstrap nennt.
const USED_MUSIC: Array[StringName] = [&"dungeon", &"crypt", &"game_over"]

var _fails: int = 0
var _frames: int = 0
var _section: String = "Aufbau"
var _done: bool = false

## Signal-Mitschriften als MEMBER, nicht als lokale Variablen in einem Lambda: GDScript faengt
## lokale Variablen `by value` ein (Merker aus Phase 7).
var _music_events: Array[StringName] = []
var _wiped: bool = false

func _on_music_changed(music_id: StringName) -> void:
	_music_events.append(music_id)

func _on_wiped() -> void:
	_wiped = true

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
	# Stumm in den Lauf hinein (Begruendung im Kopf). Abschnitt 2 schaltet kurz ein.
	AudioManager.enabled = false
	AudioManager.rng.seed = 20261002
	AudioManager.music_changed.connect(_on_music_changed)

	section("1. Busse und Bank")
	check("Bus Master vorhanden", AudioManager.has_bus(&"Master"))
	check("Bus Music vorhanden", AudioManager.has_bus(&"Music"))
	check("Bus SFX vorhanden", AudioManager.has_bus(&"SFX"))
	check("Musik liegt unter den Effekten",
		AudioManager.bus_db(&"Music") < AudioManager.bus_db(&"SFX"),
		"Music %.1f dB / SFX %.1f dB" % [AudioManager.bus_db(&"Music"),
			AudioManager.bus_db(&"SFX")])
	var bank: AudioBank = AudioManager.bank()
	check("Bank geladen", bank != null)
	for id: StringName in USED_SOUNDS:
		check("Bank kennt SFX '%s'" % id, bank.has_sound(id))
	for id: StringName in USED_MUSIC:
		check("Bank kennt Musik '%s'" % id, bank.has_music(id))
	check("Kampfklaenge sind variiert (attack_swing)", bank.variant_count(&"attack_swing") >= 2,
		str(bank.variant_count(&"attack_swing")))
	check("Kampfklaenge sind variiert (hit_enemy)", bank.variant_count(&"hit_enemy") >= 2,
		str(bank.variant_count(&"hit_enemy")))
	# Ueber viele Ziehungen muessen bei drei Varianten auch mehrere vorkommen — sonst waere die
	# Variation nur in der Bank und nicht im Ohr.
	var seen: Dictionary = {}
	for _i in 40:
		seen[bank.pick_sound(&"hit_enemy", AudioManager.rng)] = true
	check("Variantenauswahl greift wirklich", seen.size() >= 2, "%d verschiedene" % seen.size())
	check("Unbekannte ID liefert nichts", bank.pick_sound(&"gibtsnicht", AudioManager.rng) == null)

	section("2. Abspiel-Mechanik (mit Ton, nur WAV)")
	AudioManager.enabled = true
	await physics(1)
	var before: int = AudioManager.play_count(&"menu_move")
	check("play() meldet Erfolg", AudioManager.play(&"menu_move"))
	check("Zaehler gestiegen", AudioManager.play_count(&"menu_move") == before + 1)
	check("last_played gesetzt", AudioManager.last_played() == &"menu_move",
		str(AudioManager.last_played()))
	check("Ein Abspieler laeuft wirklich", AudioManager.active_sfx_count() >= 1,
		"%d aktiv" % AudioManager.active_sfx_count())
	# Dedup: zwei Gegner, die im selben Frame getroffen werden, sind zwei Aufrufe derselben ID.
	# Deckungsgleich addiert klingt das nach einem Knacken, nicht nach zwei Treffern.
	check("Zweiter Aufruf im GLEICHEN Frame wird verworfen", not AudioManager.play(&"menu_move"))
	check("Zaehler dabei unveraendert", AudioManager.play_count(&"menu_move") == before + 1)
	await physics(1)
	check("Naechsten Frame wieder erlaubt", AudioManager.play(&"menu_move"))
	check("Unbekannte ID meldet Fehlschlag", not AudioManager.play(&"gibtsnicht"))

	# Pool: der Manager darf unter Dauerfeuer keine Nodes nachlegen.
	var children_before: int = AudioManager.get_child_count()
	for i in 40:
		AudioManager.play(&"hit_enemy" if i % 2 == 0 else &"attack_swing")
		await physics(1)
	check("Pool waechst nicht", AudioManager.get_child_count() == children_before,
		"%d -> %d" % [children_before, AudioManager.get_child_count()])
	check("Pool hat die erwartete Groesse", AudioManager.pool_size() == AudioManager.POOL_SIZE)
	check("Nie mehr Abspieler aktiv als der Pool gross ist",
		AudioManager.active_sfx_count() <= AudioManager.pool_size())

	# Gehaltener Klang (der kanalisierende Reif).
	check("start_loop meldet Start", AudioManager.start_loop(&"reif_loop"))
	check("loop_id gesetzt", AudioManager.loop_id() == &"reif_loop")
	check("start_loop ist idempotent", not AudioManager.start_loop(&"reif_loop"))
	AudioManager.stop_loop()
	check("stop_loop raeumt auf", AudioManager.loop_id() == &"")
	check("Unbekannte Loop-ID meldet Fehlschlag", not AudioManager.start_loop(&"gibtsnicht"))

	AudioManager.enabled = false
	await physics(1)
	check("Stumm schaltet alle Abspieler ab", AudioManager.active_sfx_count() == 0,
		"%d aktiv" % AudioManager.active_sfx_count())

	section("3. Musik: Kreuzblende und kein Neustart")
	AudioManager.music_fade_frames = 10
	var starts0: int = AudioManager.music_starts()
	check("play_music meldet Start", AudioManager.play_music(&"dungeon"))
	check("current_music gesetzt", AudioManager.current_music() == &"dungeon")
	check("Blende laeuft", AudioManager.is_music_fading())
	check("Zaehler gestiegen", AudioManager.music_starts() == starts0 + 1)
	await physics(5)
	var mid: float = AudioManager.music_volume()
	check("Auf halber Blende halb laut", mid > 0.0 and mid < 1.0, "%.2f" % mid)
	await physics(8)
	check("Blende zu Ende", not AudioManager.is_music_fading())
	check("Voll aufgeblendet", is_equal_approx(AudioManager.music_volume(), 1.0),
		"%.2f" % AudioManager.music_volume())

	# DIE Kernregel der Musikverwaltung.
	check("GLEICHE ID startet nicht neu", not AudioManager.play_music(&"dungeon"))
	check("Zaehler dabei unveraendert", AudioManager.music_starts() == starts0 + 1)
	check("Auch keine Blende ausgeloest", not AudioManager.is_music_fading())

	check("Andere ID blendet ueber", AudioManager.play_music(&"crypt"))
	check("Zaehler gestiegen", AudioManager.music_starts() == starts0 + 2)
	check("Blende laeuft", AudioManager.is_music_fading())
	await physics(14)
	check("current_music ist crypt", AudioManager.current_music() == &"crypt")

	AudioManager.stop_music(0)
	check("stop_music raeumt die ID", AudioManager.current_music() == &"")
	check("Harter Schnitt blendet nicht", not AudioManager.is_music_fading())
	check("Leere ID stellt ab", not AudioManager.play_music(&""))
	check("Unbekannte Musik-ID meldet Fehlschlag", not AudioManager.play_music(&"gibtsnicht"))
	check("Unbekannter Jingle meldet Fehlschlag", not AudioManager.play_jingle(&"gibtsnicht"))
	check("music_changed wurde gemeldet", _music_events.size() >= 3,
		str(_music_events))

	section("4. Die Raumkette traegt die Musik")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var player: Player = main.get_node("Player")
	var party: PartyManager = main.get_node("PartyManager")
	var menu: GameOverMenu = main.get_node("GameOverMenu")
	RoomManager.fade_frames = 6
	# Eigenes, leeres Verzeichnis: der Lauf soll die Spielstaende des Entwicklers nicht anfassen
	# (Regel seit Phase 9).
	SaveManager.save_dir = "user://saves_phase10"
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)
	party.party_wiped.connect(_on_wiped)
	await physics(3)

	check("Startraum bringt sein Stueck mit", AudioManager.current_music() == &"dungeon",
		str(AudioManager.current_music()))
	var starts_a: int = AudioManager.music_starts()

	await transition(&"room_02", &"start")
	check("A -> B wechselt das Stueck", AudioManager.current_music() == &"crypt",
		str(AudioManager.current_music()))
	check("und wirft es an", AudioManager.music_starts() == starts_a + 1)

	# Der Fall, um den es geht: zwei Nachbarraeume mit demselben `music_id`. Ein Stueck, das an
	# jeder Tuer von vorn anfaengt, verraet die Raumgrenze und macht Herumlaufen unangenehm.
	await transition(&"room_03", &"start")
	check("B -> C laesst dasselbe Stueck LAUFEN",
		AudioManager.current_music() == &"crypt")
	check("und startet es NICHT neu", AudioManager.music_starts() == starts_a + 1,
		"%d Starts" % AudioManager.music_starts())
	await transition(&"room_02", &"from_c")
	check("C -> B ebenso", AudioManager.music_starts() == starts_a + 1)
	await transition(&"room_01", &"from_b")
	check("B -> A blendet zurueck auf dungeon", AudioManager.current_music() == &"dungeon")
	check("und wirft es wieder an", AudioManager.music_starts() == starts_a + 2)

	section("5. Der Kampf ist hoerbar")
	var room: Room01 = RoomManager.current_room() as Room01
	var enemy: Skeleton = room.get_node("Skeleton") as Skeleton
	var reif: Reif = player.reif

	var n: int = AudioManager.play_count(&"attack_swing")
	player.state_machine.transition_to(&"attack")
	await physics(2)
	check("Angriff schwingt hoerbar", AudioManager.play_count(&"attack_swing") == n + 1)

	# Die Klang-ID sitzt als Export an der Hitbox der jeweiligen Szene — der Trichter selbst
	# (components/hitbox.gd) weiss nicht, wer zuschlaegt.
	check("Player-Hitbox nennt hit_enemy", player.hitbox.hit_sound == &"hit_enemy",
		str(player.hitbox.hit_sound))
	check("Gegner-Hitbox nennt hit_player", enemy.hitbox.hit_sound == &"hit_player",
		str(enemy.hitbox.hit_sound))

	# Ein ECHTER Ueberlapp, nicht `hurtbox.take_hit` wie in den anderen Suiten: der Klang haengt
	# an der Hitbox, und ein direkter Aufruf der Hurtbox umgeht genau die Stelle, die geprueft
	# werden soll.
	player.global_position = enemy.global_position + Vector2(0.0, -8.0)
	player.facing = &"down"
	await physics(2)
	while enemy.hurtbox.is_invulnerable():
		await get_tree().physics_frame
	n = AudioManager.play_count(&"hit_enemy")
	player.enable_hitbox()
	await physics(4)
	player.disable_hitbox()
	check("Treffer auf den Gegner klingt", AudioManager.play_count(&"hit_enemy") == n + 1,
		"%d -> %d" % [n, AudioManager.play_count(&"hit_enemy")])

	# Invariante: der Klang haengt am GELANDETEN Treffer, nicht am Aufruf. Waehrend der I-Frames
	# prallt der Schlag ab — und ein Klang ohne Schaden waere eine Luege.
	check("Vorbedingung: Gegner hat I-Frames", enemy.hurtbox.is_invulnerable())
	n = AudioManager.play_count(&"hit_enemy")
	player.enable_hitbox()
	await physics(4)
	player.disable_hitbox()
	check("Abgeprallter Treffer bleibt STUMM",
		AudioManager.play_count(&"hit_enemy") == n, "%d" % AudioManager.play_count(&"hit_enemy"))

	# Andere Richtung durch denselben Trichter.
	while player.hurtbox.is_invulnerable():
		await get_tree().physics_frame
	enemy.face_toward(player.global_position)
	n = AudioManager.play_count(&"hit_player")
	enemy.enable_hitbox()
	await physics(4)
	enemy.disable_hitbox()
	check("Treffer auf den Spieler klingt anders",
		AudioManager.play_count(&"hit_player") == n + 1,
		"%d -> %d" % [n, AudioManager.play_count(&"hit_player")])

	# Telegraph und Tod des Gegners. Beide States betritt der Test direkt — die KI dorthin zu
	# fahren waere ein Test der KI, nicht des Tons.
	n = AudioManager.play_count(&"enemy_alert")
	enemy.state_machine.transition_to(&"telegraph")
	await physics(2)
	check("Telegraph warnt hoerbar", AudioManager.play_count(&"enemy_alert") == n + 1)

	# Die Zeitdehnung des Reifs muss im Pitch ankommen — sonst ist der verlangsamte Gegner nur
	# zu sehen, nicht zu hoeren.
	HitstopManager.set_time_scale(enemy.state_machine, reif.stats.time_scale)
	await physics(1)
	enemy.play_sound(&"enemy_alert")
	check("Verlangsamter Gegner klingt tiefer",
		is_equal_approx(AudioManager.last_pitch(), reif.stats.time_scale),
		"Pitch %.2f (erwartet %.2f)" % [AudioManager.last_pitch(), reif.stats.time_scale])
	HitstopManager.clear_time_scale(enemy.state_machine)
	await physics(1)
	enemy.play_sound(&"enemy_alert")
	check("Ungedehnter Gegner klingt normal",
		is_equal_approx(AudioManager.last_pitch(), 1.0), "%.2f" % AudioManager.last_pitch())

	n = AudioManager.play_count(&"enemy_dead")
	while enemy.hurtbox.is_invulnerable():
		await get_tree().physics_frame
	enemy.hurtbox.take_hit(enemy.get_health(), Vector2.ZERO)
	await physics(2)
	check("Der Tod des Gegners klingt", AudioManager.play_count(&"enemy_dead") == n + 1)

	section("6. Der Reif ist hoerbar")
	Input.action_press(&"reif_channel")
	await physics(3)
	check("Kanal summt (gehaltener Klang laeuft)", AudioManager.loop_id() == &"reif_loop",
		str(AudioManager.loop_id()))
	n = AudioManager.play_count(&"dash")
	player.state_machine.transition_to(&"dash")
	await physics(2)
	check("Dash zischt", AudioManager.play_count(&"dash") == n + 1)
	while player.state_machine.current_state.name == "Dash":
		await get_tree().physics_frame
	Input.action_release(&"reif_channel")
	await physics(3)
	check("Loslassen beendet den gehaltenen Klang", AudioManager.loop_id() == &"")

	# Der Kanal darf nicht durch eine Blende in den naechsten Raum summen (gleiche
	# Aufraeumpflicht wie bei der Zeitdehnung, Phase 8).
	Input.action_press(&"reif_channel")
	await physics(3)
	check("Vorbedingung: Kanal laeuft", AudioManager.loop_id() == &"reif_loop")
	player.set_input_locked(true)
	await physics(2)
	check("Input-Sperre schaltet den Kanal stumm", AudioManager.loop_id() == &"")
	player.set_input_locked(false)
	Input.action_release(&"reif_channel")
	await physics(2)

	# Stufe 3: der Reif schlaegt von selbst zu. Die Vorwarnung war bis Phase 9 rein visuell —
	# wer im Kampf auf den Gegner schaut, hat sie verpasst. Deterministisch statt gewuerfelt:
	# Wahrscheinlichkeit auf Anschlag (Muster aus phase7_sim).
	# Der Zaehler VOR dem Aufdrehen: mit der Wahrscheinlichkeit auf Anschlag feuert der Zwang
	# schon in den zwei Frames bis zur Vorbedingungspruefung.
	n = AudioManager.play_count(&"reif_compel")
	var tuned: ReifStats = reif.stats.duplicate()
	tuned.compulsion_per_second = 60.0  # ~1,0 pro Frame -> feuert sofort
	reif.stats = tuned
	player.set_corruption(tuned.level_thresholds[2] + OVER)
	player.state_machine.transition_to(&"idle")
	await physics(2)
	check("Vorbedingung: Stufe 3", reif.level() == 3, str(reif.level()))
	for _i in 40:
		await get_tree().physics_frame
		if reif.is_compelled():
			break
	check("Vorbedingung: Vorwarnung laeuft", reif.is_compelled())
	check("Die Vorwarnung des Zwangs warnt hoerbar",
		AudioManager.play_count(&"reif_compel") == n + 1,
		"%d -> %d" % [n, AudioManager.play_count(&"reif_compel")])
	# Die echten Werte zurueck, sonst schlaegt der Reif im Rest des Laufs jeden Frame zu.
	reif.stats = load("res://resources/reif.tres") as ReifStats
	player.set_corruption(0.0)
	await physics(tuned.compulsion_tell_frames + 4)

	# Eine neu erreichte Korruptionsstufe ist ein Ereignis, der Abbau ist keins.
	player.set_corruption(0.0)
	await physics(2)
	n = AudioManager.play_count(&"corruption_up")
	player.set_corruption(reif.stats.level_thresholds[0] + OVER)
	await physics(2)
	check("Neue Korruptionsstufe klingt", AudioManager.play_count(&"corruption_up") == n + 1)
	n = AudioManager.play_count(&"corruption_up")
	player.set_corruption(0.0)
	await physics(3)
	check("Sinkende Korruption bleibt stumm",
		AudioManager.play_count(&"corruption_up") == n)

	section("7. Ensemble, Raum und Speichern")
	# Wechsel auf eine KORRUMPIERTE Figur darf nicht nach "neue Stufe" klingen: die Figur hat
	# nichts erreicht, sie stand nur schon dort (dafuer gibt es `Reif.sync_level`).
	player.set_corruption(0.0)
	await physics(2)
	var idx: int = party.active_index()
	party.switch_next()
	await physics(2)
	player.set_corruption(reif.stats.level_thresholds[1] + OVER)  # Stufe 2 auf Figur B
	await physics(3)
	n = AudioManager.play_count(&"corruption_up")
	var m: int = AudioManager.play_count(&"switch_figure")
	party.switch_next()  # zurueck auf Figur A (Korruption 0)
	await physics(2)
	party.switch_next()  # wieder auf die korrumpierte Figur B
	await physics(3)
	check("Freiwilliger Wechsel klingt", AudioManager.play_count(&"switch_figure") == m + 2,
		"%d" % AudioManager.play_count(&"switch_figure"))
	check("Wechsel auf korrumpierte Figur klingt NICHT nach neuer Stufe",
		AudioManager.play_count(&"corruption_up") == n,
		"%d" % AudioManager.play_count(&"corruption_up"))

	# Stufe 4 sperrt den Wechsel — die Verweigerung war bis Phase 9 nur ein matter Flash.
	player.set_corruption(reif.stats.corruption_max)
	await physics(2)
	check("Vorbedingung: Wechsel gesperrt", reif.switch_locked())
	n = AudioManager.play_count(&"switch_refused")
	party.switch_next()
	await physics(2)
	check("Verweigerter Wechsel klingt", AudioManager.play_count(&"switch_refused") == n + 1)
	player.set_corruption(0.0)
	while party.active_index() != idx:
		party.switch_next()
		await physics(2)

	# Platte und Tuer. Die Platte reagiert auf GEWICHT, also muss der Zwerg drauf.
	n = AudioManager.play_count(&"plate_press")
	m = AudioManager.play_count(&"door_move")
	var heavy: int = _heaviest_figure(party)
	while party.active_index() != heavy:
		party.switch_next()
		await physics(2)
	player.global_position = room.plate.global_position
	await physics(4)
	check("Vorbedingung: Platte gedrueckt", room.plate.is_pressed())
	check("Platte klickt", AudioManager.play_count(&"plate_press") == n + 1)
	check("Tuer bewegt sich hoerbar", AudioManager.play_count(&"door_move") == m + 1)
	n = AudioManager.play_count(&"plate_release")
	player.global_position = room.spawn_point(&"start")
	await physics(4)
	check("Platte kommt hoerbar zurueck", AudioManager.play_count(&"plate_release") == n + 1)
	# Die Tuer schliesst nach `open_frames` — und ihr Zuschlagen ist derselbe Klang, tiefer.
	m = AudioManager.play_count(&"door_move")
	room.door.open_for(1)
	await physics(6)
	check("Tuer schliesst hoerbar", AudioManager.play_count(&"door_move") == m + 1)
	check("Zuschlagen klingt tiefer als Aufgehen",
		is_equal_approx(AudioManager.last_pitch(), room.door.CLOSE_PITCH),
		"Pitch %.2f" % AudioManager.last_pitch())

	# Speicherpunkt: schliesst einen offenen Punkt aus Phase 9 (Rueckmeldung war nur ein Flash).
	n = AudioManager.play_count(&"save_point")
	var save_point: SavePoint = room.get_node("SavePoint") as SavePoint
	player.global_position = save_point.global_position
	await physics(4)
	Input.action_press(&"interact")
	await physics(2)
	Input.action_release(&"interact")
	await physics(2)
	check("Vorbedingung: Slot geschrieben", SaveManager.has_slot(SaveManager.active_slot))
	check("Speichern bestaetigt sich hoerbar", AudioManager.play_count(&"save_point") == n + 1)

	section("8. Ausfall, Game Over und Menue")
	n = AudioManager.play_count(&"figure_down")
	await down_active(player)
	check("Ausgefallene Figur klingt", AudioManager.play_count(&"figure_down") == n + 1)
	check("Vorbedingung: noch kein Game Over", not _wiped)

	await down_active(player)
	check("Vorbedingung: Party ausgefallen", _wiped)
	# Der Jingle stellt das Stueck ab. Beides gleichzeitig ist Krach, und weiterlaufende
	# Dungeonmusik hinter dem Tod liest sich wie ein haengender Frame.
	check("Game Over stellt die Musik ab", AudioManager.current_music() == &"",
		str(AudioManager.current_music()))

	while not menu.is_open():
		await get_tree().physics_frame
	n = AudioManager.play_count(&"menu_move")
	menu.move_selection(1)
	await physics(1)
	check("Menue-Navigation klickt", AudioManager.play_count(&"menu_move") == n + 1)
	# Seit Phase 11 hat das Menue einen dritten Eintrag ("Hauptmenue"): der untere Rand der Liste
	# liegt eine Zeile tiefer als in Phase 10.
	menu.move_selection(1)
	await physics(1)
	n = AudioManager.play_count(&"menu_move")
	menu.move_selection(1)  # steht schon am unteren Rand
	await physics(1)
	check("Am Rand der Liste bleibt es still",
		AudioManager.play_count(&"menu_move") == n, "%d" % AudioManager.play_count(&"menu_move"))
	n = AudioManager.play_count(&"menu_confirm")
	menu.move_selection(-99)  # zurueck nach oben auf den Speicherstand
	await physics(1)
	menu.confirm()
	check("Bestaetigen klickt", AudioManager.play_count(&"menu_confirm") == n + 1)
	await settle()
	check("Nach dem Laden traegt der Raum wieder sein Stueck",
		AudioManager.current_music() == &"dungeon", str(AudioManager.current_music()))
	check("Der Jingle laeuft nicht unter der Raummusik weiter",
		not AudioManager.is_jingle_playing())

	section("9. Aufraeumen")
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)
	var left: int = 0
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		if SaveManager.has_slot(slot):
			left += 1
	check("Testverzeichnis leer", left == 0, "%d Slots uebrig" % left)
	# Der Lauf endet stumm — kein laufendes Ogg beim Beenden (Begruendung im Kopf).
	check("Lauf endet ohne Ton", not AudioManager.enabled)
	check("Kein Abspieler mehr aktiv", AudioManager.active_sfx_count() == 0)

	_done = true
	print("\n%s (%d Fehler)" % ["ALLES GRUEN" if _fails == 0 else "FEHLER", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


## Die schwerste Figur im Ensemble — die, die die Platte herunterdrueckt (Zwerg).
func _heaviest_figure(party: PartyManager) -> int:
	var best: int = 0
	var best_weight: float = -1.0
	for i in party.figures.size():
		var w: float = party.figures[i].stats.weight
		if w > best_weight:
			best_weight = w
			best = i
	return best


func transition(room_id: StringName, spawn_id: StringName) -> void:
	RoomManager.transition_to(room_id, spawn_id)
	await settle()


## Wartet, bis keine Transition mehr laeuft (plus zwei Frames fuer queue_free des alten Raums).
func settle() -> void:
	while RoomManager.is_transitioning():
		await get_tree().physics_frame
	await physics(2)


## Die aktive Figur ausschalten. Auf das Ende der I-Frames warten ist Pflicht: sie ueberleben
## den Figurenwechsel (gleicher Player-Node, Phase 4) — der zweite Todesstoss prallte sonst
## stumm ab (Merker aus Phase 7).
func down_active(player: Player) -> void:
	while player.hurtbox.is_invulnerable():
		await get_tree().physics_frame
	player.hurtbox.take_hit(player.stats.max_health, Vector2.ZERO)
	await physics(4)


func physics(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame
