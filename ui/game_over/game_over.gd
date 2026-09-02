class_name GameOverFade
extends CanvasLayer
## Schwarzblende beim Game Over (Phase 7). Ohne sie wuerde der Raum beim Neustart einfach
## umspringen und der Spieler wuesste nicht, dass er verloren hat.
##
## Timing in FRAMES per Zaehler im _physics_process — wie Tuer, Gegner-KI und Angriffstiming
## im ganzen Projekt, und aus demselben Grund: deterministisch und headless pruefbar.

signal fade_finished

@export var fade_frames: int = 60

@onready var _rect: ColorRect = $Rect

## -1 = laeuft nicht.
var _frames: int = -1

func _ready() -> void:
	_rect.color = Color(0.0, 0.0, 0.0, 0.0)

func start() -> void:
	if _frames >= 0:
		return  # laeuft schon — ein zweites Game Over waehrend der Blende gibt es nicht
	_frames = 0

func is_running() -> bool:
	return _frames >= 0

func alpha() -> float:
	return _rect.color.a

func reset() -> void:
	_frames = -1
	_rect.color.a = 0.0

func _physics_process(_delta: float) -> void:
	if _frames < 0:
		return
	_frames += 1
	_rect.color.a = clampf(float(_frames) / float(maxi(fade_frames, 1)), 0.0, 1.0)
	if _frames >= fade_frames:
		_frames = -1
		_rect.color.a = 1.0
		fade_finished.emit()
