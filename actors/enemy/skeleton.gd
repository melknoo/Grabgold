class_name Skeleton
extends CharacterBody2D

@export var stats: TuningStats
@export var aggro_range: float = 70.0
@export var attack_range: float = 20.0
@export var telegraph_frames: int = 30
@export var attack_active_frames: int = 8
@export var retreat_frames: int = 30

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var state_machine: StateMachine = $StateMachine


var facing: StringName = &"down"
var _health: int
var _player: Node2D

func _ready() -> void:
	add_to_group(&"enemy")
	_health = stats.max_health
	hurtbox.sprite = sprite
	hurtbox.hit_taken.connect(_on_hurt)

func get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	return _player

func face_toward(target: Vector2) -> void:
	var d: Vector2 = target - global_position
	if absf(d.x) >= absf(d.y):
		facing = &"right" if d.x >= 0.0 else &"left"
	else:
		facing = &"down" if d.y >= 0.0 else &"up"

func facing_vector() -> Vector2:
	match facing:
		&"down":  return Vector2(0.0, 1.0)
		&"up":    return Vector2(0.0, -1.0)
		&"left":  return Vector2(-1.0, 0.0)
		&"right": return Vector2(1.0, 0.0)
	return Vector2(0.0, 1.0)

func move_dir(dir: Vector2, delta: float) -> void:
	if dir == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, stats.friction * delta)
	else:
		velocity = velocity.move_toward(dir.normalized() * stats.max_speed, stats.acceleration * delta)
	move_and_slide()

func play_anim(action: StringName) -> void:
	sprite.play("%s_%s" % [action, facing])

func enable_hitbox() -> void:
	hitbox.damage = stats.attack_damage
	hitbox.knockback_speed = stats.knockback_speed
	hitbox.hitstop_frames = stats.hitstop_frames
	hitbox.knockback_dir = facing_vector()
	hitbox.position = facing_vector() * stats.hitbox_offset
	hitbox.enable()

func disable_hitbox() -> void:
	hitbox.disable()

func get_health() -> int:
	return _health

func _on_hurt(damage: int, knockback: Vector2) -> void:
	_health = maxi(0, _health - damage)
	velocity = knockback
	if _health == 0:
		state_machine.transition_to(&"dead")
	else:
		state_machine.transition_to(&"hurt", {"knockback": knockback})
