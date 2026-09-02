extends State

var _t: int = 0

func enter(_msg: Dictionary = {}) -> void:
	var enemy := actor as Skeleton
	enemy.velocity = Vector2.ZERO
	# `sprite.play` direkt, NICHT `play_anim`: das haengt das Facing an ("dead_down") und die
	# Todes-Animation ist richtungslos (`skeleton_frames.tres` kennt nur "dead"). Bis Phase 8
	# lief hier jedes Mal ein "There is no animation with name 'dead_down'" ins Log und die
	# Todespose war nie zu sehen — aufgedeckt vom Gegner-Respawn-Check in phase8_sim.
	enemy.sprite.play(&"dead")
	enemy.hitbox.disable()
	enemy.hurtbox.monitorable = false
	enemy.set_deferred("collision_layer", 0)
	enemy.get_node("CollisionShape2D").set_deferred("disabled", true)
	# Erledigt-Flag (Phase 9). Nur fuer Gegner MIT `persist_id` — normale Gegner respawnen
	# weiter, weil der Raum bei jedem Betreten frisch instanziert wird (Phase 8).
	if enemy.persist_id != &"":
		SaveManager.mark_killed(enemy.persist_id)
	_t = 45

func physics_update(_delta: float) -> void:
	_t -= 1
	if _t <= 0:
		actor.queue_free()
