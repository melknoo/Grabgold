class_name PartyManager
extends Node
## Haelt das Ensemble und schaltet die aktive Figur durch (Kickoff: immer nur EINE aktiv,
## kein Party-KI-Code, kein Pathfinding).
##
## Umsetzung: Profil-Tausch am bestehenden Player-Node statt Despawn/Respawn einer zweiten
## Szene. Begruendung siehe docs/progress.md (Phase 4) — kurz: es gibt ohnehin nie zwei Koerper
## in der Welt, und der Tausch erbt Position/Velocity/I-Frames automatisch, statt sie bei jedem
## Wechsel von Hand umzuhaengen.
##
## Per-Figur-Zustand (Health; ab Phase 5 die Korruption) lebt HIER, nicht im Player: er muss den
## Wechsel ueberleben, weil der Reif weitergereicht wird und Korruption extrem langsam abbaut.

signal figure_switched(index: int, profile: FigureProfile)

@export var figures: Array[FigureProfile] = []
@export var player: Player

var _index: int = 0
## Health pro Figur, Index-parallel zu `figures`. -1 = noch nie aktiv gewesen -> beim ersten
## Aktivieren aus `stats.max_health` gefuellt.
var _health: Array[int] = []

func _ready() -> void:
	if figures.is_empty() or player == null:
		push_error("PartyManager: `figures` und `player` muessen gesetzt sein.")
		return
	_health.resize(figures.size())
	_health.fill(-1)
	# Der Player hat sein Startprofil selbst schon angewandt; hier nur den Index synchronisieren.
	var start: int = figures.find(player.profile)
	_index = start if start >= 0 else 0
	_activate(_index, false)

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"switch_figure"):
		switch_next()

func switch_next() -> void:
	if figures.size() < 2 or player == null:
		return
	if not player.can_switch():
		return
	_health[_index] = player.get_health()
	_activate((_index + 1) % figures.size(), true)

## `reset_state` false = Initialisierung (Player steht schon), true = echter Wechsel.
func _activate(index: int, reset_state: bool) -> void:
	_index = index
	var profile: FigureProfile = figures[_index]
	player.apply_profile(profile)
	if _health[_index] < 0:
		_health[_index] = profile.stats.max_health
	player.set_health(_health[_index])
	if reset_state:
		# Die neue Figur uebernimmt Position und Facing, startet aber aus dem Stand: sonst erbt
		# der Zwerg die Vollgeschwindigkeit des Kuriers und der Tempo-Unterschied waere unsichtbar.
		player.velocity = Vector2.ZERO
		player.state_machine.transition_to(&"idle")
	figure_switched.emit(_index, profile)

func active_index() -> int:
	return _index

func active_profile() -> FigureProfile:
	return figures[_index] if _index < figures.size() else null
