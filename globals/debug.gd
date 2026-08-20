extends Node
## Autoload "Debug". Globale Debug-Schalter fuer das Combat-Tuning.
## Hitbox/Hurtbox-Nodes lauschen auf boxes_toggled und zeichnen ihre Shapes, wenn show_boxes true.

signal boxes_toggled(shown: bool)

var show_boxes: bool = false

func toggle_boxes() -> void:
	show_boxes = not show_boxes
	boxes_toggled.emit(show_boxes)
