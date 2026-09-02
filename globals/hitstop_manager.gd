extends Node
## Autoload "HitstopManager". Der EINZIGE Ort, an dem Zeit fuer einzelne Aktoren manipuliert wird —
## OHNE Engine.time_scale (das traefe UI/Partikel). Zaehlt in _physics_process (60 Hz Tick).
##
## Zwei Betriebsarten, beide ueber `process_mode`:
##   1. HITSTOP  (Phase 2): Node fuer N Frames komplett eingefroren -> Freeze-Frame beim Treffer.
##   2. ZEITDEHNUNG (Phase 5, Reif): Node laeuft nur jeden n-ten Frame (Duty-Cycle ueber einen
##      Akkumulator). faktor 0.55 = der Node bekommt 55 % seiner Ticks, bewegt sich also 45 %
##      langsamer und seine Frame-Zaehler laufen entsprechend traeger.
##
## Ein pausiertes Ziel (PROCESS_MODE_DISABLED) friert Bewegung UND Animation (Kinder inklusive),
## rendert aber weiter. Erwartet Nodes mit Default-process_mode.
##
## Hitstop und Zeitdehnung komponieren von selbst, OHNE Sonderfall: der Hitstop trifft den
## Aktor-Body, die Zeitdehnung dessen StateMachine/Sprite. Ein DISABLED-Elternteil schlaegt jedes
## INHERIT im Kind — solange der Hitstop laeuft, steht der Aktor also ganz still, danach greift
## das Duty-Cycle-Gating wieder.

var _frozen: Dictionary = {}  # Node -> verbleibende Frames (int)
var _slowed: Dictionary = {}  # Node -> Akkumulator (float); Faktor in _factor
var _factor: Dictionary = {}  # Node -> Zeitfaktor (float, 0..1)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # laeuft weiter, waehrend Ziele pausiert sind

func hitstop(frames: int, nodes: Array) -> void:
	if frames <= 0:
		return
	for n: Node in nodes:
		if not is_instance_valid(n):
			continue
		_frozen[n] = frames
		# Deferred: process_mode darf nicht mitten im Physics-Callback (area_entered) gesetzt
		# werden (CollisionObject-Warnung + undefiniertes Verhalten).
		n.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)

## Idempotent: erneutes Setzen mit demselben Faktor laesst den Akkumulator stehen, damit der
## Reif jeden Frame stumpf alle Gegner neu registrieren kann (faengt Nachzuegler mit ein).
func set_time_scale(node: Node, factor: float) -> void:
	if not is_instance_valid(node):
		return
	_factor[node] = factor
	if not _slowed.has(node):
		_slowed[node] = 0.0

func clear_time_scale(node: Node) -> void:
	if not _slowed.has(node):
		return
	_slowed.erase(node)
	_factor.erase(node)
	if is_instance_valid(node):
		node.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)

func time_scale_for(node: Node) -> float:
	return _factor.get(node, 1.0)

func is_slowed(node: Node) -> bool:
	return _slowed.has(node)

func _physics_process(_delta: float) -> void:
	_tick_frozen()
	_tick_slowed()

func _tick_frozen() -> void:
	if _frozen.is_empty():
		return
	for n: Node in _frozen.keys():
		if not is_instance_valid(n):
			_frozen.erase(n)
			continue
		_frozen[n] -= 1
		if _frozen[n] <= 0:
			n.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
			_frozen.erase(n)

func _tick_slowed() -> void:
	if _slowed.is_empty():
		return
	for n: Node in _slowed.keys():
		if not is_instance_valid(n):
			_slowed.erase(n)
			_factor.erase(n)
			continue
		var acc: float = _slowed[n] + _factor[n]
		if acc >= 1.0:
			# Dieser Frame gehoert dem Node.
			_slowed[n] = acc - 1.0
			n.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
		else:
			_slowed[n] = acc
			n.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
