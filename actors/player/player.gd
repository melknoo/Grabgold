class_name Player
extends CharacterBody2D

@export var stats: TuningStats

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: StateMachine = $StateMachine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox

const HITBOX_OFFSET := 13.0

var facing: StringName = &"down"
var _attack_buffer_frames_left: int = 0
var _health: int

func _ready() -> void:
	add_to_group(&"player")
	_health = stats.max_health
	hurtbox.sprite = sprite
	hurtbox.hit_taken.connect(_on_hurt)

func _on_hurt(damage: int, knockback: Vector2) -> void:
	_health = maxi(0, _health - damage)
	if _health == 0:
		# Phase-3: kein echtes Game-Over — Health wird resettet.
		_health = stats.max_health
	state_machine.transition_to(&"hurt", {"knockback": knockback})

func facing_vector() -> Vector2:
	match facing:
		&"down":  return Vector2(0, 1)
		&"up":    return Vector2(0, -1)
		&"left":  return Vector2(-1, 0)
		&"right": return Vector2(1, 0)
	return Vector2(0, 1)

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"attack"):
		_attack_buffer_frames_left = stats.attack_buffer_frames
	elif _attack_buffer_frames_left > 0:
		_attack_buffer_frames_left -= 1

func consume_attack() -> bool:
	if _attack_buffer_frames_left > 0:
		_attack_buffer_frames_left = 0
		return true
	return false

func enable_hitbox() -> void:
	hitbox.damage = stats.attack_damage
	hitbox.knockback_speed = stats.knockback_speed
	hitbox.hitstop_frames = stats.hitstop_frames
	hitbox.knockback_dir = facing_vector()
	hitbox.position = facing_vector() * HITBOX_OFFSET
	hitbox.enable()

func disable_hitbox() -> void:
	hitbox.disable()

func get_input_vector() -> Vector2:
	return Vector2(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"move_up", &"move_down")
	)

func update_facing(input: Vector2) -> void:
	if input.x != 0.0:
		facing = &"right" if input.x > 0.0 else &"left"
	elif input.y != 0.0:
		facing = &"down" if input.y > 0.0 else &"up"
	# If input == Vector2.ZERO, do nothing

func apply_movement(input: Vector2, delta: float) -> void:
	var dir := input.normalized()
	if dir == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, stats.friction * delta)
	else:
		velocity = velocity.move_toward(dir * stats.max_speed, stats.acceleration * delta)
	move_and_slide()

func play_anim(action: StringName) -> void:
	sprite.play("%s_%s" % [action, facing])
