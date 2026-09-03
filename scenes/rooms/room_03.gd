class_name Room03
extends Room
## Raum 03 (C) — Gruftkammer (Phase 12). Der Raum zum Durchatmen, aber nicht umsonst: der
## Speicherpunkt liegt HINTER dem Waechter, und am Waechter kommt man nur mit einem der Verben
## vorbei (Reif, Dash, oder die Figur, die den Schaden aushaelt).
##
## Der Waechter ist keine neue Gegner-KLASSE, sondern `actors/enemy/waechter.tscn`: dieselbe
## `Skeleton`-Maschine, anderes Sheet (SkeletonDemon), anderes `TuningStats`-`.tres`. Eine neue
## Gegnerart ist damit ein Tool-Eintrag plus ein `.tres` — kein Code, dieselbe Regel wie beim
## Figuren-Ensemble (Phase 4).
##
## Er traegt eine `persist_id` und bleibt darum tot (Phase 9), im Gegensatz zu den drei
## Skeletten in B. Das ist der Unterschied zwischen einem Kampf, den der Raum stellt, und einem
## Gegner, den man einmal aus dem Weg raeumt.

## Nur fuer die Debug-Zeile. Kein `@onready`-Feld und keine gemerkte Referenz: wer den Waechter
## im letzten Durchgang erledigt hat, betritt den Raum ohne ihn — `Skeleton._ready` raeumt sich
## dann selbst weg (`queue_free`), und eine gemerkte, typisierte Referenz waere genau der Fall,
## vor dem CLAUDE.md > Regel Null warnt.
func _guard() -> Skeleton:
	var node := get_node_or_null(^"Waechter") as Skeleton
	if node == null or node.is_queued_for_deletion():
		return null
	return node

func debug_text() -> String:
	var guard: Skeleton = _guard()
	if guard == null:
		return "Waechter erledigt"
	return "Waechter %d/%d" % [guard.get_health(), guard.stats.max_health]
