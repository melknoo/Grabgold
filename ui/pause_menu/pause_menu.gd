class_name PauseMenu
extends CanvasLayer
## Pausenmenue (Phase 11). Der einzige Weg, im laufenden Spiel an die Optionen und zurueck ins
## Hauptmenue zu kommen — ohne es waeren die Optionen nur vor dem Spielstart erreichbar, und
## damit waere der Bildschirm aus dieser Phase halb umsonst gebaut.
##
## Angehalten wird mit den Mitteln, die seit Phase 9 dafuer stehen: `RoomManager.set_room_frozen`
## (`process_mode` am `RoomHost`) plus `Player.set_input_locked`. Ausdruecklich NICHT
## `get_tree().paused` und nicht `Engine.time_scale` — dasselbe Argument wie beim HitstopManager:
## der Raum soll stehen, die Huelle (Menue, Blenden, Ton) weiterlaufen. Die Musik laeuft dabei
## absichtlich weiter, sonst waere der Musikregler in den Optionen nicht zu hoeren.
##
## Der Reif raeumt seinen gehaltenen Klang bei der Input-Sperre selbst auf (Phase 10) — ein
## Summen, das durch die Pause traegt, gibt es damit von selbst nicht.
##
## Liegt in `boot.tscn` und nicht in der Weltszene: es gehoert zur Huelle, teilt sich den
## Optionen-Bildschirm mit dem Hauptmenue und muss ein Freigeben der Welt ueberleben.

signal resume_requested
signal options_requested
signal main_menu_requested

enum Option { RESUME, OPTIONS, MAIN_MENU }

@onready var _entry_resume: Label = $Center/Box/EntryResume
@onready var _entry_options: Label = $Center/Box/EntryOptions
@onready var _entry_menu: Label = $Center/Box/EntryMenu

var _open: bool = false
var _index: int = Option.RESUME
var _grace: int = 0

func _ready() -> void:
	visible = false

func is_open() -> bool:
	return _open

func selected() -> Option:
	return _index as Option

## `keep_selection` = true, wenn das Menue nach den Optionen wieder aufgeht: der Spieler soll
## dort weitermachen, wo er war, und nicht wieder auf "Weiter" stehen.
func open(keep_selection: bool = false) -> void:
	if not keep_selection:
		_index = Option.RESUME
	_grace = 1
	visible = true
	_open = true
	_refresh()

func close() -> void:
	_open = false
	visible = false

func move_selection(step: int) -> void:
	if not _open:
		return
	var next: int = clampi(_index + step, Option.RESUME, Option.MAIN_MENU)
	if next == _index:
		return  # am Rand der Liste bleibt es still
	_index = next
	AudioManager.play(&"menu_move")
	_refresh()

## Weitermachen. Auch der `pause`-Druck landet hier — die Taste, die aufmacht, macht auch zu.
func resume() -> void:
	if not _open:
		return
	AudioManager.play(&"menu_back")
	close()
	resume_requested.emit()

func confirm() -> void:
	if not _open:
		return
	if _index == Option.RESUME:
		resume()
		return
	AudioManager.play(&"menu_confirm")
	if _index == Option.OPTIONS:
		# NICHT `close()`: der Aufrufer blendet aus und baut nach den Optionen wieder auf. Das
		# Menue bleibt also offen im Sinne von "die Pause laeuft weiter".
		options_requested.emit()
		return
	close()
	main_menu_requested.emit()

func _physics_process(_delta: float) -> void:
	if not _open:
		return
	if _grace > 0:
		_grace -= 1
		return
	if Input.is_action_just_pressed(&"move_up"):
		move_selection(-1)
	elif Input.is_action_just_pressed(&"move_down"):
		move_selection(1)
	if Input.is_action_just_pressed(&"pause"):
		resume()
	elif Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"attack"):
		confirm()

func _refresh() -> void:
	_entry_resume.text = "%s Weiter" % (">" if _index == Option.RESUME else " ")
	_entry_options.text = "%s Optionen" % (">" if _index == Option.OPTIONS else " ")
	_entry_menu.text = "%s Hauptmenue" % (">" if _index == Option.MAIN_MENU else " ")
