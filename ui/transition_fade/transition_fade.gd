class_name TransitionFade
extends CanvasLayer
## Schwarzblende des Raumwechsels (Phase 8). Wird vom `RoomManager`-Autoload selbst instanziert
## und lebt damit ausserhalb jeder Raum- oder Weltszene — genau darum ueberlebt sie den Tausch
## des Raums, um den es hier geht.
##
## Timing in FRAMES per Zaehler im _physics_process, KEIN Tween: Tuer, Gegner-KI, Angriffs-
## timing und die Game-Over-Blende zaehlen im ganzen Projekt Frames, weil das deterministisch
## und headless pruefbar ist. Ein Tween waere der erste Zeitgeber, der es nicht ist.

signal fade_finished

## 0 = nichts sichtbar, 1 = voll schwarz.
enum Phase { IDLE, OUT, IN }

@onready var _rect: ColorRect = $Rect

var _phase: Phase = Phase.IDLE
var _frames: int = 0
var _total: int = 1

func _ready() -> void:
	_rect.color = Color(0.0, 0.0, 0.0, 0.0)

func alpha() -> float:
	return _rect.color.a

func is_fading() -> bool:
	return _phase != Phase.IDLE

## Nach Schwarz. `fade_finished` kommt, sobald Alpha 1.0 erreicht ist.
func fade_out(frames: int) -> void:
	_start(Phase.OUT, frames)

## Aus Schwarz heraus. `fade_finished` kommt bei Alpha 0.0.
func fade_in(frames: int) -> void:
	_start(Phase.IN, frames)

## Sofort voll schwarz bzw. sofort klar — fuer den Spielstart ohne Blende.
func set_black(black: bool) -> void:
	_phase = Phase.IDLE
	_rect.color.a = 1.0 if black else 0.0

func _start(phase: Phase, frames: int) -> void:
	_phase = phase
	_total = maxi(frames, 1)
	_frames = 0
	# Startwert setzen, damit ein Fade nicht vom Alpha des vorigen abhaengt.
	_rect.color.a = 0.0 if phase == Phase.OUT else 1.0

func _physics_process(_delta: float) -> void:
	if _phase == Phase.IDLE:
		return
	_frames += 1
	var t: float = clampf(float(_frames) / float(_total), 0.0, 1.0)
	_rect.color.a = t if _phase == Phase.OUT else 1.0 - t
	if _frames < _total:
		return
	_rect.color.a = 1.0 if _phase == Phase.OUT else 0.0
	_phase = Phase.IDLE
	fade_finished.emit()
