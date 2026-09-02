class_name RoomExit
extends Area2D
## Raum-Tuer (Phase 8): der Uebergang in einen anderen Raum. Layer 8 `interactable`,
## Mask 2 `player_body` — kein neues Collision-Bit, die Tuer scannt den Spieler.
##
## Nicht zu verwechseln mit `Door` (actors/props/door.gd): das ist die ZEITTUER des Phase-6-
## Puzzles, ein solider StaticBody. Diese hier ist ein reiner Trigger und blockiert nichts.

## Ziel: Raum-ID (Schluessel in resources/room_registry.tres) und Spawn-ID in diesem Raum.
@export var target_room: StringName = &""
@export var target_spawn: StringName = &"start"

## ALTTP-Stil: reinlaufen genuegt (User-Entscheidung fuer die drei Testraeume). Auf `false`
## braucht die Tuer einen `interact`-Druck — beides bleibt als Achse am Node, weil sich das
## erst im Spielen entscheidet.
@export var auto_enter: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if auto_enter:
		_try_enter(body as Player)

## Bei `auto_enter = false` wird die Ueberlappung JEDEN Physik-Frame ausgewertet, nicht per
## Signal-Flanke: derselbe Grund wie bei der PressurePlate — wer in der Tuer stehend die Figur
## wechselt, loest kein neues `body_entered` aus, koennte danach aber druecken wollen.
func _physics_process(_delta: float) -> void:
	if auto_enter or not Input.is_action_just_pressed(&"interact"):
		return
	for body: Node2D in get_overlapping_bodies():
		if _try_enter(body as Player):
			return

func _try_enter(player: Player) -> bool:
	if player == null:
		return false
	# Waehrend einer laufenden Transition kein zweiter Aufruf: der Spieler wird beim Ankommen
	# umgesetzt und koennte dabei kurz in einem Trigger liegen.
	if RoomManager.is_transitioning():
		return false
	if target_room == &"":
		push_error("RoomExit %s: kein target_room gesetzt." % get_path())
		return false
	RoomManager.transition_to(target_room, target_spawn)
	return true
