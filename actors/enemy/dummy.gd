class_name Dummy
extends CharacterBody2D

@export var max_health: int = 20
@export var knockback_friction: float = 900.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox: Hurtbox = $Hurtbox

var _health: int

func _ready() -> void:
	_health = max_health
	hurtbox.sprite = sprite
	hurtbox.hit_taken.connect(_on_hit)
	add_to_group(&"dummy")

func _on_hit(damage: int, knockback: Vector2) -> void:
	_health = maxi(0, _health - damage)
	velocity = knockback
	if _health == 0:
		_health = max_health

func _physics_process(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
	move_and_slide()
