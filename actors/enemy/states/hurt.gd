extends State

var _t: int = 0

func enter(msg: Dictionary = {}) -> void:
	var enemy := actor as Skeleton
	enemy.velocity = msg.get("knockback", Vector2.ZERO)
	_t = 10
	enemy.play_anim(&"idle")
	enemy.sprite.modulate = Color(1.0, 0.5, 0.5)

func exit() -> void:
	var enemy := actor as Skeleton
	enemy.sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func physics_update(delta: float) -> void:
	var enemy := actor as Skeleton
	enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, enemy.stats.friction * delta)
	enemy.move_and_slide()
	_t -= 1
	if _t <= 0:
		enemy.sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		state_machine.transition_to(&"approach")
