class_name Room
extends Node2D
## Basis aller Raeume (Phase 8). Bis Phase 7 hiess das Skript von Raum 01 selbst `Room` — mit
## drei Raeumen tragfaehig ist das nicht, denn es kannte Tuer, Platte und Skelett von Raum 01.
##
## Hier steht nur, was der RoomManager von JEDEM Raum braucht: Identitaet, Ausmasse (fuer die
## Kamera-Limits) und die Spawn-Punkte. Raumspezifische Verdrahtung lebt in der Unterklasse
## (siehe room_01.gd).

const TILE := 16

## Identitaet des Raums. Muss dem Schluessel in `resources/room_registry.tres` entsprechen —
## der RoomManager laedt darueber und Phase 9 speichert genau diesen String.
@export var room_id: StringName = &""

## Raummass in Tiles, identisch zum Eintrag in tools/build_room_resources.gd. Wer dort etwas
## aendert, aendert es auch hier — die Kamera-Limits haengen daran.
@export var size_tiles: Vector2i = Vector2i(40, 24)

## Musikstueck des Raums. In Phase 8 ungenutzt und bewusst schon angelegt: Phase 11 liest es im
## `room_changed`-Handler des AudioManagers. Der Track gehoert zum Raum, nicht in die Registry —
## sonst muesste man ihn an zwei Stellen pflegen.
@export var music_id: StringName = &""

func _ready() -> void:
	# Gruppe statt fester NodePath: das Debug-Overlay haengt in einer eigenen CanvasLayer und soll
	# den Raum finden, ohne die Szenenstruktur zu kennen (gleiches Muster wie `player`).
	add_to_group(&"room")

## Raumgrenzen in Weltpixeln — Quelle fuer die Kamera-Limits.
func bounds() -> Rect2i:
	return Rect2i(Vector2i.ZERO, size_tiles * TILE)

## Position des Spawn-Punkts mit dieser ID.
##
## Gesucht wird unter den EIGENEN Kindern, nicht in einer Gruppe: beim Raumwechsel haengt der alte
## Raum noch einen Frame im Baum (queue_free), und eine Gruppensuche koennte dessen gleichnamigen
## Punkt liefern. Kein Treffer -> Warnung und erster vorhandener Punkt, damit ein Tippfehler in
## einer Tuer-ID den Spieler nicht ins Nichts (0,0 = in der Wand) setzt.
func spawn_point(spawn_id: StringName) -> Vector2:
	var first: SpawnPoint = null
	for child: Node in get_children():
		var point := child as SpawnPoint
		if point == null:
			continue
		if point.spawn_id == spawn_id:
			return point.global_position
		if first == null:
			first = point
	if first != null:
		push_warning("Room %s: Spawn '%s' nicht gefunden -> '%s'." % [room_id, spawn_id, first.spawn_id])
		return first.global_position
	push_error("Room %s: kein SpawnPoint vorhanden." % room_id)
	return Vector2.ZERO

## Raumspezifische Debug-Zeile. Default leer; Raum 01 meldet hier Platte und Tuer. So kennt das
## Debug-Overlay keine raumspezifischen Nodes mehr und scheitert in Raum 02/03 nicht an `null`.
func debug_text() -> String:
	return ""
