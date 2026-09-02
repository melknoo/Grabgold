class_name Player
extends CharacterBody2D

## Signalisiert Health-Aenderungen nach aussen (PartyManager haelt sie pro Figur persistent).
signal health_changed(current: int, maximum: int)
## Dito fuer die Korruption (Phase 5). Der Reif ist weiterreichbar, die Korruption bleibt bei der
## Figur — der persistente Wert liegt darum im PartyManager, nicht hier.
signal corruption_changed(value: float, level: int)
## Health dieser Figur ist auf 0 — sie faellt aus (Phase 7). Wer darauf reagiert, ist der
## PartyManager: er haelt den Zustand pro Figur und entscheidet ueber Zwangswechsel/Game Over.
signal downed

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

## Faerbung der Vorwarnung vor dem Zwangsangriff (Stufe 3). Giftig-violett, damit es sich klar
## vom roten Telegraph des Skeletts unterscheidet — das eine ist eine Drohung von aussen, das
## andere greift von innen zu.
const COMPULSION_TINT := Color(0.85, 0.35, 1.0)

## Verweigerter Figurenwechsel (Stufe 4): matt und entfaerbt statt grell — der Reif nimmt etwas
## weg, er droht nicht.
const REFUSAL_TINT := Color(0.35, 0.30, 0.45)
const REFUSAL_FRAMES := 18

var stats: TuningStats
var facing: StringName = &"down"
var _attack_buffer_frames_left: int = 0
var _health: int
var _corruption: float = 0.0
var _refusal_frames_left: int = 0
## Waehrend eines Raumwechsels (Phase 8) liest der Spieler keinen Input mehr. Der Schalter sitzt
## HIER und nicht an drei Aufrufstellen, weil drei Stellen den Input-Singleton lesen: dieses
## Skript (Attack-Buffer + Bewegungsvektor fuer die States), der Reif (Kanal/Dash) und der
## PartyManager (Figurenwechsel). Ein Flag an der Quelle statt fuenf Guards.
var _input_locked: bool = false
## Keine Figur steht mehr (Phase 9). Siehe `set_defeated`.
var _defeated: bool = false

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

## Handlungsfaehig = idle oder move. Ein laufender Schlag, Hitstun und der Dash duerfen weder vom
## Figurenwechsel noch vom Zwangsangriff (Phase 7) abgebrochen werden — sonst wird beides zum
## Cancel-Tool und der Nachteil "langsamer Zwerg" waere folgenlos.
func is_neutral() -> bool:
	if state_machine == null or state_machine.current_state == null:
		return false
	var current: String = state_machine.current_state.name
	return current == "Idle" or current == "Move"

## Zusaetzlich zur Handlungsfaehigkeit: ab Korruptionsstufe 4 sperrt der Reif den Wechsel.
func can_switch() -> bool:
	return is_neutral() and not (reif != null and reif.switch_locked())

## Faerbung waehrend der Vorwarnung des Zwangsangriffs. Nur RGB — der Alphakanal gehoert der
## Hurtbox (I-Frame-Blinken), beide wuerden sich sonst gegenseitig ueberschreiben.
func set_compulsion_tint(on: bool) -> void:
	set_sprite_tint(COMPULSION_TINT if on else Color.WHITE)

func set_sprite_tint(c: Color) -> void:
	sprite.modulate = Color(c.r, c.g, c.b, sprite.modulate.a)

## Kurzer, matter Flash: der Reif laesst die Figur nicht los (Korruptionsstufe 4). Sonst waere ein
## verweigerter Wechsel voellig stumm und saehe wie ein hakender Tastendruck aus.
func flash_refusal() -> void:
	_refusal_frames_left = REFUSAL_FRAMES

## Der Zwangsangriff hat Vorrang: er ist das dringendere Signal und faerbt ohnehin jeden Frame.
func _tick_refusal_tint() -> void:
	if _refusal_frames_left <= 0:
		return
	_refusal_frames_left -= 1
	if reif != null and reif.is_compelled():
		return
	set_sprite_tint(REFUSAL_TINT if (_refusal_frames_left / 3) % 2 == 0 else Color.WHITE)
	if _refusal_frames_left == 0:
		set_sprite_tint(Color.WHITE)

func _on_hurt(damage: int, knockback: Vector2) -> void:
	set_health(_health - damage)
	if _health == 0:
		# Phase 7: kein Health-Reset mehr. Die Figur faellt aus; der PartyManager wechselt
		# zwangsweise auf die naechste und meldet Game Over, wenn keine mehr steht. Bewusst KEIN
		# Hurt-State: diese Figur verlaesst das Feld, ein Knockback an ihr waere folgenlos.
		downed.emit()
		return
	state_machine.transition_to(&"hurt", {"knockback": knockback * stats.knockback_taken_scale})

## Input-Sperre setzen (RoomManager waehrend der Blende). Beim Sperren faellt die Figur sofort in
## den Stand und nach `idle` zurueck — ein laufender Schlag oder Hitstun darf nicht mitten im
## Raumwechsel weiterlaufen und im neuen Raum landen.
func set_input_locked(locked: bool) -> void:
	if _input_locked == locked:
		return
	_input_locked = locked
	if not locked:
		return
	_attack_buffer_frames_left = 0
	velocity = Vector2.ZERO
	if state_machine != null and state_machine.current_state != null and not is_neutral():
		state_machine.transition_to(&"idle")

func is_input_locked() -> bool:
	return _input_locked

## Die Party ist ausgefallen (Phase 9). Der Koerper bleibt liegen, kann aber nichts mehr
## abbekommen. Ohne das schlaegt ein Gegner hinter der Game-Over-Blende weiter zu: die Hurtbox
## bliebe scharf, jeder Treffer liefe erneut in `_on_hurt` mit `_health == 0` und feuerte
## `downed` -> `party_wiped` immer wieder.
##
## Nur `monitorable`, NICHT die I-Frames — dieselbe Trennung wie beim Phase-Dash (Phase 5): die
## I-Frames gehoeren dem Trefferfeedback, nicht dem Weltzustand.
##
## `set_deferred`, weil der Ausfall aus einem Area-Signal kommt und damit mitten im
## Physik-Callback laeuft (derselbe Fehler, der in Phase 2 den HitstopManager zerlegt hat).
func set_defeated(on: bool) -> void:
	_defeated = on
	hurtbox.set_deferred("monitorable", not on)

func is_defeated() -> bool:
	return _defeated

func facing_vector() -> Vector2:
	match facing:
		&"down":  return Vector2(0, 1)
		&"up":    return Vector2(0, -1)
		&"left":  return Vector2(-1, 0)
		&"right": return Vector2(1, 0)
	return Vector2(0, 1)

func _physics_process(_delta: float) -> void:
	if _input_locked:
		_tick_refusal_tint()
		return
	if Input.is_action_just_pressed(&"attack"):
		_attack_buffer_frames_left = stats.attack_buffer_frames
	elif _attack_buffer_frames_left > 0:
		_attack_buffer_frames_left -= 1
	_tick_refusal_tint()

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
	if _input_locked:
		return Vector2.ZERO
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
