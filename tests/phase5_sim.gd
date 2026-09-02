extends Node
## Headless-Verifikation Phase 5 (Reif). Prueft, was sich ohne Bild pruefen laesst: Kanalisierung,
## Duty-Cycle-Zeitdehnung, Schadensbonus, Phase-Dash inkl. Maskenwiederherstellung,
## Korruptionszaehler/-stufen, Drift und Persistenz ueber den Figurenwechsel.
## Aufruf: $GODOT --headless --path . res://tests/phase5_sim.tscn
##
## Laeuft als SZENE, nicht per --script: bei --script registriert Godot die Autoloads nicht, und
## Hitbox/Hurtbox referenzieren `Debug` -> Compile-Error noch vor dem ersten Test.

## Messsonde fuer den Duty-Cycle: zaehlt, wie oft sie tatsaechlich getickt hat.
class TickCounter extends Node:
	var ticks: int = 0
	func _physics_process(_delta: float) -> void:
		ticks += 1

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
	var skeleton: Skeleton = main.find_child("Skeleton", true, false)
	var overlay: CanvasLayer = main.get_node("CorruptionOverlay")
	var reif: Reif = player.reif
	# Skelett aus dem Weg, damit es die Messungen nicht stoert.
	skeleton.position = Vector2(3000, 3000)
	await physics(3)

	print("\n== 1. Startzustand ==")
	check("Reif ist nicht aktiv", not reif.is_channeling())
	check("Korruption 0", is_zero_approx(player.get_corruption()), "%.2f" % player.get_corruption())
	check("Stufe 0", reif.level() == 0, str(reif.level()))
	check("Schadensfaktor 1.0 ohne Kanal", is_equal_approx(reif.damage_multiplier(), 1.0))
	check("Dash ohne Reif gesperrt", not reif.can_dash())
	check("Vignette unsichtbar", is_zero_approx(overlay.intensity()), "%.2f" % overlay.intensity())
	check("Koerper sind solide (player_body scannt enemy_body)",
		player.get_collision_mask_value(3), "mask=%d" % player.collision_mask)

	print("\n== 2. Kanalisierung laedt Korruption auf ==")
	Input.action_press(&"reif_channel")
	await physics(60)
	check("Reif kanalisiert", reif.is_channeling())
	var expected: float = reif.stats.corruption_per_second * player.stats.corruption_gain_scale
	check("Aufladung ~ corruption_per_second/s",
		absf(player.get_corruption() - expected) < 0.8,
		"%.2f (erwartet ~%.2f)" % [player.get_corruption(), expected])
	check("Schadensfaktor aktiv", is_equal_approx(reif.damage_multiplier(), reif.stats.damage_multiplier))
	check("Dash freigeschaltet", reif.can_dash())

	print("\n== 3. Zeitdehnung: Duty-Cycle im HitstopManager ==")
	var probe := TickCounter.new()
	add_child(probe)
	HitstopManager.set_time_scale(probe, 0.55)
	await physics(100)
	HitstopManager.clear_time_scale(probe)
	check("Sonde tickt ~55 von 100 Frames", absf(probe.ticks - 55) <= 3, "%d Ticks" % probe.ticks)
	probe.queue_free()
	check("Skelett-StateMachine ist registriert", HitstopManager.is_slowed(skeleton.state_machine))
	check("Skelett-Sprite ist registriert", HitstopManager.is_slowed(skeleton.sprite))
	check("Skelett-Body selbst NICHT gegated (Hurtbox bleibt aktiv)",
		not HitstopManager.is_slowed(skeleton))
	check("Faktor = reif.tres", is_equal_approx(
		HitstopManager.time_scale_for(skeleton.state_machine), reif.stats.time_scale),
		"%.2f" % HitstopManager.time_scale_for(skeleton.state_machine))

	print("\n== 4. Zeitdehnung wirkt auf Gegner-Timing, nicht auf den Spieler ==")
	var slow_frames: int = await measure_telegraph(skeleton)
	var slow_dist: float = await measure_run(player)
	Input.action_release(&"reif_channel")
	await physics(3)
	check("Zeitdehnung geloest", not HitstopManager.is_slowed(skeleton.state_machine))
	check("process_mode zurueckgesetzt",
		skeleton.state_machine.process_mode == Node.PROCESS_MODE_INHERIT,
		str(skeleton.state_machine.process_mode))
	var fast_frames: int = await measure_telegraph(skeleton)
	var fast_dist: float = await measure_run(player)
	var ratio: float = float(fast_frames) / float(slow_frames)
	check("Telegraph dauert real ~1/time_scale laenger",
		absf(ratio - reif.stats.time_scale) < 0.06,
		"%d F normal vs %d F gedehnt (Faktor %.2f, erwartet %.2f)"
			% [fast_frames, slow_frames, ratio, reif.stats.time_scale])
	check("Spieler bleibt unveraendert schnell (kein Engine.time_scale)",
		absf(slow_dist - fast_dist) < 1.0, "%.1f px vs %.1f px" % [slow_dist, fast_dist])

	print("\n== 5. Schadensbonus ==")
	var base_dmg: int = await hit_skeleton(player, skeleton, false)
	var reif_dmg: int = await hit_skeleton(player, skeleton, true)
	check("Ohne Reif = attack_damage", base_dmg == player.stats.attack_damage, str(base_dmg))
	check("Mit Reif = roundi(damage * multiplier)",
		reif_dmg == roundi(player.stats.attack_damage * reif.stats.damage_multiplier),
		"%d (erwartet %d)" % [reif_dmg, roundi(player.stats.attack_damage * reif.stats.damage_multiplier)])
	skeleton.position = Vector2(3000, 3000)
	await physics(45)

	print("\n== 6. Phase-Dash ==")
	Input.action_release(&"reif_channel")
	player.state_machine.transition_to(&"idle")
	player.facing = &"right"
	player.velocity = Vector2.ZERO
	await physics(2)
	# Ohne Kanal darf gar nichts passieren.
	Input.action_press(&"dash")
	await physics(2)
	Input.action_release(&"dash")
	check("Ohne Reif kein Dash", player.state_machine.current_state.name != "Dash",
		player.state_machine.current_state.name)
	# Gegner mitten in den Weg stellen.
	var start: Vector2 = player.position
	skeleton.position = start + Vector2(26, 0)
	Input.action_press(&"reif_channel")
	await physics(2)
	Input.action_press(&"dash")
	await physics(2)
	Input.action_release(&"dash")
	check("Dash-State betreten", player.state_machine.current_state.name == "Dash",
		player.state_machine.current_state.name)
	check("Hurtbox ausgesetzt (fuer Gegner-Hitboxen unsichtbar)", not player.hurtbox.monitorable)
	check("Body-Maske um enemy_body gekuerzt", reif.is_phasing())
	check("Regulaere I-Frames unverbraucht", not player.hurtbox.is_invulnerable())
	await physics(reif.stats.dash_frames + 4)
	var travelled: float = player.position.x - start.x
	check("Dash endet jenseits des Gegners", travelled > 40.0, "%.1f px" % travelled)
	check("Hurtbox wieder scharf", player.hurtbox.monitorable)
	check("Maske wiederhergestellt", not reif.is_phasing(), "mask=%d" % player.collision_mask)
	check("Dash-Cooldown laeuft", reif.dash_cooldown_left() > 0, str(reif.dash_cooldown_left()))

	print("\n== 6b. Unverwundbarkeit im Dash (echte Gegner-Hitbox) ==")
	# Die Skelett-KI stilllegen: sonst mischt sie sich mit eigenen Angriffen ein und die Messung
	# haengt am Zufall ihres Zustands. Die Hitbox wird hier von Hand geschaltet.
	skeleton.state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	# Auf der Stelle dashen, damit die Geometrie waehrend der Messung konstant bleibt — sonst
	# haengt das Ergebnis daran, wie schnell der Spieler aus der Hitbox herauslaeuft.
	var still_ring: ReifStats = reif.stats.duplicate()
	still_ring.dash_speed = 0.0
	still_ring.dash_frames = 30
	still_ring.dash_cooldown_frames = 0
	reif.stats = still_ring
	player.state_machine.transition_to(&"idle")
	player.velocity = Vector2.ZERO
	skeleton.position = player.position
	skeleton.facing = &"down"
	# Cooldown des Dashes aus Abschnitt 6 auslaufen lassen.
	await physics(20)
	Input.action_press(&"dash")
	await physics(2)
	Input.action_release(&"dash")
	check("Dash laeuft (auf der Stelle)", player.state_machine.current_state.name == "Dash",
		player.state_machine.current_state.name)
	var hp_before: int = player.get_health()
	skeleton.enable_hitbox()
	await physics(10)
	check("Treffer im Dash kommt nicht an", player.get_health() == hp_before,
		"%d -> %d" % [hp_before, player.get_health()])
	check("Regulaere I-Frames dabei unverbraucht", not player.hurtbox.is_invulnerable())
	# Gegenprobe, dass die ausgesetzte Hurtbox nicht dauerhaft blind bleibt: nach dem Dash noch
	# einmal zuschlagen lassen -> muss treffen. Der Gegner wird dafuer neu positioniert, weil die
	# Physik die jetzt soliden Koerper nach dem Dash auseinanderschiebt (Depenetration).
	skeleton.disable_hitbox()
	await physics(still_ring.dash_frames + 6)
	check("Dash ist beendet", player.state_machine.current_state.name != "Dash",
		player.state_machine.current_state.name)
	skeleton.position = player.position
	skeleton.enable_hitbox()
	await physics(8)
	check("Kontrolle: der naechste Hieb trifft wieder", player.get_health() < hp_before,
		"%d -> %d" % [hp_before, player.get_health()])
	skeleton.position = Vector2(3000, 3000)
	skeleton.state_machine.process_mode = Node.PROCESS_MODE_INHERIT
	skeleton.state_machine.transition_to(&"idle")
	reif.stats = load("res://resources/reif.tres")
	await physics(50)

	print("\n== 7. Maske bleibt gekuerzt, solange der Dash im Gegner endet ==")
	await physics(reif.stats.dash_cooldown_frames + 2)
	player.state_machine.transition_to(&"idle")
	player.facing = &"right"
	player.velocity = Vector2.ZERO
	await physics(2)
	# Gegner exakt auf das Dash-Ende stellen -> der Spieler kommt IM Koerper zum Stehen.
	skeleton.position = player.position + Vector2(
		reif.stats.dash_speed * reif.stats.dash_frames / 60.0, 0.0)
	Input.action_press(&"dash")
	await physics(2)
	Input.action_release(&"dash")
	await physics(reif.stats.dash_frames + 2)
	check("Steckt im Gegner -> Maske bleibt gekuerzt", reif.is_phasing(),
		"mask=%d" % player.collision_mask)
	# Freilaufen -> Maske muss von selbst zurueckkommen.
	skeleton.position = Vector2(3000, 3000)
	await physics(4)
	check("Nach dem Freiwerden stellt sich die Maske zurueck", not reif.is_phasing(),
		"mask=%d" % player.collision_mask)

	print("\n== 8. Korruptionsstufen ==")
	Input.action_release(&"reif_channel")
	await physics(2)
	player.set_corruption(reif.stats.level_thresholds[0] + 0.5)
	await physics(2)
	check("Stufe 1 an der ersten Schwelle", reif.level() == 1, str(reif.level()))
	check("Vignette sichtbar", overlay.intensity() > 0.0, "%.2f" % overlay.intensity())
	player.set_corruption(reif.stats.corruption_max)
	await physics(2)
	check("Vignette bei Vollausschlag = 1.0", overlay.intensity() > 0.99,
		"%.4f" % overlay.intensity())
	check("Stufe 4 am Anschlag", reif.level() == 4, str(reif.level()))

	print("\n== 9. Stufe 2: Dash-Drift ==")
	var tuned: ReifStats = reif.stats.duplicate()
	tuned.drift_chance = 1.0
	reif.stats = tuned
	player.set_corruption(tuned.level_thresholds[1] + 0.5)
	check("Drift traegt weiter als eingegeben",
		reif.roll_dash_frames() == roundi(tuned.dash_frames * tuned.drift_scale),
		"%d statt %d" % [reif.roll_dash_frames(), tuned.dash_frames])
	player.set_corruption(0.0)
	check("Unter Stufe 2 kein Drift", reif.roll_dash_frames() == tuned.dash_frames,
		str(reif.roll_dash_frames()))
	reif.stats = load("res://resources/reif.tres")

	print("\n== 10. Abbau: extrem langsam ==")
	player.set_corruption(50.0)
	await physics(120)
	var decayed: float = 50.0 - player.get_corruption()
	check("Korruption sinkt", decayed > 0.0, "-%.2f in 2 s" % decayed)
	check("Abbau < 1 %/s", decayed < 2.0, "-%.2f in 2 s" % decayed)

	print("\n== 11. Persistenz ueber den Figurenwechsel (der Reif wird weitergereicht) ==")
	player.state_machine.transition_to(&"idle")
	await physics(2)
	player.set_corruption(40.0)
	party.switch_next()
	await physics(2)
	check("Zwerg startet unkorrumpiert", player.get_corruption() < 1.0,
		"%.2f" % player.get_corruption())
	check("Kurier-Korruption gesichert", party.corruption_of(0) > 39.0,
		"%.2f" % party.corruption_of(0))
	# Zwerg kurz kanalisieren: haelt den Fluch besser aus (corruption_gain_scale 0.7).
	Input.action_press(&"reif_channel")
	await physics(60)
	Input.action_release(&"reif_channel")
	var zwerg_gain: float = player.get_corruption()
	check("Zwerg laedt langsamer auf als der Kurier",
		zwerg_gain < expected * 0.9, "%.2f vs Kurier %.2f" % [zwerg_gain, expected])
	party.switch_next()
	await physics(2)
	check("Kurier hat seine ~40 wieder", absf(player.get_corruption() - 40.0) < 1.0,
		"%.2f" % player.get_corruption())
	party.switch_next()
	await physics(2)
	check("Zwerg hat seinen eigenen Wert behalten",
		absf(player.get_corruption() - zwerg_gain) < 1.0, "%.2f" % player.get_corruption())

	print("\n%s (%d Fehler)" % ["ALLES GRUEN" if _fails == 0 else "FEHLER", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


## Reale Physik-Frames, die das Skelett fuer seinen 30-Frame-Telegraph braucht. Direktes Mass
## dafuer, wie stark die Zeitdehnung das Gegner-Timing streckt.
func measure_telegraph(skeleton: Skeleton) -> int:
	skeleton.state_machine.transition_to(&"telegraph")
	var frames: int = 0
	while skeleton.state_machine.current_state.name == "Telegraph" and frames < 400:
		await get_tree().physics_frame
		frames += 1
	skeleton.state_machine.transition_to(&"idle")
	return frames


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


## Ein Schlag gegen das Skelett; gibt den zugefuegten Schaden zurueck.
func hit_skeleton(player: Player, skeleton: Skeleton, channeling: bool) -> int:
	if channeling:
		Input.action_press(&"reif_channel")
	else:
		Input.action_release(&"reif_channel")
	await physics(2)
	player.state_machine.transition_to(&"idle")
	player.velocity = Vector2.ZERO
	player.facing = &"right"
	skeleton.state_machine.transition_to(&"idle")
	skeleton.position = player.position + Vector2(player.stats.hitbox_offset, 0)
	await physics(2)
	var before: int = skeleton.get_health()
	player.state_machine.transition_to(&"attack")
	await physics(60)
	return before - skeleton.get_health()


func physics(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame
