extends CanvasLayer
## Feedback fuer Korruptionsstufe 1 (Phase 5): entsaettigte Bildschirmraender, Intensitaet an den
## Korruptionswert der aktiven Figur gekoppelt.
##
## Stufe 2 (Dash-Drift) hat bewusst KEIN eigenes visuelles Feedback — er soll sich wie ein Bug
## anfuehlen, nicht wie eine angekuendigte Strafe (Kickoff).
##
## Der zweite Teil von Stufe 1, "Fluestern im Sound-Mix", fehlt noch: das Projekt hat bislang
## keinerlei Audio-Infrastruktur. Siehe docs/assets-todo.md.

## Sichtbare Grundstaerke, sobald Stufe 1 erreicht ist — sonst waere der Einstieg in die Stufe
## unsichtbar (Intensitaet exakt 0 an der Schwelle).
const ONSET: float = 0.25

@onready var rect: ColorRect = $Vignette

var _player: Player = null

func _ready() -> void:
	visible = false

func _process(_dt: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_bind_player()
		return
	_apply(_player.get_corruption())

func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player

func _apply(corruption: float) -> void:
	var stats: ReifStats = _player.reif.stats
	if stats == null or _player.reif.level() < 1:
		visible = false
		return
	var onset_at: float = stats.level_thresholds[0]
	var span: float = maxf(1.0, stats.corruption_max - onset_at)
	var ratio: float = clampf((corruption - onset_at) / span, 0.0, 1.0)
	visible = true
	(rect.material as ShaderMaterial).set_shader_parameter(
		&"intensity", ONSET + (1.0 - ONSET) * ratio)

## Fuer die headless-Verifikation: der aktuell gesetzte Shader-Parameter.
func intensity() -> float:
	if not visible:
		return 0.0
	return (rect.material as ShaderMaterial).get_shader_parameter(&"intensity")
