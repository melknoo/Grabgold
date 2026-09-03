extends Node
## Headless-Verifikation Phase 6 (Ein echter Raum). Prueft, was sich ohne Bild pruefen laesst:
## solide Waende, Kamera-Limits, Gewichtsplatte, Zeittuer inkl. verzoegertem Schliessen, die
## Puzzle-Zahl (Distanz vs. Laufweite je Figur) und den Phase-Dash als Raum-Verb.
## Aufruf: $GODOT --headless --path . res://tests/phase6_sim.tscn
##
## Laeuft als SZENE, nicht per --script (siehe phase4/phase5_sim: bei --script fehlen die
## Autoloads und Hitbox/Hurtbox scheitern schon beim Kompilieren an `Debug`).

const PHYS_FPS := 60.0

var _fails: int = 0

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
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var player: Player = main.get_node("Player")
	var party: PartyManager = main.get_node("PartyManager")
	# Der Raum haengt seit Phase 8 nicht mehr fest in main.tscn, sondern wird vom RoomManager
	# in `RoomHost` instanziert.
	var room: Room01 = RoomManager.current_room() as Room01
	var door: Door = room.door
	var plate: PressurePlate = room.plate
	var skeleton: Skeleton = room.get_node("Skeleton")
	await physics(3)

	print("\n== 1. Der Raum steht ==")
	var bounds: Rect2i = room.bounds()
	check("Raum ist 640x384 px (doppelter Viewport)", bounds.size == Vector2i(640, 384), str(bounds.size))
	check("Spieler startet am Marker", player.global_position.is_equal_approx(room.spawn_point(&"start")),
		"%s" % player.global_position)
	check("Tuer ist zu", not door.is_open())
	check("Platte ist offen", not plate.is_pressed())

	print("\n== 2. Kamera ==")
	var cam: Camera2D = player.camera
	check("Kamera haengt am Player (ueberlebt den Figurenwechsel)", cam.get_parent() == player)
	check("Limits = Raumgrenzen",
		cam.limit_left == bounds.position.x and cam.limit_top == bounds.position.y
		and cam.limit_right == bounds.end.x and cam.limit_bottom == bounds.end.y,
		"%d,%d..%d,%d" % [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom])
	check("Position-Smoothing AUS (CLAUDE.md: sonst Tile-Seams)", not cam.position_smoothing_enabled)
	check("Limit-Smoothing AUS", not cam.limit_smoothed)

	print("\n== 3. Waende sind solide ==")
	# Gegen die linke Aussenwand laufen. Bis Phase 5 gab es nichts, was den Spieler aufhaelt.
	var wall_start: Vector2 = player.global_position
	Input.action_press(&"move_left")
	await physics(120)
	Input.action_release(&"move_left")
	await physics(5)
	var free_run: float = player.stats.max_speed * 120.0 / PHYS_FPS
	check("Spieler wird von der Wand gestoppt",
		wall_start.x - player.global_position.x < free_run - 20.0,
		"%.1f px statt %.1f px frei" % [wall_start.x - player.global_position.x, free_run])
	check("Spieler bleibt im Raum", player.global_position.x > float(bounds.position.x),
		"x=%.1f" % player.global_position.x)

	print("\n== 4. Die Platte wiegt: der Kurier ist zu leicht ==")
	check("Kurier ist aktiv", party.active_profile().stats.weight < plate.required_weight,
		"weight %.1f < %.1f" % [party.active_profile().stats.weight, plate.required_weight])
	await stand_on(player, plate, 60)
	check("Platte bleibt offen", not plate.is_pressed())
	check("Tuer bleibt zu", not door.is_open())

	print("\n== 5. Der Zwerg loest sie aus — im Stehen, ohne die Platte zu verlassen ==")
	# Genau der Fall, den `body_entered` NICHT sehen wuerde: der Player-Node bleibt derselbe,
	# nur sein Profil wechselt (Phase 4). Darum wertet die Platte jeden Frame die Ueberlappung aus.
	party.switch_next()
	await physics(5)
	check("Zwerg ist aktiv", party.active_profile().stats.weight >= plate.required_weight,
		"weight %.1f" % party.active_profile().stats.weight)
	check("Platte gibt nach — ohne neues body_entered", plate.is_pressed())
	check("Tuer ist offen", door.is_open())
	check("Tuer-Kollision ist aus", door.get_node("CollisionShape2D").disabled)

	print("\n== 6. Die Zeittuer laeuft ab ==")
	# Weg von der Tuer, damit sie ungehindert schliessen kann.
	player.global_position = room.spawn_point(&"start")
	await physics(door.open_frames + 6)
	check("Tuer ist wieder zu", not door.is_open())
	check("Tuer-Kollision ist wieder an", not door.get_node("CollisionShape2D").disabled)

	print("\n== 7. Die Tuer schliesst nicht auf dem Spieler ==")
	# Gegenstueck zum Phase-5-Maskentest: Zustand erst zuruecknehmen, wenn das Feld frei ist.
	door.open_for(30)
	await physics(2)
	player.global_position = door.global_position
	player.velocity = Vector2.ZERO
	await physics(60)
	check("Tuer bleibt offen, solange der Spieler drinsteht", door.is_open(),
		"Zaehler %d" % door.frames_left())
	player.global_position = room.spawn_point(&"start")
	await physics(6)
	check("Sobald das Feld frei ist, schliesst sie", not door.is_open())

	print("\n== 8. Die Puzzle-Zahl: das Fenster passt nur dem Kurier ==")
	var distance: float = room.plate_to_door_distance()
	var window_s: float = door.open_frames / PHYS_FPS
	var zwerg: TuningStats = load("res://resources/player_zwerg.tres")
	var kurier: TuningStats = load("res://resources/player_kurier.tres")
	var reach_zwerg: float = zwerg.max_speed * window_s
	var reach_kurier: float = kurier.max_speed * window_s
	print("  Distanz Platte->Tuer %.0f px, Fenster %.2f s" % [distance, window_s])
	check("Zwerg schafft die Strecke NICHT", reach_zwerg < distance,
		"%.0f px Reichweite < %.0f px" % [reach_zwerg, distance])
	check("Kurier schafft sie", reach_kurier > distance,
		"%.0f px Reichweite > %.0f px" % [reach_kurier, distance])
	check("Beide mit Reserve (kein Zufallsergebnis)",
		distance - reach_zwerg > 30.0 and reach_kurier - distance > 30.0,
		"Puffer %.0f / %.0f px" % [distance - reach_zwerg, reach_kurier - distance])

	print("\n== 9. Der Korridor: Phase-Dash geht durch Gegner, nicht durch Waende ==")
	if party.active_profile().stats.weight >= plate.required_weight:
		party.switch_next()  # zurueck auf den Kurier
		await physics(5)
	# a) Durch das Skelett im Korridor.
	skeleton.state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector2(420, 200)
	player.velocity = Vector2.ZERO
	player.facing = &"right"
	player.state_machine.transition_to(&"idle")
	skeleton.position = Vector2(456, 200)
	await physics(3)
	var dash_start: Vector2 = player.global_position
	await do_dash(player)
	var through: float = player.global_position.x - dash_start.x
	check("Dash traegt durch das Skelett hindurch", player.global_position.x > skeleton.position.x,
		"%.1f px, Gegner bei x=%.0f" % [through, skeleton.position.x])
	await physics(20)
	check("Maske kommt zurueck, obwohl der Korridor eng ist", not player.reif.is_phasing(),
		"mask=%d" % player.collision_mask)
	# b) Gegen eine Wand. Bit 1 bleibt in der Maske -> der Dash endet AN der Wand.
	skeleton.position = Vector2(3000, 3000)
	await physics(player.reif.stats.dash_cooldown_frames + 4)
	player.global_position = Vector2(520, 200)  # Korridor, Wand oberhalb bei y < 176
	player.velocity = Vector2.ZERO
	player.facing = &"up"
	player.state_machine.transition_to(&"idle")
	await physics(3)
	var wall_y: float = player.global_position.y
	var dash_reach: float = player.reif.stats.dash_speed * player.reif.stats.dash_frames / PHYS_FPS
	await do_dash(player)
	var travelled_up: float = wall_y - player.global_position.y
	check("Dash wird von der Wand gestoppt", travelled_up < dash_reach - 20.0,
		"%.1f px statt %.1f px frei" % [travelled_up, dash_reach])
	check("Spieler bleibt im Korridor (Wandkante y=176)", player.global_position.y >= 176.0,
		"y %.1f -> %.1f" % [wall_y, player.global_position.y])

	print("\n%s (%d Fehler)" % ["ALLES GRUEN" if _fails == 0 else "FEHLER", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


## Stellt den Spieler auf die Platte und laesst ihn dort N Frames stehen.
func stand_on(player: Player, plate: PressurePlate, frames: int) -> void:
	player.global_position = plate.global_position
	player.velocity = Vector2.ZERO
	player.state_machine.transition_to(&"idle")
	await physics(frames)


## Ein Phase-Dash. Merker aus Phase 5: die Taste muss ZWEI Physik-Frames gehalten werden — bei
## nur einem trifft Input.action_press das is_action_just_pressed-Fenster nicht zuverlaessig.
func do_dash(player: Player) -> void:
	Input.action_press(&"reif_channel")
	await physics(2)
	Input.action_press(&"dash")
	await physics(2)
	Input.action_release(&"dash")
	await physics(player.reif.stats.dash_frames + 4)
	Input.action_release(&"reif_channel")
	await physics(2)


func physics(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame
