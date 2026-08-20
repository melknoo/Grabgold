extends State

var _t: int = 0

func enter(_msg: Dictionary = {}) -> void:
	var enemy := actor as Skeleton
	enemy.velocity = Vector2.ZERO
	enemy.play_anim(&"dead")
	enemy.hitbox.disable()
	enemy.hurtbox.monitorable = false
	enemy.set_deferred("collision_layer", 0)
	enemy.get_node("CollisionShape2D").set_deferred("disabled", true)
	_t = 45

func physics_update(_delta: float) -> void:
	_t -= 1
	if _t <= 0:
		actor.queue_free()
