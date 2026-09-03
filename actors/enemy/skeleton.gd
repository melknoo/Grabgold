class_name Skeleton
extends CharacterBody2D

@export var stats: TuningStats
@export var aggro_range: float = 70.0
@export var attack_range: float = 20.0
@export var telegraph_frames: int = 30
@export var attack_active_frames: int = 8
@export var retreat_frames: int = 30

## Bleibt dieser Gegner tot (Phase 9)? Leer = nein, er respawnt bei jedem Betreten des Raums —
## das ist die Regel fuer normale Gegner und faellt seit Phase 8 von selbst so aus, weil der
## Raum frisch instanziert wird. Gesetzt = sein Tod landet als `world_flag` im Spielstand
## (Bosse, Quest-Kills).
##
## Die ID muss ueber ALLE Raeume eindeutig sein: sie ist der Flag-Name, nicht der Node-Name.
@export var persist_id: StringName = &""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var state_machine: StateMachine = $StateMachine


var facing: StringName = &"down"
var _health: int
var _player: Node2D

func _ready() -> void:
	# Schon erledigt (Phase 9)? Dann gar nicht erst aufbauen. Der SaveManager haelt die Flags des
	# laufenden Spiels und wird beim Laden VOR dem Rauminstanzieren gefuellt — genau darum darf
	# diese Frage hier im _ready stehen.
	if persist_id != &"" and SaveManager.is_killed(persist_id):
		_despawn()
		return
	add_to_group(&"enemy")
	_health = stats.max_health
	hurtbox.sprite = sprite
	hurtbox.hit_taken.connect(_on_hurt)

## Sofort aus dem Weg (Phase 9). `queue_free` allein genuegt nicht: der Node bliebe bis zum
## Frame-Ende im Baum und haette mit aktiver Hurtbox und laufender StateMachine noch einen
## Physik-Frame lang mitgespielt.
func _despawn() -> void:
	hide()
	state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	hitbox.disable()
	hurtbox.set_deferred("monitorable", false)  # gleicher Grund wie in states/dead.gd
	set_deferred("collision_layer", 0)
	$CollisionShape2D.set_deferred("disabled", true)
	queue_free()

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

## Klang DIESES Gegners (Phase 10). Die Zeitdehnung des Reifs (Phase 5) faehrt in den PITCH:
## ein verlangsamter Gegner klingt tiefer. Das ist die einzige Stelle, an der der Reif hoerbar
## auf etwas anderes als sich selbst wirkt — und genau das macht ihn im Kampf lesbar.
##
## Gefragt wird nach der StateMachine, nicht nach dem Body: verlangsamt wird sie (der Body laeuft
## durch, damit seine Areas nicht flackern — siehe `Reif._apply_time_dilation`).
func play_sound(id: StringName) -> void:
	AudioManager.play(id, HitstopManager.time_scale_for(state_machine))

func get_health() -> int:
	return _health

func _on_hurt(damage: int, knockback: Vector2) -> void:
	_health = maxi(0, _health - damage)
	# `knockback_taken_scale` lag bis Phase 11 brach: nur der Player las ihn (der Zwerg steht mit
	# 0.0 wie ein Fels). Fuer den Waechter in Raum C ist genau das die Achse, die ihn von einem
	# Skelett mit mehr Health unterscheidet — er weicht nicht zurueck, also darf man ihn nicht
	# einfach in die Ecke pruegeln. Der Default 1.0 laesst jeden bisherigen Gegner unveraendert.
	var taken: Vector2 = knockback * stats.knockback_taken_scale
	velocity = taken
	if _health == 0:
		state_machine.transition_to(&"dead")
	else:
		state_machine.transition_to(&"hurt", {"knockback": taken})
