class_name Player
extends CharacterBody2D

## Signalisiert Health-Aenderungen nach aussen (PartyManager haelt sie pro Figur persistent).
signal health_changed(current: int, maximum: int)
## Dito fuer die Korruption (Phase 5). Der Reif ist weiterreichbar, die Korruption bleibt bei der
## Figur — der persistente Wert liegt darum im PartyManager, nicht hier.
signal corruption_changed(value: float, level: int)

@export var profile: FigureProfile

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: StateMachine = $StateMachine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var reif: Reif = $Reif
## Kind des Players, nicht des Raums: der Figurenwechsel tauscht nur das Profil am bestehenden
## Node (Phase 4) — die Kamera ueberlebt den Wechsel damit von selbst. Ihre Limits setzt der
## Bootstrap aus den Raumgrenzen (scenes/main.gd).
@onready var camera: Camera2D = $Camera2D

## Name der AnimationLibrary am AnimationPlayer. Leerer StringName = Default-Library, damit die
## Animation weiterhin als "attack" (ohne Praefix) abgespielt wird.
const ANIM_LIBRARY := &""

var stats: TuningStats
var facing: StringName = &"down"
var _attack_buffer_frames_left: int = 0
var _health: int
var _corruption: float = 0.0

func _ready() -> void:
	add_to_group(&"player")
	hurtbox.sprite = sprite
	hurtbox.hit_taken.connect(_on_hurt)
	apply_profile(profile)

## Setzt Sprite-Satz, Angriffs-Animation und Feel-Werte der Figur. Der Player-Node bleibt dabei
## dieselbe Instanz (siehe docs/progress.md, Phase 4: Profil-Tausch statt Despawn/Respawn) —
## Position, Velocity und laufende I-Frames ueberleben den Wechsel damit von selbst.
func apply_profile(new_profile: FigureProfile) -> void:
	if new_profile == null:
		push_error("Player: kein FigureProfile gesetzt.")
		return
	profile = new_profile
	stats = new_profile.stats
	sprite.sprite_frames = new_profile.frames
	if animation_player.has_animation_library(ANIM_LIBRARY):
		animation_player.remove_animation_library(ANIM_LIBRARY)
	animation_player.add_animation_library(ANIM_LIBRARY, new_profile.anims)
	# I-Frame-Verhalten ist pro Figur tunebar -> aus den Stats in die Hurtbox spiegeln.
	hurtbox.iframe_duration = stats.iframe_duration
	hurtbox.iframe_blink_interval = stats.iframe_blink_interval
	set_health(stats.max_health)

func set_health(value: int) -> void:
	_health = clampi(value, 0, stats.max_health)
	health_changed.emit(_health, stats.max_health)

func get_health() -> int:
	return _health

## Korruption 0..reif.stats.corruption_max. Wird vom Reif getickt und vom PartyManager ueber den
## Figurenwechsel hinweg gesichert — apply_profile setzt sie deshalb bewusst NICHT zurueck.
func set_corruption(value: float) -> void:
	_corruption = maxf(0.0, value)
	corruption_changed.emit(_corruption, reif.level() if reif != null else 0)

func get_corruption() -> float:
	return _corruption

## Ein Figurenwechsel darf einen laufenden Schlag oder Hitstun nicht abbrechen — sonst wird die
## Schultertaste zum Cancel-Tool und der Nachteil "langsamer Zwerg" waere folgenlos.
func can_switch() -> bool:
	if state_machine == null or state_machine.current_state == null:
		return false
	var current: String = state_machine.current_state.name
	return current == "Idle" or current == "Move"

func _on_hurt(damage: int, knockback: Vector2) -> void:
	set_health(_health - damage)
	if _health == 0:
		# Phase-3/4: kein echtes Game-Over — Health wird resettet.
		set_health(stats.max_health)
	state_machine.transition_to(&"hurt", {"knockback": knockback * stats.knockback_taken_scale})

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
	# Hoeherer Schaden, solange der Reif kanalisiert wird (Kickoff). Der Kanal muss den Schlag
	# ueberleben — darum ist Kanalisieren zustandsunabhaengig (siehe reif.gd).
	hitbox.damage = roundi(stats.attack_damage * reif.damage_multiplier())
	hitbox.knockback_speed = stats.knockback_speed
	hitbox.hitstop_frames = stats.hitstop_frames
	hitbox.knockback_dir = facing_vector()
	hitbox.position = facing_vector() * stats.hitbox_offset
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
