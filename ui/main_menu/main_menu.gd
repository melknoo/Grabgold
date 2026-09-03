class_name MainMenu
extends CanvasLayer
## Hauptmenue (Phase 11). Der Bildschirm, den Phase 9 angekuendigt und bewusst verschoben hat:
## "es waere eine eigene Szene VOR der persistenten Weltszene und damit ein eigener Umbau".
## Genau dieser Umbau ist `scenes/boot.tscn`; hier liegt nur die Auswahl.
##
## Es ist eine DATEIAUSWAHL, kein "Neues Spiel / Laden / Optionen" (ALTTP-Muster): die drei
## Slots stehen als Zeilen da, ein voller laedt, ein leerer beginnt DORT ein neues Spiel. Damit
## ist der Slot immer bewusst gewaehlt — bis Phase 10 schrieb jeder Speicherpunkt in
## `SaveManager.active_slot`, und welcher das war, konnte der Spieler nirgends sehen.
##
## Loeschen liegt hier und nirgends sonst, mit Inline-Bestaetigung auf der Zeile selbst. Ohne es
## waere die Auswahl ein Sackgassen-Menue: nach drei Spielstaenden liesse sich kein neues Spiel
## mehr beginnen, weil ein voller Slot immer laedt.
##
## Eingabe per Polling wie ueberall im Projekt; bestaetigt wird mit `interact` ODER `attack`
## (Muster aus Phase 9 — wer gerade gestorben ist, hat die Hand nicht zwingend auf F).

## Leerer Slot gewaehlt: dort ein neues Spiel beginnen.
signal new_game_requested(slot: int)
## Voller Slot gewaehlt.
signal load_requested(slot: int)
signal options_requested
signal quit_requested

@onready var _box: VBoxContainer = $Center/Box
@onready var _entry_options: Label = $Center/Box/EntryOptions
@onready var _entry_quit: Label = $Center/Box/EntryQuit
@onready var _hint: Label = $Center/Box/Hint

## Ein Label je Slot, `_slot_rows[i]` gehoert Slot i+1.
var _slot_rows: Array[Label] = []
## Kopfdaten der Slots, EINMAL beim Oeffnen und nach jedem Loeschen gelesen — nicht bei jedem
## Tastendruck: `slot_info` liest die ganze Datei (Phase 9), und die Navigation soll nicht
## dreimal pro Frame auf die Platte greifen.
var _info: Array[SaveData] = []

var _open: bool = false
var _index: int = 0
## Slot, dessen Loeschung bestaetigt werden will. 0 = keiner.
var _armed: int = 0
var _grace: int = 0

func _ready() -> void:
	for i in SaveManager.SLOT_COUNT:
		var row := Label.new()
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override(&"font_size", 8)
		_box.add_child(row)
		_box.move_child(row, 1 + i)
		_slot_rows.append(row)
		_info.append(null)
	visible = false

func is_open() -> bool:
	return _open

## 0..SLOT_COUNT-1 = Slots, dann Optionen, dann Beenden.
func selected() -> int:
	return _index

func options_index() -> int:
	return SaveManager.SLOT_COUNT

func quit_index() -> int:
	return SaveManager.SLOT_COUNT + 1

## Slot, dessen Loeschung gerade bestaetigt werden will (0 = keiner). Oeffentlich fuer den Test.
func armed_slot() -> int:
	return _armed

## `keep_selection` = true, wenn das Menue nach den Optionen wieder aufgeht: der Spieler soll
## auf dem Eintrag aufsetzen, den er gerade gedrueckt hat.
func open(keep_selection: bool = false) -> void:
	if not keep_selection:
		_index = 0
	_armed = 0
	_grace = 1
	_scan()
	visible = true
	_open = true
	_refresh()

func close() -> void:
	_open = false
	visible = false

## Die Slots neu von der Platte lesen.
func _scan() -> void:
	for i in SaveManager.SLOT_COUNT:
		_info[i] = SaveManager.slot_info(i + 1)

func move_selection(step: int) -> void:
	if not _open:
		return
	var next: int = clampi(_index + step, 0, quit_index())
	if next == _index:
		return  # am Rand der Liste bleibt es still (Muster aus Phase 9)
	_index = next
	# Wegbewegen nimmt die geladene Loeschung zurueck: eine scharfe Bestaetigung, die man nicht
	# mehr sieht, ist eine Falle.
	_armed = 0
	AudioManager.play(&"menu_move")
	_refresh()

## Loeschen anfordern bzw. zurueckziehen (`switch_figure`, im Menue die zweite Hand). Wirkt nur
## auf einem VOLLEN Slot — auf einem leeren gibt es nichts zu loeschen, also bleibt es still.
func toggle_delete() -> void:
	if not _open or _index >= options_index():
		return
	if _armed != 0:
		_armed = 0
		AudioManager.play(&"menu_back")
		_refresh()
		return
	if _info[_index] == null:
		return
	_armed = _index + 1
	AudioManager.play(&"menu_move")
	_refresh()

func confirm() -> void:
	if not _open:
		return
	# Scharfe Loeschung zuerst: solange sie steht, bedeutet die Bestaetigungstaste NUR sie.
	if _armed != 0:
		var slot: int = _armed
		_armed = 0
		SaveManager.delete_slot(slot)
		_scan()
		AudioManager.play(&"menu_confirm")
		_refresh()
		return
	AudioManager.play(&"menu_confirm")
	if _index == options_index():
		options_requested.emit()
		return
	if _index == quit_index():
		quit_requested.emit()
		return
	# Das Menue schliesst sich NICHT selbst: wer darauf hoert, baut erst eine Welt auf, und ein
	# Fehlschlag beim Laden soll den Spieler nicht in einem leeren Bildschirm sitzen lassen
	# (dieselbe Zustaendigkeit wie beim Game-Over-Menue, Phase 9).
	var slot: int = _index + 1
	if _info[_index] != null:
		load_requested.emit(slot)
	else:
		new_game_requested.emit(slot)

## Text einer Slot-Zeile (0-basiert). Oeffentlich fuer den Test: dass ein Slot "leer" anzeigt
## und ein voller seine Kopfdaten, ist die eigentliche Aussage dieses Bildschirms.
func row_text(index: int) -> String:
	return _slot_rows[index].text if index >= 0 and index < _slot_rows.size() else ""

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
	if Input.is_action_just_pressed(&"switch_figure"):
		toggle_delete()
	elif Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"attack"):
		confirm()

func _refresh() -> void:
	for i in _slot_rows.size():
		var marker: String = ">" if _index == i else " "
		var body: String
		if _armed == i + 1:
			body = "loeschen? F ja / Q nein"
		elif _info[i] != null:
			body = _info[i].summary()
		else:
			body = "leer"
		_slot_rows[i].text = "%s Slot %d — %s" % [marker, i + 1, body]
		# Ein leerer Slot ist hier ANWAEHLBAR (er beginnt ein neues Spiel) und darum nicht grau —
		# anders als im Game-Over-Menue, wo derselbe leere Slot nichts zu laden hat.
		_slot_rows[i].modulate = Color(1, 1, 1, 1) if _info[i] != null else Color(0.7, 0.7, 0.7, 1)
	_entry_options.text = "%s Optionen" % (">" if _index == options_index() else " ")
	_entry_quit.text = "%s Beenden" % (">" if _index == quit_index() else " ")
	if _armed != 0:
		_hint.text = "F loescht Slot %d" % _armed
	elif _index < options_index():
		_hint.text = "F waehlen · Q loeschen" if _info[_index] != null else "F beginnt hier"
	else:
		_hint.text = "F waehlen"
