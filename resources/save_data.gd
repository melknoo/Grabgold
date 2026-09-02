class_name SaveData
extends Resource
## Ein Spielstand (Phase 9). Typisierte Resource-KLASSE, aber als JSON auf Platte
## (`user://saves/slot_N.json`) — bewusst NICHT per `ResourceSaver` als `.tres`:
##
##  * `.tres` traegt den Skriptpfad im Savefile mit; ein Spielstand ist Spielerdaten und soll
##    nichts ausfuehren koennen.
##  * `ResourceLoader` cacht nach Pfad. Zweimal denselben Slot laden gaebe dieselbe Instanz
##    zurueck, und ein Slot-Overwrite waere im laufenden Spiel unsichtbar.
##  * Ein Feld, das spaeter dazukommt, ist in JSON ein `data.get(key, default)` — daher das
##    `version`-Feld unten und `from_dict()` als einzige Lesestelle.
##
## Die Werte-in-`.tres`-Regel des Projekts (TuningStats, ReifStats, RoomRegistry) gilt fuer
## AUTORENDATEN, die von Hand gepflegt werden. Ein Spielstand ist das Gegenteil: er wird nur
## geschrieben und gelesen, nie editiert.

## Wird bei jeder Formataenderung erhoeht. `from_dict()` verweigert alles andere, statt
## halb passende Felder in einen laufenden Spielstand zu schreiben.
const VERSION := 1

@export var version: int = VERSION

## Wo der Spieler wieder aufsetzt. `spawn_id` ist der SpawnPoint NEBEN dem Speicherpunkt —
## keine rohe Position, damit ein verschobener Raum nicht alte Spielstaende in die Wand setzt.
@export var room_id: StringName = &""
@export var spawn_id: StringName = &"start"

## Ensemble-Zustand, index-parallel zu `PartyManager.figures`. 0 in `health` = ausgefallen.
@export var figure_index: int = 0
@export var health: Array[int] = []
@export var corruption: Array[float] = []

## Weltzustand, der einen Raumwechsel ueberleben soll (Phase 9): erledigte Bosse/Quest-Kills.
## Normale Gegner stehen NICHT hier drin — die respawnen weiter (siehe Skeleton.persist_id).
@export var world_flags: Dictionary[StringName, bool] = {}

## Fuer die Slot-Anzeige. Frames, wie jeder Zeitwert im Projekt.
@export var playtime_frames: int = 0
## Unix-Sekunden. Reine Anzeige — nichts im Spiel haengt an der Systemzeit.
@export var saved_at: int = 0


func to_dict() -> Dictionary:
	# StringName-Schluessel muessen zu String werden: JSON kennt nur String-Keys, und beim
	# Zurueckparsen kaemen sie sonst als String und passten nicht zum typisierten Dictionary.
	var flags: Dictionary = {}
	for key: StringName in world_flags:
		flags[String(key)] = world_flags[key]
	return {
		"version": version,
		"room_id": String(room_id),
		"spawn_id": String(spawn_id),
		"figure_index": figure_index,
		"health": Array(health),
		"corruption": Array(corruption),
		"world_flags": flags,
		"playtime_frames": playtime_frames,
		"saved_at": saved_at,
	}


## Einzige Lesestelle. `null` = unbrauchbar (falsche Version, kein Dictionary, kein Raum) —
## der Aufrufer meldet das als fehlgeschlagenen Ladevorgang und laesst die Welt in Ruhe.
##
## Alle Zahlen laufen durch `int()`/`float()`: JSON kennt keinen Integer, aus einer gespeicherten
## `6` wird beim Parsen `6.0`, und `Array[int]` nimmt keinen Float an.
static func from_dict(data: Variant) -> SaveData:
	if data is not Dictionary:
		return null
	var dict: Dictionary = data
	if int(dict.get("version", -1)) != VERSION:
		return null
	var out := SaveData.new()
	out.version = VERSION
	out.room_id = StringName(dict.get("room_id", ""))
	out.spawn_id = StringName(dict.get("spawn_id", "start"))
	out.figure_index = int(dict.get("figure_index", 0))
	if out.room_id == &"":
		return null
	var raw_health: Variant = dict.get("health", [])
	if raw_health is Array:
		for value: Variant in raw_health:
			out.health.append(int(value))
	var raw_corruption: Variant = dict.get("corruption", [])
	if raw_corruption is Array:
		for value: Variant in raw_corruption:
			out.corruption.append(float(value))
	var raw_flags: Variant = dict.get("world_flags", {})
	if raw_flags is Dictionary:
		var flags: Dictionary = raw_flags
		for key: Variant in flags:
			out.world_flags[StringName(key)] = bool(flags[key])
	out.playtime_frames = int(dict.get("playtime_frames", 0))
	out.saved_at = int(dict.get("saved_at", 0))
	return out


## "03:28" — Minuten:Sekunden aus Frames bei 60 Hz.
func playtime_text() -> String:
	var seconds: int = playtime_frames / 60
	return "%02d:%02d" % [seconds / 60, seconds % 60]


## Einzeiler fuer die Slot-Anzeige im Game-Over-Menue.
func summary() -> String:
	return "%s  %s" % [room_id, playtime_text()]
