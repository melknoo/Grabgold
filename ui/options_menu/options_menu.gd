class_name OptionsMenu
extends CanvasLayer
## Optionen (Phase 11). Ein Regler je Bus (`Settings.BUSES`) plus "Zurueck".
##
## Bis Phase 10 gab es `AudioManager.set_bus_db`, aber keinen Weg dorthin — dieselbe Lage wie bei
## den drei Spielstand-Slots ohne Auswahl-UI. Das ist die Stelle, die beides erreichbar macht.
##
## Der Bildschirm hat ZWEI Aufrufer (Hauptmenue und Pausenmenue) und liegt darum in `boot.tscn`,
## nicht in einem davon: er ist Teil der Huelle, nicht des Spiels. Wer ihn oeffnet, blendet sein
## eigenes Menue aus und baut es beim Schliessen wieder auf — damit liest in keinem Frame mehr
## als ein Menue denselben Tastendruck.
##
## Eingabe per Polling im `_physics_process` aus dem `Input`-Singleton, wie ueberall im Projekt
## (Player, Reif, PartyManager, RoomExit, GameOverMenu): dieselben Actions wie im Spiel, damit
## ein Test sie mit `Input.action_press` fahren kann und der Spieler keine zweite Belegung lernt.
##
## Angezeigt wird PROZENT, kein Balken: der Standard-Font ist nicht monospaced, ein aus `|` und
## Leerzeichen gebauter Balken wackelte bei jedem Schritt. Ein Pixel-Font steht in
## `docs/assets-todo.md`; bis dahin ist eine Zahl ehrlicher als ein schiefer Balken.

## Der Bildschirm ist zu. Der Aufrufer baut sein eigenes Menue wieder auf.
signal closed

@onready var _box: VBoxContainer = $Center/Box
@onready var _hint: Label = $Center/Box/Hint

## Ein Label je Bus, in der Reihenfolge von `Settings.BUSES`, danach "Zurueck".
var _rows: Array[Label] = []
var _entry_back: Label

var _open: bool = false
var _index: int = 0
## Ein Frame Schonzeit nach dem Oeffnen. Ohne sie schliesst der Bildschirm sich in genau dem
## Frame wieder, in dem er von einem `pause`-Druck aufgemacht wurde — beide Menues lesen
## denselben `just_pressed`.
var _grace: int = 0

func _ready() -> void:
	# Die Regler stehen nicht in der Szene: ihre Anzahl ist `Settings.BUSES`, und eine Zeile,
	# die man an zwei Stellen pflegen muss, faellt irgendwann auseinander.
	for i in Settings.BUSES.size():
		var row := Label.new()
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override(&"font_size", 8)
		_box.add_child(row)
		_box.move_child(row, 1 + i)  # hinter den Titel, vor Zurueck/Hinweis
		_rows.append(row)
	_entry_back = $Center/Box/EntryBack
	visible = false

func is_open() -> bool:
	return _open

## 0..n-1 = Regler, n = "Zurueck".
func selected() -> int:
	return _index

func back_index() -> int:
	return Settings.BUSES.size()

func open() -> void:
	_index = 0
	_grace = 1
	visible = true
	_open = true
	_refresh()

func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	AudioManager.play(&"menu_back")
	closed.emit()

## Auswahl bewegen. Oeffentlich, damit ein Test den Bildschirm ohne Eingabegeraet fahren kann.
func move_selection(step: int) -> void:
	if not _open:
		return
	var next: int = clampi(_index + step, 0, back_index())
	if next == _index:
		return  # am Rand der Liste passiert nichts, also klingt auch nichts
	_index = next
	AudioManager.play(&"menu_move")
	_refresh()

## Den gewaehlten Regler verstellen. Auf "Zurueck" ist links/rechts ein No-Op — und bleibt
## darum still.
func adjust(step: int) -> void:
	if not _open or _index >= back_index():
		return
	var bus: StringName = Settings.BUSES[_index]
	var before: int = Settings.volume_step(bus)
	Settings.set_volume_step(bus, before + step)
	if Settings.volume_step(bus) == before:
		return  # schon am Anschlag
	# Der Klang liegt auf dem SFX-Bus und ist damit selbst die Rueckmeldung: wer die Effekte
	# leiser zieht, hoert das Klicken leiser werden. Genau deshalb klingt es NACH dem Setzen.
	AudioManager.play(&"menu_move")
	_refresh()

## Bestaetigen schliesst immer — auch auf einem Regler. Ein Tastendruck, auf den nichts folgt,
## liest sich als Bug (dieselbe Ueberlegung wie beim grauen Slot in Phase 9); der Eintrag
## "Zurueck" bleibt trotzdem sichtbar, damit man den Weg hinaus SIEHT.
func confirm() -> void:
	if not _open:
		return
	AudioManager.play(&"menu_confirm")
	_open = false
	visible = false
	closed.emit()

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
	if Input.is_action_just_pressed(&"move_left"):
		adjust(-1)
	elif Input.is_action_just_pressed(&"move_right"):
		adjust(1)
	if Input.is_action_just_pressed(&"pause"):
		close()
	elif Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"attack"):
		confirm()

func _refresh() -> void:
	for i in _rows.size():
		var bus: StringName = Settings.BUSES[i]
		_rows[i].text = "%s %s  %d%%" % [
			">" if _index == i else " ", Settings.label(bus), Settings.volume_percent(bus)]
	_entry_back.text = "%s Zurueck" % (">" if _index == back_index() else " ")
	_hint.text = "links/rechts stellt ein" if _index < back_index() else "Escape zurueck"
