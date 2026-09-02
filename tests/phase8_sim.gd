extends Node
## Headless-Verifikation Phase 8 (Raumwechsel + Transition). Prueft die Kette A<->B<->C, die
## Freigabe des alten Raums, die Kamera-Limits je Raum, die Input-Sperre waehrend der Blende,
## den Gegner-Respawn und den Game-Over-Neustart ueber den RoomManager.
## Aufruf: $GODOT --headless --path . res://tests/phase8_sim.tscn
##
## Laeuft als SZENE, nicht per --script (siehe phase4..7_sim: bei --script fehlen die Autoloads).

var _fails: int = 0

## Signal-Mitschriften als MEMBER, nicht als lokale Variablen in einem Lambda: GDScript faengt
## lokale Variablen `by value` ein (Merker aus Phase 7).
var _changed_to: Array[StringName] = []
var _finished: int = 0
var _wiped: bool = false
## Alpha der Blende im Moment des Raumtauschs.
var _alpha_at_change: float = -1.0

func _on_room_changed(room_id: StringName) -> void:
	_changed_to.append(room_id)
	_alpha_at_change = RoomManager.fade_alpha()

func _on_transition_finished() -> void:
	_finished += 1

func _on_wiped() -> void:
	_wiped = true

func check(label: String, ok: bool, detail: String = "") -> void:
	print("  %s %s%s" % ["[OK]  " if ok else "[FAIL]", label, ("  -> " + detail) if detail != "" else ""])
	if not ok:
		_fails += 1

func _ready() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var host: Node2D = main.get_node("RoomHost")
	var player: Player = main.get_node("Player")
	var party: PartyManager = main.get_node("PartyManager")
	var game_over: GameOverFade = main.get_node("GameOverFade")
	var menu: GameOverMenu = main.get_node("GameOverMenu")
	# Kurze Blende: der Test prueft den Ablauf, nicht die Feel-Dauer (die liegt bei 18 F).
	RoomManager.fade_frames = 6
	# Seit Phase 9 haengt am Game Over ein Menue, und dessen Angebot haengt am aktiven Slot.
	# Eigenes, leeres Verzeichnis: der Lauf soll nicht von den Spielstaenden des Entwicklers
	# abhaengen und keine davon anfassen.
	SaveManager.save_dir = "user://saves_phase8"
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)
	RoomManager.room_changed.connect(_on_room_changed)
	RoomManager.transition_finished.connect(_on_transition_finished)
	party.party_wiped.connect(_on_wiped)
	await physics(3)

	print("\n== 1. Startzustand: Raum A steht ==")
	check("RoomManager gebunden", RoomManager.is_bound())
	check("Startraum ist room_01", RoomManager.current_room_id() == &"room_01",
		str(RoomManager.current_room_id()))
	check("Genau ein Raum in RoomHost", host.get_child_count() == 1, str(host.get_child_count()))
	check("Raum ist ein Room01", RoomManager.current_room() is Room01)
	check("Spieler am Spawn start",
		player.global_position.is_equal_approx(RoomManager.current_room().spawn_point(&"start")),
		str(player.global_position))
	check("Keine Transition", not RoomManager.is_transitioning())
	check("Blende offen", is_zero_approx(RoomManager.fade_alpha()))
	_check_camera(player, RoomManager.current_room(), "A")

	print("\n== 2. Kette A -> B -> C -> B -> A ==")
	var seen_rooms: Array[Node] = []
	for step: Array in [
		[&"room_02", &"start", Vector2(56, 88)],
		[&"room_03", &"start", Vector2(56, 88)],
		[&"room_02", &"from_c", Vector2(264, 88)],
		[&"room_01", &"from_b", Vector2(568, 184)],
	]:
		var previous: Node = RoomManager.current_room()
		seen_rooms.append(previous)
		await transition(step[0], step[1])
		var room: Room = RoomManager.current_room()
		check("in %s angekommen" % step[0], RoomManager.current_room_id() == step[0],
			str(RoomManager.current_room_id()))
		check("  Spieler auf Spawn %s" % step[1], player.global_position.is_equal_approx(step[2]),
			str(player.global_position))
		check("  genau ein Raum in RoomHost", host.get_child_count() == 1, str(host.get_child_count()))
		check("  alter Raum freigegeben", not is_instance_valid(previous))
		check("  Blende wieder offen", is_zero_approx(RoomManager.fade_alpha()))
		check("  Raumtausch lag bei Alpha 1.0", is_equal_approx(_alpha_at_change, 1.0),
			"%.3f" % _alpha_at_change)
		_check_camera(player, room, str(step[0]))
	check("room_changed 4x gemeldet", _changed_to.size() == 4, str(_changed_to))
	check("transition_finished 4x gemeldet", _finished == 4, str(_finished))

	print("\n== 3. Party-Zustand ueberlebt den Wechsel ==")
	# Erst Zustand aufbauen: Health senken, auf den Zwerg wechseln, Korruption auflegen.
	player.set_health(player.get_health() - 2)
	party.switch_next()
	await physics(2)
	player.set_corruption(37.5)
	var hp_before: int = player.get_health()
	var corr_before: float = player.get_corruption()
	var index_before: int = party.active_index()
	var figure_before: String = player.profile.display_name
	check("Vorbedingung: zweite Figur aktiv", index_before == 1, str(index_before))
	await transition(&"room_02", &"start")
	await transition(&"room_01", &"from_b")
	check("HP unveraendert", player.get_health() == hp_before,
		"%d -> %d" % [hp_before, player.get_health()])
	# Nicht "unveraendert": der Reif baut jeden Frame ab (0.4/s), auch hinter der Blende — das ist
	# gewollt. Geprueft wird, dass der Wert die Raeume UEBERLEBT und nur um den regulaeren Abbau
	# der verstrichenen Frames sinkt, nicht zurueckgesetzt wird.
	var decayed: float = corr_before - player.get_corruption()
	check("Korruption ueberlebt (nur regulaerer Abbau)", decayed >= 0.0 and decayed < 1.0,
		"%.2f -> %.2f (-%.2f)" % [corr_before, player.get_corruption(), decayed])
	check("aktive Figur unveraendert", party.active_index() == index_before
		and player.profile.display_name == figure_before, player.profile.display_name)
	player.set_corruption(0.0)
	party.switch_next()
	await physics(2)

	print("\n== 4. Input gesperrt waehrend der Blende ==")
	var start_pos: Vector2 = player.global_position
	RoomManager.transition_to(&"room_02", &"start")
	await physics(1)
	check("Transition laeuft", RoomManager.is_transitioning())
	check("Input gesperrt", player.is_input_locked())
	var index_at_lock: int = party.active_index()
	Input.action_press(&"move_right")
	Input.action_press(&"attack")
	Input.action_press(&"reif_channel")
	Input.action_press(&"switch_figure")
	await physics(2)
	Input.action_press(&"dash")
	await physics(2)
	check("keine Bewegung", player.global_position.distance_to(start_pos) < 0.01,
		"%.2f px" % player.global_position.distance_to(start_pos))
	check("Zustand bleibt neutral (kein Angriff/Dash)", player.is_neutral(),
		player.state_machine.current_state.name)
	check("Kein Kanal, keine Korruption", not player.reif.is_channeling()
		and is_zero_approx(player.get_corruption()), "%.2f" % player.get_corruption())
	check("Figur wechselt nicht", party.active_index() == index_at_lock, str(party.active_index()))
	for action: StringName in [&"move_right", &"attack", &"reif_channel", &"switch_figure", &"dash"]:
		Input.action_release(action)
	await settle()
	check("nach der Transition wieder frei", not player.is_input_locked()
		and not RoomManager.is_transitioning())
	# Gegenprobe: dieselbe Eingabe wirkt jetzt.
	var free_pos: Vector2 = player.global_position
	Input.action_press(&"move_right")
	await physics(10)
	Input.action_release(&"move_right")
	check("Bewegung nach Freigabe wieder moeglich", player.global_position.x > free_pos.x + 5.0,
		"%.1f px" % (player.global_position.x - free_pos.x))
	await physics(10)

	print("\n== 5. Blende erreicht voll schwarz ==")
	var max_alpha: float = 0.0
	RoomManager.transition_to(&"room_03", &"start")
	while RoomManager.is_transitioning():
		max_alpha = maxf(max_alpha, RoomManager.fade_alpha())
		await get_tree().physics_frame
	check("Blende erreicht voll schwarz", is_equal_approx(max_alpha, 1.0), "%.3f" % max_alpha)
	check("Raumtausch bei Alpha 1.0", is_equal_approx(_alpha_at_change, 1.0), "%.3f" % _alpha_at_change)
	await physics(2)
	check("Blende danach wieder 0", is_zero_approx(RoomManager.fade_alpha()))

	print("\n== 6. Gegner respawnen beim Betreten ==")
	await transition(&"room_02", &"start")
	var skeleton: Skeleton = RoomManager.current_room().get_node("Skeleton")
	var full_hp: int = skeleton.get_health()
	skeleton.hurtbox.take_hit(full_hp, Vector2.ZERO)
	await physics(4)
	check("Skelett in B ist erledigt",
		not is_instance_valid(skeleton) or skeleton.get_health() == 0)
	await transition(&"room_03", &"start")
	await transition(&"room_02", &"from_c")
	var respawned: Skeleton = RoomManager.current_room().get_node_or_null("Skeleton") as Skeleton
	check("Skelett in B ist wieder da", respawned != null)
	check("  und hat volle Health", respawned != null and respawned.get_health() == full_hp,
		str(respawned.get_health()) if respawned != null else "-")
	check("  und ist eine neue Instanz", respawned != skeleton)

	print("\n== 7. Die Raum-Tuer loest selbst aus ==")
	# Bisher hat der Test `transition_to` direkt gerufen. Hier laeuft der Weg, den der Spieler
	# nimmt: in den Trigger hinein.
	var exit_to_c: RoomExit = RoomManager.current_room().get_node("ExitToC")
	check("Tuer steht auf auto_enter", exit_to_c.auto_enter)
	player.global_position = exit_to_c.global_position
	await physics(3)
	check("Betreten loest die Transition aus", RoomManager.is_transitioning())
	await settle()
	check("in room_03 angekommen", RoomManager.current_room_id() == &"room_03",
		str(RoomManager.current_room_id()))

	# Gegenprobe mit auto_enter = false: Betreten allein tut nichts, erst `interact`.
	var exit_to_b: RoomExit = RoomManager.current_room().get_node("ExitToB")
	exit_to_b.auto_enter = false
	player.global_position = exit_to_b.global_position
	await physics(5)
	check("auto_enter=false: Betreten allein tut nichts", not RoomManager.is_transitioning()
		and RoomManager.current_room_id() == &"room_03", str(RoomManager.current_room_id()))
	Input.action_press(&"interact")
	await physics(2)
	Input.action_release(&"interact")
	check("interact loest sie aus", RoomManager.is_transitioning())
	await settle()
	check("zurueck in room_02 auf from_c", RoomManager.current_room_id() == &"room_02"
		and player.global_position.is_equal_approx(Vector2(264, 88)),
		"%s %s" % [RoomManager.current_room_id(), player.global_position])

	print("\n== 8. Unbekannte Raum-ID aendert nichts ==")
	var before_id: StringName = RoomManager.current_room_id()
	var before_room: Node = RoomManager.current_room()
	RoomManager.transition_to(&"gibt_es_nicht", &"start")
	await physics(3)
	check("Raum unveraendert", RoomManager.current_room_id() == before_id
		and RoomManager.current_room() == before_room, str(RoomManager.current_room_id()))
	check("keine Transition haengen geblieben", not RoomManager.is_transitioning())
	check("Spieler handlungsfaehig", not player.is_input_locked())

	print("\n== 9. Game Over startet ueber den RoomManager am Startraum neu ==")
	await transition(&"room_03", &"start")
	await down_active(player)
	await down_active(player)
	check("party_wiped gemeldet", _wiped)
	check("Blende laeuft", game_over.is_running() or is_equal_approx(game_over.alpha(), 1.0))
	await physics(game_over.fade_frames + 2)
	# Seit Phase 9 startet das Game Over nicht mehr blind neu, sondern fragt. Ohne Spielstand
	# steht "Neu beginnen" bereit — der Ablauf danach ist derselbe wie in Phase 8 geprueft.
	check("Game-Over-Menue offen", menu.is_open())
	check("kein Speicherstand anwaehlbar", not menu.can_load())
	menu.confirm()
	await settle()
	check("zurueck im Startraum", RoomManager.current_room_id() == &"room_01",
		str(RoomManager.current_room_id()))
	check("Spieler am Startspawn",
		player.global_position.is_equal_approx(RoomManager.current_room().spawn_point(&"start")),
		str(player.global_position))
	check("beide Figuren stehen wieder", party.standing_count() == 2, str(party.standing_count()))
	check("Health voll", player.get_health() == player.stats.max_health,
		"%d/%d" % [player.get_health(), player.stats.max_health])
	check("Korruption zurueckgesetzt", is_zero_approx(player.get_corruption()))
	check("Korruption auch der inaktiven Figur", is_zero_approx(party.corruption_of(1)))
	check("Game-Over-Blende zurueckgenommen", is_zero_approx(game_over.alpha()))
	check("Transitions-Blende offen", is_zero_approx(RoomManager.fade_alpha()))
	check("Input frei", not player.is_input_locked())

	print("\n%s (%d Fehler)" % ["ALLES GRUEN" if _fails == 0 else "FEHLER", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


## Kamera-Limits muessen nach JEDEM Wechsel zu den Grenzen des neuen Raums passen — die Raeume
## sind unterschiedlich gross, und genau darum laeuft `_apply_camera_limits` nicht mehr einmalig
## im Bootstrap, sondern wandert mit dem Raumwechsel.
func _check_camera(player: Player, room: Room, label: String) -> void:
	var b: Rect2i = room.bounds()
	var cam: Camera2D = player.camera
	check("  Kamera-Limits == Raum %s %s" % [label, b.size],
		cam.limit_left == b.position.x and cam.limit_top == b.position.y
		and cam.limit_right == b.end.x and cam.limit_bottom == b.end.y,
		"%d,%d..%d,%d" % [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom])
	check("  Kamera-Smoothing aus", not cam.position_smoothing_enabled and not cam.limit_smoothed)


## Ein vollstaendiger Wechsel inklusive Blende.
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
