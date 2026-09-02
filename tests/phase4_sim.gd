extends Node
## Headless-Verifikation Phase 4. Prueft, was sich headless pruefen laesst: Profil-Tausch,
## Tempo-/Timing-Unterschied, Knockback-Immunitaet des Zwergs, Wechsel-Sperre, Health-Persistenz.
## Aufruf: $GODOT --headless --path . res://tests/phase4_sim.tscn
##
## Laeuft als SZENE, nicht per --script: bei --script registriert Godot die Autoloads nicht, und
## Hitbox/Hurtbox referenzieren `Debug` -> Compile-Error noch vor dem ersten Test.

var _fails: int = 0

func check(label: String, ok: bool, detail: String = "") -> void:
	print("  %s %s%s" % ["[OK]  " if ok else "[FAIL]", label, ("  -> " + detail) if detail != "" else ""])
	if not ok:
		_fails += 1

func _ready() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var player: Player = main.get_node("Player")
	var party: PartyManager = main.get_node("PartyManager")
	# Ab Phase 6 liegt das Skelett im Raum (scenes/rooms/room_01.tscn), nicht mehr direkt
	# unter Main. Rekursiv suchen, damit der Test kuenftige Umbauten der Szene ueberlebt.
	var skeleton: Node2D = main.find_child("Skeleton", true, false)
	# Skelett aus dem Weg, damit es die Messungen nicht stoert.
	skeleton.position = Vector2(3000, 3000)
	await physics(3)

	print("\n== 1. Startzustand ==")
	check("Startfigur ist Kurier", party.active_profile().display_name == "Kurier",
		party.active_profile().display_name)
	check("Stats = Kurier-tres", is_equal_approx(player.stats.max_speed, 95.0), str(player.stats.max_speed))
	check("Anim-Library aus Profil", player.animation_player.has_animation("attack"))
	check("SpriteFrames = Ninja (32px)",
		player.sprite.sprite_frames.get_frame_texture("idle_down", 0).get_width() == 32)
	check("HP = 6", player.get_health() == 6, str(player.get_health()))

	print("\n== 2. Tempo-Messung Kurier ==")
	var kurier_dist: float = await measure_run(player)
	check("Kurier legt in 30 F > 40 px zurueck", kurier_dist > 40.0, "%.1f px" % kurier_dist)

	print("\n== 3. Figurenwechsel ==")
	Input.action_press(&"switch_figure")
	await physics(1)
	Input.action_release(&"switch_figure")
	await physics(2)
	check("Aktive Figur ist Zwerg", party.active_profile().display_name == "Zwerg",
		party.active_profile().display_name)
	check("Stats = Zwerg-tres", is_equal_approx(player.stats.max_speed, 58.0), str(player.stats.max_speed))
	check("SpriteFrames = Knight (16px)",
		player.sprite.sprite_frames.get_frame_texture("idle_down", 0).get_width() == 16)
	check("Attack-Anim laenger (schwerer Hieb)",
		player.animation_player.get_animation(&"attack").length > 0.35,
		"%.3fs" % player.animation_player.get_animation(&"attack").length)
	check("Startet aus dem Stand", player.velocity == Vector2.ZERO, str(player.velocity))
	check("HP = 9 (Zwerg-max)", player.get_health() == 9, str(player.get_health()))

	print("\n== 4. Tempo-Messung Zwerg ==")
	var zwerg_dist: float = await measure_run(player)
	check("Zwerg ist deutlich langsamer als Kurier", zwerg_dist < kurier_dist * 0.75,
		"%.1f px vs %.1f px (%.0f%%)" % [zwerg_dist, kurier_dist, 100.0 * zwerg_dist / kurier_dist])

	print("\n== 5. Knockback: Zwerg steht wie ein Fels ==")
	var before: Vector2 = player.position
	player.hurtbox.take_hit(1, Vector2(400, 0))
	await physics(10)
	var moved_zwerg: float = player.position.distance_to(before)
	check("Zwerg wird nicht weggestossen", moved_zwerg < 0.5, "%.2f px" % moved_zwerg)
	check("Schaden kommt trotzdem an", player.get_health() == 8, str(player.get_health()))
	# I-Frames abwarten, sonst schluckt die Hurtbox den naechsten Treffer.
	await physics(45)

	print("\n== 6. Wechsel-Sperre im Angriff ==")
	player.state_machine.transition_to(&"attack")
	await physics(2)
	check("can_switch() im Attack = false", not player.can_switch(),
		player.state_machine.current_state.name)
	party.switch_next()
	check("Wechsel wird verweigert", party.active_profile().display_name == "Zwerg",
		party.active_profile().display_name)
	await physics(40)

	print("\n== 7. Health-Persistenz ueber den Wechsel ==")
	# Zwerg steht bei 8/9. Zurueck zum Kurier (6/6), dann wieder zum Zwerg -> muss 8 sein.
	party.switch_next()
	await physics(2)
	check("Kurier hat wieder 6/6", player.get_health() == 6 and player.stats.max_health == 6,
		"%d/%d" % [player.get_health(), player.stats.max_health])
	party.switch_next()
	await physics(2)
	check("Zwerg hat seine 8 HP behalten", player.get_health() == 8, str(player.get_health()))

	print("\n== 8. Knockback: Kurier fliegt weiterhin ==")
	party.switch_next()
	await physics(2)
	var kb_before: Vector2 = player.position
	player.hurtbox.take_hit(1, Vector2(400, 0))
	await physics(10)
	var moved_kurier: float = player.position.distance_to(kb_before)
	check("Kurier wird weggestossen", moved_kurier > 5.0, "%.2f px" % moved_kurier)

	print("\n== 9. Trifft der Zwerg? (1-Frame-Pose + kleinerer Hitbox-Offset) ==")
	await physics(45)  # I-Frames aus Test 8 auslaufen lassen
	party.switch_next()
	await physics(2)
	check("Zwerg ist aktiv", party.active_profile().display_name == "Zwerg")
	player.facing = &"right"
	# Skelett in Reichweite direkt vor den Zwerg stellen; sein eigener Angriff ist hier egal.
	skeleton.position = player.position + Vector2(player.stats.hitbox_offset, 0)
	var skl_before: int = skeleton.get_health()
	player.state_machine.transition_to(&"attack")
	# Attack laeuft 24 Physik-Frames (9/6/9), die Hitbox oeffnet ab Frame 9. Bei einem Treffer
	# kommen 10 Frames Hitstop obendrauf -> die Figur ist ~34 Frames (0.57s) gebunden.
	await physics(45)
	check("Skelett nimmt Schaden", skeleton.get_health() < skl_before,
		"%d -> %d" % [skl_before, skeleton.get_health()])
	check("Zwerg-Schaden ist 2 (Kurier: 1)", skl_before - skeleton.get_health() == 2,
		str(skl_before - skeleton.get_health()))
	check("Attack verklemmt nicht", player.state_machine.current_state.name != "Attack",
		player.state_machine.current_state.name)

	print("\n== 10. Regression: Kurier-Angriff (Phase 2) unveraendert ==")
	await physics(20)
	party.switch_next()
	await physics(2)
	check("Kurier ist aktiv", party.active_profile().display_name == "Kurier")
	player.facing = &"right"
	skeleton.position = player.position + Vector2(player.stats.hitbox_offset, 0)
	var k_before: int = skeleton.get_health()
	player.state_machine.transition_to(&"attack")
	await physics(30)
	check("Kurier-Schaden ist 1", k_before - skeleton.get_health() == 1,
		"%d -> %d" % [k_before, skeleton.get_health()])
	check("Attack endet in Idle/Move",
		player.state_machine.current_state.name != "Attack",
		player.state_machine.current_state.name)

	print("\n%s (%d Fehler)" % ["ALLES GRUEN" if _fails == 0 else "FEHLER", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


## Laesst die Figur 30 Physik-Frames nach rechts laufen und gibt die zurueckgelegte Distanz.
func measure_run(player: Player) -> float:
	player.velocity = Vector2.ZERO
	player.state_machine.transition_to(&"idle")
	var start: Vector2 = player.position
	Input.action_press(&"move_right")
	await physics(30)
	Input.action_release(&"move_right")
	var dist: float = player.position.distance_to(start)
	await physics(6)
	return dist


func physics(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame
