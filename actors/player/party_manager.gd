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
## Eine Figur ist ausgefallen (0 HP). Sie bleibt draussen, bis der Raum neu startet.
signal figure_downed(index: int, profile: FigureProfile)
## Keine Figur steht mehr — Game Over. Wer darauf reagiert, ist der Bootstrap (scenes/main.gd).
signal party_wiped
## Ein Wechsel wurde verweigert, weil der Reif ihn sperrt (Korruptionsstufe 4). Ohne dieses Signal
## waere die Sperre voellig stumm — man druecke Q und nichts passiert, was wie ein Bug aussieht.
signal switch_refused
## Ein Speicherpunkt hat das Ensemble aufgefrischt (Phase 9). Andockpunkt fuer Ton/Effekt —
## und die Stelle, an der ein Test nachweist, dass die Korruption dabei NICHT mitfaellt.
signal party_restored

@export var figures: Array[FigureProfile] = []
@export var player: Player

var _index: int = 0
## Health pro Figur, Index-parallel zu `figures`. -1 = noch nie aktiv gewesen -> beim ersten
## Aktivieren aus `stats.max_health` gefuellt.
var _health: Array[int] = []
## Korruption pro Figur, Index-parallel zu `figures`. Startet bei 0.0. DAS ist die Umsetzung von
## "der Reif ist jederzeit weiterreichbar": wechseln heisst den Ring uebergeben — die Korruption
## bleibt bei der Figur, die sie sich geholt hat, und baut extrem langsam ab.
var _corruption: Array[float] = []

func _ready() -> void:
	if figures.is_empty() or player == null:
		push_error("PartyManager: `figures` und `player` muessen gesetzt sein.")
		return
	_health.resize(figures.size())
	_health.fill(-1)
	_corruption.resize(figures.size())
	_corruption.fill(0.0)
	# Der Player hat sein Startprofil selbst schon angewandt; hier nur den Index synchronisieren.
	var start: int = figures.find(player.profile)
	_index = start if start >= 0 else 0
	_activate(_index, false)
	player.downed.connect(_on_player_downed)

func _physics_process(_delta: float) -> void:
	# Waehrend eines Raumwechsels ist der Input gesperrt (Phase 8) — sonst koennte man mitten in
	# der Blende die Figur tauschen und im neuen Raum stuende eine andere als beim Losgehen.
	if player != null and player.is_input_locked():
		return
	if Input.is_action_just_pressed(&"switch_figure"):
		switch_next()

func switch_next() -> void:
	if figures.size() < 2 or player == null:
		return
	if not player.is_neutral():
		return
	if not player.can_switch():
		# Handlungsfaehig, aber der Reif sperrt (Stufe 4) -> das ist eine Aussage, kein Nichts.
		player.flash_refusal()
		AudioManager.play(&"switch_refused")
		switch_refused.emit()
		return
	var next: int = _next_standing(_index)
	if next < 0:
		return  # niemand sonst steht mehr
	_health[_index] = player.get_health()
	_corruption[_index] = player.get_corruption()
	_activate(next, true)
	# Der Klang haengt am FREIWILLIGEN Wechsel, nicht in `_activate`: das laeuft auch beim Laden,
	# beim Wiederbeleben und beim Zwangswechsel nach einem Ausfall — ein Spielstand soll nicht
	# chirpen, und der Ausfall hat seinen eigenen Klang.
	AudioManager.play(&"switch_figure")

## Die aktive Figur ist auf 0 HP. Sie bleibt draussen — es gibt keinen Health-Reset mehr.
func _on_player_downed() -> void:
	_health[_index] = 0
	_corruption[_index] = player.get_corruption()
	var fallen: int = _index
	AudioManager.play(&"figure_down")
	figure_downed.emit(fallen, figures[fallen])
	var next: int = _next_standing(fallen)
	if next < 0:
		party_wiped.emit()
		return
	# Zwangswechsel: umgeht `can_switch()` bewusst. Die Sperre schuetzt einen laufenden Schlag und
	# haelt ab Stufe 4 den Fluch fest — aber eine ausgefallene Figur MUSS weichen, sonst haette
	# Korruptionsstufe 4 ein totes Spiel zur Folge.
	_activate(next, true)

## Naechste Figur im Kreis, die noch steht. -1 = keine mehr. `-1` in `_health` heisst
## "noch nie aktiv gewesen" und zaehlt als stehend.
func _next_standing(from: int) -> int:
	for step in range(1, figures.size()):
		var idx: int = (from + step) % figures.size()
		if _health[idx] != 0:
			return idx
	return -1

func is_downed(index: int) -> bool:
	return index < _health.size() and _health[index] == 0

func standing_count() -> int:
	var n: int = 0
	for hp: int in _health:
		if hp != 0:
			n += 1
	return n

## Vollstaendiger Reset des Ensembles (Raum-Neustart nach Game Over). Auch die Korruption faellt
## auf 0 — sonst startet man neu und ist sofort wieder auf Stufe 4.
func revive_all() -> void:
	for i in _health.size():
		_health[i] = -1
		_corruption[i] = 0.0
	_activate(0, true)

## Speicherpunkt (Phase 9): Health voll, ausgefallene Figuren stehen wieder — die KORRUPTION
## bleibt, bei jeder Figur. Absicht: sie ist die Langzeitschuld des Reifs ("baut extrem langsam
## ab", Phase 5). Ein Speicherpunkt, der sie mitwaescht, macht sie folgenlos; einer, der
## ausgefallene Figuren draussen laesst, macht den Ausfall bis zum Game Over unumkehrbar.
func restore_all() -> void:
	for i in _health.size():
		_health[i] = figures[i].stats.max_health
	if player != null:
		player.set_health(_health[_index])
	party_restored.emit()

## Health aller Figuren (Phase 9, zum Speichern). Die AKTIVE Figur haelt ihren Wert im Player —
## `_health[_index]` ist zwischen zwei Wechseln veraltet und wuerde die Verletzungen der
## laufenden Sitzung verschlucken.
func health_array() -> Array[int]:
	var out: Array[int] = []
	for i in _health.size():
		out.append(player.get_health() if i == _index and player != null else _health[i])
	return out

## Korruption aller Figuren (Phase 9). Gleiche Begruendung wie oben.
func corruption_array() -> Array[float]:
	var out: Array[float] = []
	for i in _corruption.size():
		out.append(corruption_of(i))
	return out

## Ensemble-Zustand aus einem Spielstand (Phase 9). Kuerzere oder laengere Listen (Savefile aus
## einer Fassung mit anderem Ensemble) werden zugeschnitten statt abgelehnt: der Slot ist sonst
## unbrauchbar, obwohl Raum und Fortschritt darin noch gueltig sind.
##
## Eine ausgefallene Figur wird nie aktiv gesetzt — das ist dieselbe Invariante wie beim
## Zwangswechsel (Phase 7): wer 0 HP hat, steuert nicht.
func apply_state(index: int, health: Array[int], corruption: Array[float]) -> void:
	for i in _health.size():
		if i < health.size():
			_health[i] = health[i]
		if i < corruption.size():
			_corruption[i] = corruption[i]
	var target: int = clampi(index, 0, figures.size() - 1)
	if _health[target] == 0:
		_index = target
		target = _next_standing(target)
		if target < 0:
			# Alle ausgefallen — so ein Slot kann nicht entstehen (Game Over speichert nicht),
			# aber ein von Hand editierter waere sonst ein Spiel ohne steuerbare Figur.
			push_warning("PartyManager: Spielstand ohne stehende Figur -> volle Wiederherstellung.")
			revive_all()
			return
	_activate(target, true)

## `reset_state` false = Initialisierung (Player steht schon), true = echter Wechsel.
func _activate(index: int, reset_state: bool) -> void:
	_index = index
	var profile: FigureProfile = figures[_index]
	player.apply_profile(profile)
	# Wer das Feld betritt, ist wieder verwundbar. Das hebt die Ausfall-Sperre aus Phase 9 auf —
	# egal ob sie ueber `revive_all`, `restore_all`, einen geladenen Spielstand oder den
	# Zwangswechsel zurueckgenommen wird. Es gibt damit genau EINE Stelle dafuer.
	player.set_defeated(false)
	if _health[_index] < 0:
		_health[_index] = profile.stats.max_health
	player.set_health(_health[_index])
	player.set_corruption(_corruption[_index])
	# Die neue Stufe uebernehmen, ohne sie als Ereignis zu melden (Phase 10, siehe dort).
	if player.reif != null:
		player.reif.sync_level()
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

## Korruption einer inaktiven Figur (fuers Debug-Overlay und die Tests). Die aktive Figur haelt
## ihren Wert im Player, nicht hier.
func corruption_of(index: int) -> float:
	if index == _index and player != null:
		return player.get_corruption()
	return _corruption[index] if index < _corruption.size() else 0.0
