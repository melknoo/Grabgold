extends Node
## Autoload "HitstopManager". Friert einzelne Nodes fuer N Physik-Frames ein — OHNE
## Engine.time_scale (das traefe UI/Partikel). Zaehlt in _physics_process (60 Hz Tick).
## Ein pausiertes Ziel (PROCESS_MODE_DISABLED) friert Bewegung UND Animation (Kinder inklusive),
## rendert aber weiter -> klassischer Freeze-Frame. Erwartet Nodes mit Default-process_mode.

var _frozen: Dictionary = {}  # Node -> verbleibende Frames (int)

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

func _physics_process(_delta: float) -> void:
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
