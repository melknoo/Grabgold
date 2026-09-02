class_name SpawnPoint
extends Marker2D
## Ankunftspunkt in einem Raum (Phase 8). Eine Raum-Tuer nennt Zielraum UND Ziel-Spawn; der
## RoomManager setzt den Spieler nach dem Laden hierher.
##
## Der Punkt liegt bewusst NEBEN der Tuer, nicht in ihr: sonst wuerde der Spieler beim Ankommen
## sofort wieder in den Trigger laufen, mit dem er gerade gekommen ist.

@export var spawn_id: StringName = &"start"
