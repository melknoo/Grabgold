class_name Room02
extends Room
## Raum 02 (B) — Kampfkammer (Phase 12). Bis Phase 11 war das eine leere Kammer mit einem
## Skelett darin: Testgeruest fuer den Raumwechsel, ausdruecklich kein Content. Jetzt ist es der
## Raum, in dem der Kampf einmal ernst gemeint ist — drei Skelette, vier Saeulen, und ein
## RIEGEL vor dem Ausgang nach C, der erst hochfaehrt, wenn keiner mehr steht.
##
## Warum ein Riegel und keine offene Tuer: bis hierher konnte man jeden Gegner stehen lassen und
## weiterlaufen. Der Kampf war damit optional, und ein Vertical Slice, dessen Prioritaet
## "Kampfgefuehl" heisst, kann sich das an genau einer Stelle nicht leisten. Der Weg ZURUECK
## nach A bleibt offen — eingesperrt wird niemand, man kann sich jederzeit zurueckziehen.
##
## Der Riegel ist dieselbe `Door` wie die Zeittuer in Raum 01, nur ohne Zaehler
## (`open_permanently`). Die Verdrahtung steht hier im Raum, wie schon Platte->Tuer in
## `room_01.gd`: eine Zeile im Raum statt einer Event-Bus-Infrastruktur.

## Welt-Flag (Phase 9), das den einmal geraeumten Raum festhaelt.
##
## Die Skelette bekommen bewusst KEINE `persist_id`: normale Gegner respawnen, das ist die Regel
## seit Phase 8. Aber der Riegel soll nicht zweimal zufallen — wer aus C zurueckkommt, hat den
## Raum schon geraeumt, und ein zweiter Pflichtkampf am selben Riegel waere eine Strafe fuers
## Zurueckgehen. Die Gegner kehren also wieder, der Riegel nicht.
const CLEARED_FLAG := &"gate:room_02"

## Die obere der beiden Riegel-Kacheln — nur als Bezugspunkt fuer Debug-Zeile und Test.
## Geoeffnet werden IMMER alle `Door`-Kinder: die Oeffnung ist zwei Tiles hoch (sonst muesste
## man beim Durchgehen zielen, siehe tools/build_room_resources.gd), und zwei Kacheln heissen
## zwei Tueren. Kein Sonderfall im Code, nur eine Schleife.
@onready var gate: Door = $Riegel

var _cleared: bool = false

func _ready() -> void:
	super()
	if SaveManager.get_flag(CLEARED_FLAG):
		_cleared = true
		# `false`: kein Tuerklang beim Betreten. Der Riegel steht dann seit dem letzten Besuch
		# offen, und ein Geraeusch dafuer waere eine Meldung ueber nichts.
		_open_gate(false)

func is_cleared() -> bool:
	return _cleared

## Gezaehlt werden die EIGENEN Kinder, nicht die Gruppe `enemy`: beim Raumwechsel haengt der alte
## Raum noch einen Frame im Baum (queue_free) — dieselbe Begruendung wie bei `Room.spawn_point`.
## Kinder im Baum sind per Definition gueltige Instanzen, damit stellt sich die Frage nach
## freigegebenen Nodes (CLAUDE.md > Regel Null) hier gar nicht erst.
func enemies_alive() -> int:
	var alive: int = 0
	for child: Node in get_children():
		var enemy := child as Skeleton
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		if enemy.get_health() > 0:
			alive += 1
	return alive

func _physics_process(_delta: float) -> void:
	if _cleared or enemies_alive() > 0:
		return
	_cleared = true
	SaveManager.set_flag(CLEARED_FLAG)
	_open_gate(true)


## Beide Riegel-Kacheln auf einmal. Der doppelte Tuerklang ist keiner: der AudioManager laesst
## eine Klang-ID pro Physik-Frame genau einmal durch (Phase 10).
func _open_gate(announce: bool) -> void:
	for child: Node in get_children():
		var door := child as Door
		if door != null:
			door.open_permanently(announce)

## Die zwei Zahlen, an denen die Abnahme dieses Raums haengt: steht der Riegel richtig, und wie
## viele stehen noch?
func debug_text() -> String:
	return "Riegel %s  Gegner %d" % ["OFFEN" if gate.is_open() else "ZU", enemies_alive()]
