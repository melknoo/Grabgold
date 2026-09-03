extends Node
## Headless-Verifikation Phase 7 (Korruption zu Ende gebaut). Prueft Stufe 3 (Zwangsangriff),
## Stufe 4 (Wechselsperre) und das Todesmodell: Figur faellt aus -> Zwangswechsel -> Game Over.
## Aufruf: $GODOT --headless --path . res://tests/phase7_sim.tscn
##
## Laeuft als SZENE, nicht per --script (siehe phase4/5/6_sim).

var _fails: int = 0

## Signal-Mitschriften. Als MEMBER, nicht als lokale Variablen in einem Lambda: GDScript faengt
## lokale Variablen `by value` ein — eine Zuweisung im Lambda kaeme beim Aufrufer nie an.
var _downed_index: int = -1
var _refused: bool = false
var _wiped: bool = false

## Korruption exakt auf eine Schwelle zu setzen reicht nicht: der Reif baut jeden Frame ab
## (0.4/s), und schon nach einem Frame liegt der Wert darunter. Kleiner Aufschlag = ~5 s Luft.
const OVER := 2.0

func _on_downed(index: int, _profile: FigureProfile) -> void:
	_downed_index = index

func _on_refused() -> void:
	_refused = true

func _on_wiped() -> void:
	_wiped = true

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
	# Kein Neustart nach dem Game Over: der Test prueft die Blende, nicht den Wiederaufbau.
	# (Bis Phase 7 war das Pflicht — reload_current_scene() haette diesen Test selbst neu
	# gestartet. Seit Phase 8 tauscht der RoomManager nur den Raum, der Schalter ist reine
	# Testabsicht.)
	main.restart_on_wipe = false
	var player: Player = main.get_node("Player")
	var party: PartyManager = main.get_node("PartyManager")
	var room: Room01 = RoomManager.current_room() as Room01
	var fade: GameOverFade = main.get_node("GameOverFade")
	var reif: Reif = player.reif
	var skeleton: Skeleton = room.get_node("Skeleton")
	skeleton.position = Vector2(3000, 3000)
	await physics(3)

	print("\n== 1. Startzustand ==")
	check("Stufe 0", reif.level() == 0, str(reif.level()))
	check("Kein Zwang", not reif.is_compelled())
	check("Wechsel frei", not reif.switch_locked() and player.can_switch())
	check("Beide Figuren stehen", party.standing_count() == 2, str(party.standing_count()))
	check("Keine Blende", is_zero_approx(fade.alpha()))

	print("\n== 2. Stufe 3: der Reif schlaegt von selbst zu ==")
	# Deterministisch statt gewuerfelt: Wahrscheinlichkeit auf Anschlag, Korruption auf Stufe 3.
	var tuned: ReifStats = reif.stats.duplicate()
	tuned.compulsion_per_second = 60.0  # ~1.0 pro Frame -> feuert sofort
	reif.stats = tuned
	player.set_corruption(tuned.level_thresholds[2] + OVER)
	await physics(2)
	check("Stufe 3 erreicht", reif.level() == 3, str(reif.level()))
	player.state_machine.transition_to(&"idle")
	await physics(2)
	var saw_tell: bool = false
	var saw_attack: bool = false
	for _i in 40:
		await get_tree().physics_frame
		if reif.is_compelled():
			saw_tell = true
		if player.state_machine.current_state.name == "Attack":
			saw_attack = true
			break
	check("Vorwarnung laeuft (Sprite-Tell)", saw_tell)
	check("Danach schlaegt die Figur ohne Eingabe zu", saw_attack,
		player.state_machine.current_state.name)
	check("Tell ist beendet", not reif.is_compelled())
	await physics(40)

	print("\n== 3. Unter Stufe 3 passiert das nicht ==")
	player.set_corruption(tuned.level_thresholds[1] + OVER)  # Stufe 2
	# Eine bereits ANGELAUFENE Vorwarnung laeuft bewusst zu Ende, auch wenn die Stufe darunter
	# faellt — der Spieler hat den Tell gesehen, der Schlag ist zugesagt. Hier also erst
	# ausschwingen lassen, sonst misst der Test den Nachlauf aus Abschnitt 2.
	for _i in 40:
		await get_tree().physics_frame
		if not reif.is_compelled() and player.is_neutral():
			break
	player.state_machine.transition_to(&"idle")
	await physics(2)
	check("Stufe 2", reif.level() == 2, str(reif.level()))
	var forced: bool = false
	for _i in 60:
		await get_tree().physics_frame
		if reif.is_compelled() or player.state_machine.current_state.name == "Attack":
			forced = true
			break
	check("Kein Zwangsangriff unter Stufe 3", not forced)

	print("\n== 4. Der Zwang cancelt keinen Hitstun ==")
	# Invariante wie beim Figurenwechsel: der Reif ist kein Cancel-Tool.
	player.set_corruption(tuned.corruption_max)
	player.state_machine.transition_to(&"idle")
	await physics(2)
	# Warten, bis eine Vorwarnung laeuft, dann die Figur in den Hurt-State werfen.
	var armed: bool = false
	for _i in 40:
		await get_tree().physics_frame
		if reif.is_compelled():
			armed = true
			break
	check("Vorwarnung laeuft", armed)
	player.state_machine.transition_to(&"hurt", {"knockback": Vector2.ZERO})
	await physics(tuned.compulsion_tell_frames + 2)
	check("Zwang faellt aus, Hitstun bleibt unangetastet",
		player.state_machine.current_state.name != "Attack",
		player.state_machine.current_state.name)
	await physics(30)
	reif.stats = load("res://resources/reif.tres")

	print("\n== 5. Stufe 4: der Reif laesst die Figur nicht los ==")
	player.set_corruption(reif.stats.level_thresholds[3] + OVER)
	player.state_machine.transition_to(&"idle")
	await physics(3)
	check("Stufe 4 erreicht", reif.level() == 4, str(reif.level()))
	check("Reif meldet Sperre", reif.switch_locked())
	check("can_switch() ist trotz idle false", player.is_neutral() and not player.can_switch())
	party.switch_refused.connect(_on_refused)
	var before_index: int = party.active_index()
	party.switch_next()
	await physics(2)
	check("Wechsel wird verweigert", party.active_index() == before_index)
	check("Verweigerung wird gemeldet (nicht stumm)", _refused)

	print("\n== 6. Unter Stufe 4 geht der Wechsel wieder ==")
	player.set_corruption(reif.stats.level_thresholds[2] + OVER)  # Stufe 3
	player.state_machine.transition_to(&"idle")
	await physics(2)
	check("Stufe 3", reif.level() == 3, str(reif.level()))
	party.switch_next()
	await physics(3)
	check("Figur gewechselt", party.active_index() != before_index,
		party.active_profile().display_name)
	# Zurueck auf den Kurier und entkorrumpieren, damit Abschnitt 7 sauber startet.
	player.set_corruption(0.0)
	party.switch_next()
	await physics(3)
	player.set_corruption(0.0)
	await physics(2)

	print("\n== 7. Todesmodell: die Figur faellt aus, das Ensemble traegt ==")
	party.figure_downed.connect(_on_downed)
	var first: int = party.active_index()
	var first_name: String = party.active_profile().display_name
	await kill_active(player)
	await physics(4)
	check("Ausfall gemeldet", _downed_index == first, str(_downed_index))
	check("Diese Figur gilt als ausgefallen", party.is_downed(first))
	check("Zwangswechsel auf die naechste Figur", party.active_index() != first,
		"%s -> %s" % [first_name, party.active_profile().display_name])
	check("Die neue Figur ist voll da",
		player.get_health() == player.stats.max_health,
		"%d/%d" % [player.get_health(), player.stats.max_health])
	check("Nur noch eine steht", party.standing_count() == 1, str(party.standing_count()))
	check("Kein Game Over, solange jemand steht", is_zero_approx(fade.alpha()))

	print("\n== 8. Ausgefallene Figuren werden nicht mehr angewaehlt ==")
	var held: int = party.active_index()
	party.switch_next()
	await physics(3)
	check("Wechsel findet niemanden mehr", party.active_index() == held,
		party.active_profile().display_name)

	print("\n== 9. Game Over, wenn keine mehr steht ==")
	party.party_wiped.connect(_on_wiped)
	await kill_active(player)
	await physics(4)
	check("Game Over gemeldet", _wiped)
	check("Keine Figur steht mehr", party.standing_count() == 0, str(party.standing_count()))
	check("Blende laeuft an", fade.is_running() or fade.alpha() > 0.0, "%.2f" % fade.alpha())
	await physics(fade.fade_frames + 4)
	check("Blende ist voll schwarz", fade.alpha() > 0.99, "%.2f" % fade.alpha())

	print("\n== 10. Neustart stellt das Ensemble wieder her ==")
	fade.reset()
	party.revive_all()
	await physics(3)
	check("Beide Figuren stehen wieder", party.standing_count() == 2, str(party.standing_count()))
	check("Volle Health", player.get_health() == player.stats.max_health,
		"%d/%d" % [player.get_health(), player.stats.max_health])
	check("Korruption zurueckgesetzt", is_zero_approx(player.get_corruption()),
		"%.2f" % player.get_corruption())
	check("Korruption auch bei der inaktiven Figur", is_zero_approx(party.corruption_of(1)),
		"%.2f" % party.corruption_of(1))
	check("Blende zurueckgesetzt", is_zero_approx(fade.alpha()))
	check("Wechsel wieder frei", player.can_switch())

	print("\n%s (%d Fehler)" % ["ALLES GRUEN" if _fails == 0 else "FEHLER", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


## Bringt die aktive Figur auf 0 HP. Ueber die Hurtbox, damit der echte Pfad durchlaufen wird
## (Hurtbox -> Player._on_hurt -> downed -> PartyManager).
##
## Vorher auf das Ende der I-Frames warten: die ueberleben den Figurenwechsel (Phase 4, gleicher
## Node) — ein zweiter Todesstoss kurz nach dem ersten wuerde sonst stumm abprallen.
func kill_active(player: Player) -> void:
	while player.hurtbox.is_invulnerable():
		await get_tree().physics_frame
	player.state_machine.transition_to(&"idle")
	player.hurtbox.take_hit(player.get_health(), Vector2.ZERO)


func physics(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame
