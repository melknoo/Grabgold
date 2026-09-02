class_name PressurePlate
extends Area2D
## Gewichtsplatte (Phase 6). Der Ausloeser ist das GEWICHT der Figur (`TuningStats.weight`),
## nicht ein Tastendruck — damit wird der Figurenwechsel aus Phase 4 zum Puzzle-Verb: der Kurier
## (1.0) laeuft wirkungslos darueber, der Zwerg (3.0) drueckt sie herunter.
##
## Layer 8 `interactable`, Mask 2 `player_body`. Abweichung von der Notiz in der CLAUDE.md-Matrix
## ("Player-Interact scannt 8"), bewusst: hier scannt die PLATTE den Spieler. Das spart eine
## Interact-Action und jede Zeile Player-Code — es gibt keinen Knopf, das Gewicht IST der Input.

signal triggered
signal released

## Ab diesem Gewicht gibt die Platte nach. Zwischen Kurier (1.0) und Zwerg (3.0).
@export var required_weight: float = 2.0

## Sprite-Regionen im Pack-Sheet (TilesetDungeon.png, Tile (5,3) rot = offen / (6,3) blau =
## gedrueckt). Asset-Koordinaten, keine Feel-Werte — die gehoeren nicht ins TuningStats-`.tres`.
const REGION_UP := Rect2(80, 48, 16, 16)
const REGION_DOWN := Rect2(96, 48, 16, 16)

@onready var _sprite: Sprite2D = $Sprite2D

var _pressed: bool = false

func is_pressed() -> bool:
	return _pressed

## Ausgewertet wird JEDEN Physik-Frame ueber die Ueberlappung, nicht per `body_entered`.
## Grund: der Figurenwechsel tauscht nur das Profil am bestehenden Player-Node (Phase 4) — wer
## auf der Platte stehend wechselt, loest kein neues `body_entered` aus. Mit `body_entered` waere
## genau die zentrale Interaktion des Raums tot.
func _physics_process(_delta: float) -> void:
	var heaviest: float = 0.0
	for body: Node2D in get_overlapping_bodies():
		var player := body as Player
		if player != null and player.stats != null:
			heaviest = maxf(heaviest, player.stats.weight)
	var pressed_now: bool = heaviest >= required_weight
	if pressed_now == _pressed:
		return
	_pressed = pressed_now
	_sprite.region_rect = REGION_DOWN if _pressed else REGION_UP
	if _pressed:
		triggered.emit()
	else:
		released.emit()
