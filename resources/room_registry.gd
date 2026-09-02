class_name RoomRegistry
extends Resource
## Verzeichnis aller Raeume (Phase 8): Raum-ID -> Szenenpfad, plus der Startraum.
##
## Warum eine Resource und keine `const` im Autoload: dieselbe Regel, die `TuningStats`,
## `ReifStats` und `FigureProfile` tragen — ein neuer Raum ist ein Eintrag im `.tres`, kein Code.
## Der `music_id` gehoert bewusst NICHT hierher, sondern an den Raum-Node selbst: sonst muesste
## man ihn an zwei Stellen pflegen.

@export var rooms: Dictionary[StringName, String] = {}

## Wohin ein neues Spiel und der Neustart nach Game Over fuehren.
@export var start_room: StringName = &"room_01"
@export var start_spawn: StringName = &"start"

func has_room(room_id: StringName) -> bool:
	return rooms.has(room_id)

func scene_path(room_id: StringName) -> String:
	return rooms.get(room_id, "")
