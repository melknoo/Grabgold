class_name Reif
extends Node
## Der Reif — verfluchter Ring, Kernmechanik aus dem Kickoff. Kind-Node des Players.
##
## Taste halten = kanalisieren. Solange gehalten: Zeitdehnung fuer alle Gegner, hoeherer Schaden,
## Phase-Dash freigeschaltet — und pro Sekunde laedt Korruption auf. "Die beste Mechanik im Spiel
## ist die, die den Spieler frisst."
##
## Zwei bewusste Entscheidungen:
##  * Kanalisieren ist REIN INPUT-GETRIEBEN und zustandsunabhaengig: man haelt den Ring durch
##    Angriff und Hitstun hindurch. Sonst waere der Schadensbonus unerreichbar, weil der Schlag
##    laenger dauert als das Zeitfenster, in dem man den Kanal starten koennte.
##  * Der KORRUPTIONSWERT liegt nicht hier, sondern im Player (und persistent pro Figur im
##    PartyManager). Der Reif ist weiterreichbar — die Korruption bleibt bei der Figur, die sie
##    sich geholt hat.

@export var stats: ReifStats

## Seedbar fuer deterministische Tests (siehe tests/phase5_sim.gd, Stufe-2-Drift).
var rng := RandomNumberGenerator.new()

var _player: Player
var _channeling: bool = false
var _dash_cooldown_left: int = 0
## Nodes, die aktuell im HitstopManager als verlangsamt registriert sind.
var _slowed: Array[Node] = []
## Nach dem Dash wird die player_body-Maske NICHT sofort zurueckgesetzt (siehe _restore_body_mask).
var _mask_restore_pending: bool = false
## Restframes der Vorwarnung des Zwangsangriffs (Stufe 3). 0 = kein Zwang unterwegs.
var _tell_frames_left: int = 0

func _ready() -> void:
	_player = get_parent() as Player
	rng.randomize()
	if stats == null:
		push_error("Reif: kein ReifStats gesetzt.")

func _physics_process(delta: float) -> void:
	if stats == null or _player == null:
		return
	# Raumwechsel (Phase 8): kein Input, kein Kanal. Die Zeitdehnung wird dabei ZUERST
	# aufgeraeumt — sonst bliebe ein Gegner des alten Raums im HitstopManager als verlangsamt
	# registriert und der neue Raum startet mit haengendem Duty-Cycle.
	if _player.is_input_locked():
		_channeling = false
		_clear_time_dilation()
		# Eine laufende Vorwarnung faellt aus. Sonst blieb der Sprite violett gefaerbt in den
		# neuen Raum hinein und der Zwangsangriff schlug beim Ankommen zu.
		if _tell_frames_left > 0:
			_tell_frames_left = 0
			_player.set_compulsion_tint(false)
		return
	_channeling = Input.is_action_pressed(&"reif_channel")
	if _dash_cooldown_left > 0:
		_dash_cooldown_left -= 1
	if _mask_restore_pending:
		_restore_body_mask()
	if _channeling:
		_apply_time_dilation()
		_tick_corruption(stats.corruption_per_second * _player.stats.corruption_gain_scale * delta)
	else:
		_clear_time_dilation()
		_tick_corruption(-stats.corruption_decay_per_second * delta)
	# Nach dem Korruptions-Tick, damit eine gerade erreichte Stufe sofort greift.
	_tick_compulsion(delta)

func is_channeling() -> bool:
	return _channeling

## Faktor auf den Angriffsschaden. 1.0 ohne Kanal.
func damage_multiplier() -> float:
	return stats.damage_multiplier if _channeling else 1.0

## 0 = unkorrumpiert, 1..4 = Korruptionsstufe. Phase 5 verdrahtet Feedback nur fuer 1 und 2.
func level() -> int:
	var value: float = _player.get_corruption()
	var lvl: int = 0
	for threshold: float in stats.level_thresholds:
		if value >= threshold:
			lvl += 1
	return lvl

## Der Dash ist KEINE Grundfaehigkeit — es gibt bewusst keinen Dodge-Roll (Kickoff). Erst der
## gehaltene Reif schaltet ihn frei.
func can_dash() -> bool:
	return _channeling and _dash_cooldown_left <= 0

func start_dash_cooldown() -> void:
	_dash_cooldown_left = stats.dash_cooldown_frames

func dash_cooldown_left() -> int:
	return _dash_cooldown_left

## Dauer des naechsten Dashes in Frames. Ab Korruptionsstufe 2 traegt er gelegentlich weiter als
## eingegeben — soll sich wie ein Bug anfuehlen, nicht wie eine Strafe (Kickoff, Stufe 2).
func roll_dash_frames() -> int:
	if level() >= 2 and rng.randf() < stats.drift_chance:
		return roundi(stats.dash_frames * stats.drift_scale)
	return stats.dash_frames

## Phase-Dash: nur die Maske kuerzen, keinen Node umbauen (CLAUDE.md > Collision-Layer-Matrix).
## Bit 3 = enemy_body -> der Spieler laeuft durch Gegner hindurch. Die Hurtbox wird zusaetzlich
## ausgesetzt (unverwundbar), ohne die regulaeren I-Frames zu verbrauchen: die gehoeren dem
## Trefferfeedback und duerfen vom Dash nicht aufgezehrt werden.
func begin_phase() -> void:
	_mask_restore_pending = false
	_player.set_collision_mask_value(3, false)
	_player.hurtbox.set_deferred("monitorable", false)

func end_phase() -> void:
	_player.hurtbox.set_deferred("monitorable", true)
	# Maske erst zurueck, wenn der Spieler frei steht — sonst steckt er im Gegner fest, falls der
	# Dash mitten in einem Koerper endet.
	_mask_restore_pending = true
	_restore_body_mask()

func is_phasing() -> bool:
	return not _player.get_collision_mask_value(3)

## Die Maske MUSS fuer den Test kurz gesetzt werden: test_move prueft gegen die AKTUELLE Maske,
## und mit gekuerzter Maske sieht der Spieler den Gegner gar nicht — er wuerde immer "frei"
## melden und der Spieler bliebe im Koerper stecken. Zwischen Setzen und Zuruecksetzen laeuft
## kein Physikschritt, das ist also nebenwirkungsfrei.
##
## Geprueft wird gegen GENAU BIT 3 (`enemy_body`), nicht gegen die volle Maske. Bis Phase 5 war
## das dasselbe, weil es ausser dem Boden nichts Solides gab. Mit den Waenden aus Phase 6 nicht
## mehr: ein Dash, der direkt an einer Wand endet, haette den Test dauerhaft auf "blockiert"
## gehalten — der Spieler waere ohne Hinweis phasend stehen geblieben und haette weiter durch
## Gegner laufen koennen. Die Wand ist fuer die Frage, ob Bit 3 zurueck darf, schlicht irrelevant.
func _restore_body_mask() -> void:
	const ENEMY_BODY_MASK := 4  # nur Bit 3
	var saved: int = _player.collision_mask
	_player.collision_mask = ENEMY_BODY_MASK
	var stuck: bool = _player.test_move(_player.global_transform, Vector2.ZERO, null, 0.08, true)
	_player.collision_mask = saved
	if stuck:
		return  # steckt noch in einem Gegner -> naechsten Frame erneut versuchen
	_player.set_collision_mask_value(3, true)
	_mask_restore_pending = false

## Ab Korruptionsstufe 4 nimmt der Reif dem Spieler den Ausweg: die Figur kann nicht mehr
## gewechselt werden. Genau DAS ist der Preis der Mechanik — bis dahin durfte man den Fluch auf
## die naechste Figur abwaelzen (Phase 4/5), ab hier sitzt man auf dem, was man sich geholt hat.
## Der einzige Weg heraus ist Abwarten (0.4/s Abbau) — oder auszufallen, denn ein Zwangswechsel
## nach dem Ausknocken umgeht die Sperre bewusst (siehe PartyManager).
func switch_locked() -> bool:
	return level() >= 4

## Laeuft gerade die Vorwarnung eines Zwangsangriffs (Stufe 3)?
func is_compelled() -> bool:
	return _tell_frames_left > 0

## Stufe 3: der Reif schlaegt von selbst zu. Erst Vorwarnung (Sprite-Flackern), dann der Schlag —
## der Spieler kann in dem Fenster noch die Position aendern, den Schlag aber nicht abbestellen.
func _tick_compulsion(delta: float) -> void:
	if _tell_frames_left > 0:
		_tell_frames_left -= 1
		_player.set_compulsion_tint((_tell_frames_left / 2) % 2 == 0)
		if _tell_frames_left > 0:
			return
		_player.set_compulsion_tint(false)
		# Wurde die Figur waehrend der Vorwarnung getroffen oder dasht sie, faellt der Zwang aus.
		# Sonst wuerde der Reif Hitstun canceln — und ein Cancel-Tool ist er ausdruecklich nicht
		# (dieselbe Invariante, die den Figurenwechsel auf idle/move beschraenkt).
		if _player.is_neutral():
			_player.state_machine.transition_to(&"attack")
		return
	if level() < 3 or not _player.is_neutral():
		return
	if rng.randf() < stats.compulsion_per_second * delta:
		_tell_frames_left = maxi(stats.compulsion_tell_frames, 1)

func _tick_corruption(amount: float) -> void:
	if is_zero_approx(amount):
		return
	_player.set_corruption(clampf(_player.get_corruption() + amount, 0.0, stats.corruption_max))

## Verlangsamt NICHT den Gegner-Body, sondern nur seine StateMachine (Bewegung + Zustands-
## fortschritt) und seinen Sprite (Animation). Der Body behaelt damit durchgehend aktive
## Collision-Shapes und eine aktive Hurtbox — wuerde man ihn selbst gaten, flackerten seine Areas
## und der Spieler-Hitbox koennte ein Treffer entgehen.
func _apply_time_dilation() -> void:
	var current: Array[Node] = []
	for enemy: Node in get_tree().get_nodes_in_group(&"enemy"):
		for tick_node: Variant in [enemy.get("state_machine"), enemy.get("sprite")]:
			if tick_node is Node:
				HitstopManager.set_time_scale(tick_node, stats.time_scale)
				current.append(tick_node)
	# Wer letzten Frame verlangsamt war und jetzt nicht mehr dazugehoert (Gegner tot oder aus der
	# Gruppe), bekommt seine Zeit zurueck — sonst bliebe er gegated.
	for n: Node in _slowed:
		if not current.has(n):
			HitstopManager.clear_time_scale(n)
	_slowed = current

func _clear_time_dilation() -> void:
	if _slowed.is_empty():
		return
	for n: Node in _slowed:
		HitstopManager.clear_time_scale(n)
	_slowed.clear()
