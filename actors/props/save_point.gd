class_name SavePoint
extends Area2D
## Speicherpunkt (Phase 9). Layer 8 `interactable`, Mask 2 `player_body` — kein neues
## Collision-Bit, der Punkt scannt den Spieler (wie `PressurePlate` und `RoomExit`).
##
## NIE automatisch, anders als die `RoomExit` mit `auto_enter`: Speichern ueberschreibt einen
## Slot, das muss ein Tastendruck sein. Darum gibt es hier auch keine `auto`-Achse.
##
## Ausgewertet wird die Ueberlappung JEDEN Physik-Frame, nicht per `body_entered`: derselbe
## Grund wie bei der PressurePlate — wer auf dem Punkt stehend die Figur wechselt, loest kein
## neues `body_entered` aus, will danach aber druecken koennen.

## Gespeichert und aufgefrischt.
signal used

## Der SpawnPoint NEBEN diesem Punkt. Er landet als `SaveData.spawn_id` im Slot, damit man beim
## Laden hier wieder aufsetzt und nicht am Raumeingang. Ohne passenden SpawnPoint im Raum faellt
## `Room.spawn_point()` auf den ersten vorhandenen zurueck (mit Warnung).
@export var spawn_id: StringName = &"save"

## Health voll, ausgefallene Figuren zurueck — die Korruption bleibt (User-Entscheidung,
## Begruendung in PartyManager.restore_all). Auf `false` ist der Punkt reines Speichern.
@export var restores_party: bool = true

## Rueckmeldung ohne Ton und ohne UI: der Punkt leuchtet kurz auf. Frames, kein Tween —
## Projektkonvention (Tuer, Blenden, Gegner-KI).
@export var flash_frames: int = 24

const COLOR_IDLE := Color(0.85, 0.72, 0.25, 1.0)
const COLOR_FLASH := Color(1.0, 1.0, 0.85, 1.0)

@onready var _sprite: Sprite2D = $Sprite2D

var _flash_left: int = 0

func _ready() -> void:
	_sprite.modulate = COLOR_IDLE

func is_flashing() -> bool:
	return _flash_left > 0

func _physics_process(_delta: float) -> void:
	if _flash_left > 0:
		_flash_left -= 1
		if _flash_left == 0:
			_sprite.modulate = COLOR_IDLE
	if not Input.is_action_just_pressed(&"interact"):
		return
	for body: Node2D in get_overlapping_bodies():
		if _try_use(body as Player):
			return

func _try_use(player: Player) -> bool:
	if player == null:
		return false
	# Waehrend einer Blende (Raumwechsel, Laden, Game-Over-Neustart) ist der Input gesperrt; der
	# Speicherpunkt fragt denselben Schalter wie Player, Reif und PartyManager (Phase 8).
	if player.is_input_locked() or RoomManager.is_transitioning():
		return false
	# Auffrischen VOR dem Schreiben: sonst haelt der Slot die Verletzungen von der Ankunft fest
	# und Laden gaebe genau den Zustand zurueck, den der Punkt gerade geheilt hat.
	if restores_party:
		var party: PartyManager = RoomManager.party()
		if party != null:
			party.restore_all()
	if not SaveManager.save_to_slot(SaveManager.active_slot, spawn_id):
		return false
	_flash_left = maxi(flash_frames, 1)
	_sprite.modulate = COLOR_FLASH
	# Schliesst einen offenen Punkt aus Phase 9: die Rueckmeldung war ein Aufleuchten von 24
	# Frames und sonst nichts. Ein Speichervorgang, den man nicht bemerkt, wird nicht benutzt.
	AudioManager.play(&"save_point")
	used.emit()
	return true
