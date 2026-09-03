class_name Door
extends StaticBody2D
## Zeittuer (Phase 6). Steht auf `environment` (Bit 1) und ist damit fuer Spieler UND Gegner
## solide — anders als der Phase-Dash, der nur `enemy_body` aus der Maske kuerzt: durch Waende
## kommt niemand, auch nicht mit dem Reif.
##
## Timing in FRAMES per Zaehler im _physics_process, KEINE Timer-Node (Projektkonvention seit
## Phase 3, damit Gegner- und Raum-Timing deterministisch und headless pruefbar bleiben).

signal door_opened
signal door_closed

## Wie lange die Tuer nach dem Ausloesen offen bleibt. DAS ist die Tuning-Achse des Puzzles:
## sie muss laenger sein als Kurier-Laufzeit und kuerzer als Zwerg-Laufzeit von der Platte hierher.
## 240 F = 4 s @60: Kurier (95 px/s) braucht fuer die 304 px ~192 F, der Zwerg (58 px/s) ~314 F.
@export var open_frames: int = 240

## Das Pack hat KEINEN Tuerklang. `door_move` ist ein schwerer Aufprall; beim Schliessen laeuft
## derselbe Klang tiefer — dieselbe Tuer, andere Richtung. Eingetragen in docs/assets-todo.md.
const CLOSE_PITCH := 0.8

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _blocker: Area2D = $Blocker

var _open: bool = false
var _frames_left: int = 0

func is_open() -> bool:
	return _open

func frames_left() -> int:
	return _frames_left

## Oeffnet die Tuer und startet den Zaehler neu. Erneutes Ausloesen bei offener Tuer verlaengert
## nur — es soll sich nicht anfuehlen, als haette der zweite Tritt nichts gebracht.
func open_for(frames: int) -> void:
	_frames_left = maxi(frames, 1)
	if _open:
		return
	_open = true
	# set_deferred, weil open_for() aus einem Area-Signal der Platte kommt und damit mitten im
	# Physik-Callback laeuft. Genau der Fehler, der in Phase 2 den HitstopManager zerlegt hat
	# ("Disabling a CollisionObject during a physics callback").
	_shape.set_deferred("disabled", true)
	_sprite.visible = false
	AudioManager.play(&"door_move")
	door_opened.emit()

func _physics_process(_delta: float) -> void:
	if not _open:
		return
	if _frames_left > 0:
		_frames_left -= 1
		return
	# Der Zaehler ist abgelaufen — aber die Tuer schliesst NICHT auf jemandem. Stuende noch ein
	# Koerper im Tuerfeld, waere er im naechsten Frame in einem StaticBody eingeklemmt.
	# Dieselbe Klasse Problem und dieselbe Loesung wie Reif._restore_body_mask() (Phase 5):
	# den Zustand erst zuruecknehmen, wenn das Feld nachweislich frei ist.
	if not _blocker.get_overlapping_bodies().is_empty():
		return
	_open = false
	_shape.set_deferred("disabled", false)
	_sprite.visible = true
	AudioManager.play(&"door_move", CLOSE_PITCH)
	door_closed.emit()
