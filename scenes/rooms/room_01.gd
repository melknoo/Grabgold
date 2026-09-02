class_name Room
extends Node2D
## Raum 01 (Phase 6) — Kammer, Zeittuer, Korridor, Zielkammer.
##
## Das Puzzle steckt nicht in diesem Skript, sondern in den Werten: die Platte reagiert erst ab
## `required_weight` (nur der Zwerg), die Tuer bleibt `open_frames` offen (nur der Kurier schafft
## die Strecke). Hier wird beides nur verbunden — eine Zeile Verdrahtung im Raum statt einer
## Event-Bus-Infrastruktur, die ein Vertical Slice nicht traegt.

const TILE := 16

## Raummass in Tiles, identisch zu `ROOM` in tools/build_room_resources.gd. Wer dort etwas
## aendert, aendert es auch hier — die Kamera-Limits haengen daran.
@export var size_tiles: Vector2i = Vector2i(40, 24)

@onready var door: Door = $Door
@onready var plate: PressurePlate = $Plate
@onready var player_spawn: Marker2D = $PlayerSpawn

func _ready() -> void:
	# Gruppe statt fester NodePath: das Debug-Overlay haengt in einer eigenen CanvasLayer und soll
	# den Raum finden, ohne die Szenenstruktur zu kennen (gleiches Muster wie `player`).
	add_to_group(&"room")
	plate.triggered.connect(_on_plate_triggered)

func _on_plate_triggered() -> void:
	door.open_for(door.open_frames)

## Raumgrenzen in Weltpixeln — Quelle fuer die Kamera-Limits.
func bounds() -> Rect2i:
	return Rect2i(Vector2i.ZERO, size_tiles * TILE)

func spawn_point() -> Vector2:
	return player_spawn.global_position

## Distanz Platte -> Tuer. Nur fuer Debug-Overlay und Test: DAS ist die Zahl, an der das Puzzle
## haengt (muss zwischen Zwerg- und Kurier-Reichweite in `open_frames` liegen).
func plate_to_door_distance() -> float:
	return plate.global_position.distance_to(door.global_position)
