class_name GameOverMenu
extends CanvasLayer
## Game-Over-Bildschirm (Phase 9). Liegt UEBER der Schwarzblende aus Phase 7 (`GameOverFade`,
## Layer 4) und uebernimmt genau dort, wo die bis Phase 8 blind neu gestartet hat.
##
## Zwei Eintraege: "Letzter Speicherstand" (aktiver Slot) und "Neu beginnen" (Startraum, Flags
## und Spielzeit auf Null). Ein Hauptmenue gibt es bewusst noch nicht — es waere eine eigene
## Szene VOR der persistenten Weltszene und damit ein eigener Umbau.
##
## Eingabe per Polling im _physics_process aus dem `Input`-Singleton, wie ueberall im Projekt
## (Player, Reif, PartyManager, RoomExit): dieselbe Stelle, dieselben Actions, und ein Test kann
## sie mit `Input.action_press` fahren. Bestaetigt wird mit `interact` ODER `attack` — wer gerade
## gestorben ist, hat die Hand nicht zwingend auf F.

## Der aktive Slot soll geladen werden.
signal load_requested(slot: int)
## Neues Spiel.
signal restart_requested

## Auswahl in fester Reihenfolge. Der Ladeeintrag steht oben und ist vorausgewaehlt: nach einem
## Tod will man in fast allen Faellen den Speicherstand.
enum Option { LOAD, RESTART }

@onready var _title: Label = $Center/Box/Title
@onready var _slot_line: Label = $Center/Box/SlotLine
@onready var _entry_load: Label = $Center/Box/EntryLoad
@onready var _entry_restart: Label = $Center/Box/EntryRestart

var _open: bool = false
var _index: int = Option.LOAD
## Kein Spielstand im aktiven Slot -> der Ladeeintrag ist grau und nicht anwaehlbar. Ohne das
## waere der Vorgabeeintrag im ersten Spiel eine Taste, die nichts tut.
var _can_load: bool = false
var _slot: int = 1

func _ready() -> void:
	visible = false

func is_open() -> bool:
	return _open

func can_load() -> bool:
	return _can_load

func selected() -> Option:
	return _index as Option

## `info` = Kopfdaten des aktiven Slots (`SaveManager.slot_info`), `null` = Slot leer.
func open(slot: int, info: SaveData) -> void:
	_slot = slot
	_can_load = info != null
	_index = Option.LOAD if _can_load else Option.RESTART
	_title.text = "GEFALLEN"
	_slot_line.text = ("Slot %d — %s" % [slot, info.summary()]) if _can_load \
		else "Slot %d — leer" % slot
	visible = true
	_open = true
	_refresh()

func close() -> void:
	_open = false
	visible = false

## Auswahl bewegen. Oeffentlich, damit ein Test das Menue ohne Eingabegeraet fahren kann.
func move_selection(step: int) -> void:
	if not _open:
		return
	var next: int = clampi(_index + step, Option.LOAD, Option.RESTART)
	if next == Option.LOAD and not _can_load:
		return  # ein leerer Slot ist nicht anwaehlbar, nicht nur nicht ausfuehrbar
	_index = next
	_refresh()

## Den gewaehlten Eintrag ausloesen. Das Menue schliesst sich dabei selbst: wer darauf hoert,
## baut die Welt um, und ein noch sichtbares Menue laege ueber dem neuen Raum.
func confirm() -> void:
	if not _open:
		return
	close()
	if _index == Option.LOAD:
		load_requested.emit(_slot)
	else:
		restart_requested.emit()

func _physics_process(_delta: float) -> void:
	if not _open:
		return
	if Input.is_action_just_pressed(&"move_up"):
		move_selection(-1)
	elif Input.is_action_just_pressed(&"move_down"):
		move_selection(1)
	if Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"attack"):
		confirm()

func _refresh() -> void:
	_entry_load.text = "%s Letzter Speicherstand" % (">" if _index == Option.LOAD else " ")
	_entry_restart.text = "%s Neu beginnen" % (">" if _index == Option.RESTART else " ")
	# Grau = vorhanden, aber nicht anwaehlbar. Ein ausgeblendeter Eintrag waere schlechter: der
	# Spieler soll sehen, DASS es einen Speicherstand-Eintrag gibt.
	_entry_load.modulate = Color(1, 1, 1, 1) if _can_load else Color(0.45, 0.45, 0.45, 1)
