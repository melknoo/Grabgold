extends State
## Phase-Dash (Phase 5). Nur erreichbar, solange der Reif kanalisiert wird — es gibt bewusst
## keinen Dodge-Roll als Grundfaehigkeit (Kickoff). Frame-Counting wie in hurt.gd, keine Timer.

var _frames_left: int = 0

func enter(_msg: Dictionary = {}) -> void:
	var player := actor as Player
	var input: Vector2 = player.get_input_vector()
	var dir: Vector2 = input.normalized() if input != Vector2.ZERO else player.facing_vector()
	player.velocity = dir * player.reif.stats.dash_speed
	_frames_left = player.reif.roll_dash_frames()
	player.reif.begin_phase()
	# Facing bleibt fuer die Dauer des Dashes stehen — dieselbe Invariante wie im Angriff
	# (CLAUDE.md > Movement- und Combat-Konventionen, Punkt 3).
	player.play_anim(&"walk")

func exit() -> void:
	var player := actor as Player
	player.reif.end_phase()
	player.reif.start_dash_cooldown()

func physics_update(_delta: float) -> void:
	var player := actor as Player
	player.move_and_slide()
	_frames_left -= 1
	if _frames_left <= 0:
		if player.get_input_vector() != Vector2.ZERO:
			state_machine.transition_to(&"move")
		else:
			state_machine.transition_to(&"idle")
