extends Node
## Headless-Verifikation Phase 12 (Raum-Inhalt: Kampfkammer B, Gruftkammer C).
## Prueft die neue Geometrie beider Raeume, die Aufstellung darin, den Riegel (solide, oeffnet
## beim Raeumen, bleibt offen, steht im Spielstand), den Waechter (eigenes Sheet, eigene Stats,
## Knockback-Faktor, persistenter Tod) und dass nichts in einer Wand steht.
## Aufruf: $GODOT --headless --path . res://tests/phase12_sim.tscn
##
## Laeuft als SZENE, nicht per --script (siehe phase4..11_sim: bei --script fehlen die Autoloads).
##
## Eigenes Save-Verzeichnis (`user://saves_phase12`), damit der Lauf die echten Spielstaende des
## Entwicklers weder liest noch anfasst — dieselbe Regel wie phase8/9/10/11_sim.

const TEST_DIR := "user://saves_phase12"
const TILE := 16

var _fails: int = 0

## Notbremse: der Test wartet an mehreren Stellen auf Blenden und Bewegung; ein Fehler darin
## wuerde headless nicht fehlschlagen, sondern ewig laufen (Grund wie in phase9/10/11_sim).
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
	printerr("ABBRUCH: Frame-Budget (%d) erschoepft in Abschnitt %s." % [FRAME_BUDGET, _section])
	get_tree().quit(2)

## Abschnittsmarke. Zusaetzlich auf stderr, weil stdout bei Umleitung in eine Datei gepuffert
## wird — bei einem Haenger sieht man sonst nicht, wie weit der Lauf gekommen ist.
func section(title: String) -> void:
	_section = title
	print("\n== %s ==" % title)
	printerr("-> %s" % title)

func check(label: String, ok: bool, detail: String = "") -> void:
	print("  %s %s%s" % ["[OK]  " if ok else "[FAIL]", label, ("  -> " + detail) if detail != "" else ""])
	if not ok:
		_fails += 1


func _ready() -> void:
	# Kein Ton (Grund in phase8_sim: ein laufendes Ogg laesst Godot beim Beenden zwei
	# Fehlerzeilen stehen). MUSS vor `add_child` stehen — dort betritt der Bootstrap den
	# Startraum und wuerfe schon Musik an.
	AudioManager.enabled = false
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var player: Player = main.get_node("Player")
	RoomManager.fade_frames = 4
	SaveManager.save_dir = TEST_DIR
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)
	SaveManager.new_game()
	await settle()

	# ------------------------------------------------------------------------------------
	section("1. Geometrie: B ist ein Bildschirm, C ist die Gruft")
	await transition(&"room_02", &"start")
	var b: Room02 = RoomManager.current_room() as Room02
	check("Raum B ist ein Room02", b != null)
	check("B misst 20x12 Tiles", b.size_tiles == Vector2i(20, 12), str(b.size_tiles))
	check("B ist EIN Bildschirm (320x192 px)", b.bounds().size == Vector2i(320, 192),
		str(b.bounds().size))
	check("Kamera-Limits passen zu B", _camera_matches(player, b))
	check("B: Saeule oben links ist Wand", _is_wall(b, Vector2i(4, 3)))
	check("B: Saeule unten rechts ist Wand", _is_wall(b, Vector2i(13, 8)))
	check("B: die Mitte ist frei", not _is_wall(b, Vector2i(9, 5)))
	check("B: der Riegel-Gang ist zugemauert", _is_wall(b, Vector2i(17, 1))
		and _is_wall(b, Vector2i(18, 9)))
	# Zwei Tiles hoch, nicht eines: die Kollisionsbox des Spielers sitzt 4 px unter seinem
	# Ursprung — in einer ein Tile hohen Oeffnung muesste man beim Durchgehen zielen.
	check("B: die Oeffnung ist zwei Tiles hoch",
		not _is_wall(b, Vector2i(17, 5)) and not _is_wall(b, Vector2i(17, 6))
		and not _is_wall(b, Vector2i(18, 5)) and not _is_wall(b, Vector2i(18, 6)))
	check("B: und darueber/darunter zu", _is_wall(b, Vector2i(17, 4))
		and _is_wall(b, Vector2i(17, 7)))

	await transition(&"room_03", &"start")
	var c: Room03 = RoomManager.current_room() as Room03
	check("Raum C ist ein Room03", c != null)
	check("C misst 24x16 Tiles", c.size_tiles == Vector2i(24, 16), str(c.size_tiles))
	check("C misst 384x256 px", c.bounds().size == Vector2i(384, 256), str(c.bounds().size))
	check("Kamera-Limits passen zu C", _camera_matches(player, c))
	check("C: Korridor ist 2 Tiles hoch", not _is_wall(c, Vector2i(8, 7))
		and not _is_wall(c, Vector2i(8, 8)))
	check("C: und darueber/darunter Wand", _is_wall(c, Vector2i(8, 6))
		and _is_wall(c, Vector2i(8, 9)))
	check("C: Saeulen in der Halle", _is_wall(c, Vector2i(14, 4)) and _is_wall(c, Vector2i(15, 11)))
	check("C: die Halle ist begehbar", not _is_wall(c, Vector2i(18, 8)))

	# ------------------------------------------------------------------------------------
	section("2. Kampfkammer B: drei Skelette und ein geschlossener Riegel")
	await transition(&"room_02", &"start")
	b = RoomManager.current_room() as Room02
	var enemies: Array[Node] = _enemies_of(b)
	check("Drei Gegner stehen", enemies.size() == 3, str(enemies.size()))
	check("Alle drei leben", b.enemies_alive() == 3, str(b.enemies_alive()))
	var all_plain: bool = true
	for enemy: Node in enemies:
		if (enemy as Skeleton).persist_id != &"":
			all_plain = false
	# Die Regel aus Phase 8: normale Gegner respawnen. Der Riegel merkt sich den geraeumten
	# Raum, die Skelette tun es nicht.
	check("Keiner von ihnen ist persistent", all_plain)
	var gate: Door = b.gate
	var gate_tiles: int = 0
	for child: Node in b.get_children():
		if child is Door:
			gate_tiles += 1
	check("Der Riegel ist zwei Kacheln hoch", gate_tiles == 2, str(gate_tiles))
	check("Der Riegel steht", not gate.is_open() and not gate.is_held())
	check("Raum gilt als nicht geraeumt", not b.is_cleared())
	check("Kein Welt-Flag gesetzt", not SaveManager.get_flag(Room02.CLEARED_FLAG))
	# Solide, nicht nur optisch: der Weg vom Spawn `from_c` nach Osten ist versperrt.
	# `test_move` statt Hinlaufen — das prueft den Riegel und nicht die Gegner-KI.
	check("Der Riegel ist wirklich solide",
		player.test_move(Transform2D(0.0, Vector2(264, 88)), Vector2(32, 0)))
	check("Der Ausgang liegt dahinter",
		(b.get_node("ExitToC") as Node2D).global_position.x > gate.global_position.x)
	check("Der Weg zurueck nach A ist frei",
		not player.test_move(Transform2D(0.0, Vector2(56, 88)), Vector2(-24, 0)))

	# ------------------------------------------------------------------------------------
	section("3. Der Riegel faehrt hoch, wenn keiner mehr steht")
	var killed: int = 0
	for enemy: Node in enemies:
		var skeleton := enemy as Skeleton
		skeleton.hurtbox.take_hit(skeleton.get_health(), Vector2.ZERO)
		killed += 1
		await physics(2)
		if killed < 3:
			check("  Nach %d von 3 bleibt der Riegel zu" % killed, not gate.is_open())
	await physics(2)
	check("Nach dem dritten oeffnet er", gate.is_open())
	check("Und zwar beide Kacheln", _open_doors(b) == 2, str(_open_doors(b)))
	check("Und bleibt offen (kein Zaehler)", gate.is_held())
	check("Raum gilt als geraeumt", b.is_cleared())
	check("Welt-Flag gesetzt", SaveManager.get_flag(Room02.CLEARED_FLAG))
	await physics(90)
	check("Auch 90 Frames spaeter noch offen", gate.is_open() and gate.is_held())
	check("Der Weg nach Osten ist frei",
		not player.test_move(Transform2D(0.0, Vector2(264, 88)), Vector2(32, 0)))

	# Und der Spieler kommt jetzt auch wirklich durch — zu Fuss, nicht per transition_to.
	player.global_position = Vector2(248, 88)
	await physics(2)
	Input.action_press(&"move_right")
	var walked: int = 0
	while not RoomManager.is_transitioning() and walked < 120:
		walked += 1
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	check("Hinauslaufen loest den Wechsel aus", RoomManager.is_transitioning(),
		"%d Frames" % walked)
	await settle()
	check("Und man steht in C", RoomManager.current_room_id() == &"room_03",
		str(RoomManager.current_room_id()))

	# ------------------------------------------------------------------------------------
	section("4. Gruftkammer C: der Waechter steht vor dem Speicherpunkt")
	c = RoomManager.current_room() as Room03
	var guard: Skeleton = c.get_node("Waechter") as Skeleton
	var save_point: SavePoint = c.get_node("SavePoint") as SavePoint
	check("Der Waechter ist eine Skeleton-Maschine", guard != null)
	check("Er traegt eigene Stats", guard.stats.resource_path.ends_with("enemy_waechter.tres"),
		guard.stats.resource_path)
	check("Er haelt mehr aus als ein Skelett", guard.stats.max_health == 9,
		str(guard.stats.max_health))
	check("Er schlaegt haerter zu", guard.stats.attack_damage == 2, str(guard.stats.attack_damage))
	check("Er telegrafiert laenger", guard.telegraph_frames > 30, str(guard.telegraph_frames))
	check("Er bleibt tot (persist_id)", guard.persist_id == &"skeleton_c", str(guard.persist_id))
	var guard_frames: SpriteFrames = guard.sprite.sprite_frames
	check("Er hat ein eigenes Sheet",
		guard_frames.resource_path.ends_with("skeleton_demon_frames.tres"),
		guard_frames.resource_path)
	var atlas: AtlasTexture = guard_frames.get_frame_texture(&"idle_down", 0) as AtlasTexture
	check("Und das Sheet kommt aus dem Pack-Ordner SkeletonDemon",
		atlas != null and atlas.atlas.resource_path.contains("SkeletonDemon"),
		atlas.atlas.resource_path if atlas != null else "-")
	# Der Bau ueber ein Tool ist nur dann etwas wert, wenn beide Gegner denselben Vertrag
	# erfuellen — `states/dead.gd` spielt z.B. das richtungslose "dead".
	var plain_frames: SpriteFrames = load("res://resources/skeleton_frames.tres") as SpriteFrames
	check("Beide Gegner-Sheets haben dieselben 13 Animationen",
		guard_frames.get_animation_names() == plain_frames.get_animation_names(),
		str(guard_frames.get_animation_names().size()))
	check("Darunter das richtungslose dead", guard_frames.has_animation(&"dead"))

	check("Der Speicherpunkt liegt HINTER dem Waechter",
		save_point.global_position.x > guard.global_position.x,
		"%s / %s" % [save_point.global_position, guard.global_position])
	check("Und der Waechter hinter dem Korridor", guard.global_position.x > 192.0,
		str(guard.global_position))
	check("Der Spawn save_c liegt beim Speicherpunkt",
		c.spawn_point(&"save_c").distance_to(save_point.global_position) <= 24.0,
		str(c.spawn_point(&"save_c")))
	check("Debug-Zeile nennt seine Health", c.debug_text().begins_with("Waechter 9/9"),
		c.debug_text())

	# Der Knockback-Faktor: bis Phase 11 las ihn nur der Player.
	check("Waechter weicht kaum zurueck", guard.stats.knockback_taken_scale < 1.0,
		str(guard.stats.knockback_taken_scale))
	guard.hurtbox.take_hit(1, Vector2(200.0, 0.0))
	check("  200 px/s Knockback werden zu %.0f" % (200.0 * guard.stats.knockback_taken_scale),
		is_equal_approx(guard.velocity.x, 200.0 * guard.stats.knockback_taken_scale),
		"%.1f" % guard.velocity.x)
	check("  und er hat einen Treffer weniger", guard.get_health() == 8, str(guard.get_health()))

	# ------------------------------------------------------------------------------------
	section("5. Zurueck nach B: der Riegel bleibt offen, die Gegner kommen wieder")
	await transition(&"room_02", &"from_c")
	b = RoomManager.current_room() as Room02
	check("Der Riegel steht schon beim Betreten offen", b.gate.is_open() and b.gate.is_held())
	check("Raum gilt weiter als geraeumt", b.is_cleared())
	check("Die drei Skelette sind zurueck", b.enemies_alive() == 3, str(b.enemies_alive()))
	check("Der Spawn from_c liegt IM Raum, nicht hinter dem Riegel",
		b.spawn_point(&"from_c").x < b.gate.global_position.x,
		str(b.spawn_point(&"from_c")))
	check("Debug-Zeile nennt Riegel und Gegner", b.debug_text() == "Riegel OFFEN  Gegner 3",
		b.debug_text())

	# ------------------------------------------------------------------------------------
	section("6. Der geraeumte Raum steht im Spielstand")
	check("Slot 1 geschrieben", SaveManager.save_to_slot(1, &"start"))
	SaveManager.new_game()
	await settle()
	check("Neues Spiel raeumt das Flag ab", not SaveManager.get_flag(Room02.CLEARED_FLAG))
	await transition(&"room_02", &"start")
	b = RoomManager.current_room() as Room02
	check("Und der Riegel ist wieder zu", not b.gate.is_open())
	check("Raum gilt wieder als nicht geraeumt", not b.is_cleared())
	SaveManager.load_from_slot(1)
	await settle()
	check("Der Spielstand bringt Raum B zurueck", RoomManager.current_room_id() == &"room_02",
		str(RoomManager.current_room_id()))
	check("  samt Flag", SaveManager.get_flag(Room02.CLEARED_FLAG))
	b = RoomManager.current_room() as Room02
	check("  und der Riegel steht offen", b.gate.is_open() and b.gate.is_held())

	# ------------------------------------------------------------------------------------
	section("7. Nichts steht in einer Wand")
	for room_id: StringName in [&"room_01", &"room_02", &"room_03"]:
		await transition(room_id, &"start")
		_check_placements(RoomManager.current_room())

	print("\n%s (%d Fehler)" % ["ALLES GRUEN" if _fails == 0 else "FEHLER", _fails])
	_done = true
	_cleanup()
	get_tree().quit(1 if _fails > 0 else 0)


## Steht auf dieser Zelle eine Wandkachel? Gefragt wird die generierte `Walls`-Ebene des Raums —
## die einzige Quelle der Wahrheit ueber das Layout (die Rechtecke im Bau-Tool sind nur ihr
## Rezept).
func _is_wall(room: Room, cell: Vector2i) -> bool:
	var walls: TileMapLayer = room.get_node("Tiles/Walls") as TileMapLayer
	return walls.get_cell_source_id(cell) != -1


## Alles, was im Raum auf einer Position steht, muss auf Boden stehen. Ein Gegner oder ein
## Spawn-Punkt in einer Wand faellt im Spielen sofort auf, headless aber nie — ausser hier.
func _check_placements(room: Room) -> void:
	var bad: Array[String] = []
	for child: Node in room.get_children():
		var node := child as Node2D
		if node == null or node.name == "Tiles":
			continue
		var cell := Vector2i((node.global_position / float(TILE)).floor())
		if _is_wall(room, cell):
			bad.append("%s%s" % [node.name, cell])
	check("%s: alles steht auf Boden" % room.room_id, bad.is_empty(), ", ".join(bad))


## Wie viele Riegel-Kacheln stehen offen? Beide muessen es sein — eine offene und eine
## geschlossene Haelfte waere genau die Oeffnung, durch die man zielen muss.
func _open_doors(room: Room) -> int:
	var open_count: int = 0
	for child: Node in room.get_children():
		var door := child as Door
		if door != null and door.is_open():
			open_count += 1
	return open_count


func _camera_matches(player: Player, room: Room) -> bool:
	var bounds: Rect2i = room.bounds()
	var cam: Camera2D = player.camera
	return cam.limit_left == bounds.position.x and cam.limit_top == bounds.position.y \
		and cam.limit_right == bounds.end.x and cam.limit_bottom == bounds.end.y


## Die Gegner eines Raums als Liste. Typ `Array[Node]`, nicht `Array[Skeleton]`: nach dem
## Erledigen sind die Eintraege freigegebene Instanzen, und die Zuweisung an einen typisierten
## Platz ist selbst schon der Fehler (CLAUDE.md > Regel Null).
func _enemies_of(room: Room) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in room.get_children():
		if child is Skeleton:
			found.append(child)
	return found


func _cleanup() -> void:
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)
	DirAccess.remove_absolute(TEST_DIR)


func transition(room_id: StringName, spawn_id: StringName) -> void:
	RoomManager.transition_to(room_id, spawn_id)
	await settle()


func settle() -> void:
	while RoomManager.is_transitioning():
		await get_tree().physics_frame
	await physics(2)


func physics(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame
