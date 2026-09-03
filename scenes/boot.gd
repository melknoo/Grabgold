class_name Boot
extends Node
## HUELLE und Startpunkt des Spiels (Phase 11) — `run/main_scene`.
##
## Bis Phase 10 war `scenes/main.tscn` die Startszene und baute sich in `_ready` selbst den
## Startraum. Damit gab es nie einen Zustand "Spiel laeuft nicht", und genau darum verschob
## Phase 9 das Hauptmenue: "es waere eine eigene Szene VOR der persistenten Weltszene und damit
## ein eigener Umbau". Diese Datei IST dieser Umbau.
##
## Die Schichtung ist jetzt drei tief, und jede Schicht wird von der darueber weggeworfen:
##
##   Boot (nie gewechselt)   Menues, Optionen, Pause — die Huelle
##     +- WorldHost
##          +- main.tscn     persistente Weltszene: Player, PartyManager, Overlays
##               +- RoomHost
##                    +- room_0N.tscn   vom RoomManager getauscht (Phase 8)
##
## Warum die Menues hier und nicht in der Weltszene liegen: das Hauptmenue muss ohne Welt
## existieren, und Optionen und Pause teilen sich einen Bildschirm mit ihm. Das Game-Over-Menue
## bleibt dagegen in der Weltszene — es gehoert zum Sterben, nicht zur Huelle.
##
## Es liest KEIN Menue in demselben Frame denselben Tastendruck: wer einen anderen Bildschirm
## aufmacht, blendet seinen eigenen aus (`close()`), und jeder Bildschirm hat einen Frame
## Schonzeit nach dem Oeffnen. Sonst schluege der `pause`-Druck, der die Optionen aufmacht, im
## Pausenmenue gleich nochmal zu.

const WORLD_SCENE := "res://scenes/main.tscn"

## Wohin der Optionen-Bildschirm zurueckfuehrt. Er hat zwei Aufrufer, und "zurueck" heisst bei
## jedem etwas anderes.
enum OptionsFrom { MAIN, PAUSE }

@onready var world_host: Node = $WorldHost
@onready var main_menu: MainMenu = $MainMenu
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var options_menu: OptionsMenu = $OptionsMenu

var _world: World = null
var _options_from: OptionsFrom = OptionsFrom.MAIN

func _ready() -> void:
	main_menu.new_game_requested.connect(_on_new_game_requested)
	main_menu.load_requested.connect(_on_load_requested)
	main_menu.options_requested.connect(_on_options_from_main)
	main_menu.quit_requested.connect(_on_quit_requested)
	pause_menu.resume_requested.connect(_on_resume_requested)
	pause_menu.options_requested.connect(_on_options_from_pause)
	pause_menu.main_menu_requested.connect(open_main_menu)
	options_menu.closed.connect(_on_options_closed)
	open_main_menu()

## Die laufende Welt, oder `null`. Fuer den Test — im Spiel fragt niemand danach.
func world() -> World:
	return _world

func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


# --- Hauptmenue -------------------------------------------------------------------------------

## Zurueck in die Huelle: die Welt wird WEGGEWORFEN, nicht angehalten. Ein Spiel, das im
## Hintergrund des Hauptmenues weiterlebte, waere ein zweiter Weltzustand neben dem Spielstand —
## und die Frage "welcher gilt" hat keine gute Antwort. Wer weitermachen will, drueckt Weiter.
func open_main_menu() -> void:
	pause_menu.close()
	_free_world()
	# Der Game-Over-Jingle darf nicht unter dem Hauptmenue weiterlaufen (Phase 10).
	AudioManager.stop_jingle()
	AudioManager.play_music(&"title")
	main_menu.open()

func _free_world() -> void:
	if not has_world():
		_world = null
		return
	# `remove_child` ZUSAETZLICH zu `queue_free` — Muster aus `RoomManager._swap_room`:
	# `queue_free` laesst den Node bis zum Frame-Ende im Baum, und der RoomManager loest seine
	# Referenzen erst am `tree_exiting` des RoomHost.
	world_host.remove_child(_world)
	_world.queue_free()
	_world = null
	# Die Blende des Raumwechsels lebt im Autoload und ueberlebt jede Welt. Bleibt sie schwarz
	# stehen, liegt sie beim naechsten Spielstart ueber dem ersten Frame des Raums.
	RoomManager.clear_fade()

func _on_new_game_requested(slot: int) -> void:
	main_menu.close()
	_build_world()
	# Der Slot ist ab jetzt der, in den jeder Speicherpunkt schreibt. Bis Phase 10 war das immer
	# der Vorgabewert 1, und der Spieler konnte nirgends sehen, welcher es war.
	SaveManager.active_slot = slot
	SaveManager.new_game()

func _on_load_requested(slot: int) -> void:
	main_menu.close()
	_build_world()
	if SaveManager.load_from_slot(slot):
		return
	# Der Slot ist zwischen Anzeige und Auswahl kaputtgegangen oder verschwunden. Zurueck ins
	# Menue, statt den Spieler in einer leeren Szene sitzen zu lassen — dieselbe Zustaendigkeit,
	# die in `scenes/main.gd` das Game-Over-Menue wieder aufmacht (Phase 9).
	open_main_menu()

func _build_world() -> void:
	var scene: PackedScene = load(WORLD_SCENE) as PackedScene
	_world = scene.instantiate() as World
	# MUSS vor `add_child` stehen: dort laeuft `_ready`, und dort betrat die Weltszene bis
	# Phase 10 blind den Startraum. Wer eintritt — Startraum oder Spielstand — entscheidet sich
	# hier, eine Zeile weiter unten.
	_world.enter_on_ready = false
	_world.main_menu_requested.connect(open_main_menu)
	world_host.add_child(_world)


# --- Pause ------------------------------------------------------------------------------------

## `pause` im laufenden Spiel. Gelesen wird die Taste HIER und nicht in der Weltszene: das
## Pausenmenue gehoert der Huelle, und nur die Huelle weiss, ob gerade ein anderer Bildschirm
## offen ist.
func _physics_process(_delta: float) -> void:
	if not has_world():
		return
	if main_menu.is_open() or pause_menu.is_open() or options_menu.is_open():
		return
	# Nicht waehrend einer Blende (der Input ist dort schon gesperrt) und nicht im Game Over:
	# dort haelt die Welt bereits, und das Game-Over-Menue ist zustaendig.
	if RoomManager.is_transitioning() or not _world.accepts_pause():
		return
	if Input.is_action_just_pressed(&"pause"):
		open_pause()

## Oeffentlich, damit ein Test pausieren kann, ohne die Taste zu fahren.
func open_pause() -> void:
	if not has_world() or pause_menu.is_open():
		return
	_world.set_paused(true)
	pause_menu.open()

func _on_resume_requested() -> void:
	if has_world():
		_world.set_paused(false)


# --- Optionen ---------------------------------------------------------------------------------

func _on_options_from_main() -> void:
	_options_from = OptionsFrom.MAIN
	main_menu.close()
	options_menu.open()

func _on_options_from_pause() -> void:
	_options_from = OptionsFrom.PAUSE
	# Das Pausenmenue geht zu, die PAUSE bleibt: der Raum ist eingefroren und der Input gesperrt,
	# bis "Weiter" gedrueckt wird.
	pause_menu.close()
	options_menu.open()

func _on_options_closed() -> void:
	# `keep_selection`: der Spieler soll auf dem Eintrag "Optionen" wieder aufsetzen, den er
	# gerade gedrueckt hat, und nicht am Listenanfang.
	if _options_from == OptionsFrom.PAUSE and has_world():
		pause_menu.open(true)
	else:
		main_menu.open(true)

func _on_quit_requested() -> void:
	get_tree().quit()
