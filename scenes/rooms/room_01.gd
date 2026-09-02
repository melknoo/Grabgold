class_name Room01
extends Room
## Raum 01 (Phase 6) — Kammer, Zeittuer, Korridor, Zielkammer. Seit Phase 8 der Startraum der
## Kette A <-> B <-> C; die `RoomExit` in der Zielkammer gibt dem Puzzle zum ersten Mal ein Ziel.
##
## Das Puzzle steckt nicht in diesem Skript, sondern in den Werten: die Platte reagiert erst ab
## `required_weight` (nur der Zwerg), die Tuer bleibt `open_frames` offen (nur der Kurier schafft
## die Strecke). Hier wird beides nur verbunden — eine Zeile Verdrahtung im Raum statt einer
## Event-Bus-Infrastruktur, die ein Vertical Slice nicht traegt.
##
## Identitaet, Ausmasse und Spawn-Suche liegen in der Basisklasse (scenes/rooms/room.gd).

@onready var door: Door = $Door
@onready var plate: PressurePlate = $Plate

func _ready() -> void:
	super()
	plate.triggered.connect(_on_plate_triggered)

func _on_plate_triggered() -> void:
	door.open_for(door.open_frames)

## Distanz Platte -> Tuer. Nur fuer Debug-Overlay und Test: DAS ist die Zahl, an der das Puzzle
## haengt (muss zwischen Zwerg- und Kurier-Reichweite in `open_frames` liegen).
func plate_to_door_distance() -> float:
	return plate.global_position.distance_to(door.global_position)

## Die beiden Werte, an denen die Feel-Abnahme von Phase 6 haengt (ist das Fenster fair, ist die
## Platte als "schwer" lesbar?). Stand bis Phase 7 im Debug-Overlay selbst.
func debug_text() -> String:
	return "Platte %s  Tuer %s" % [
		"GEDRUECKT" if plate.is_pressed() else "offen",
		("OFFEN %.1fs" % (door.frames_left() / 60.0)) if door.is_open() else "zu",
	]
