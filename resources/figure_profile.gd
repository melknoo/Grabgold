class_name FigureProfile
extends Resource
## Eine Figur des Ensembles = Sprite-Satz + Angriffs-Animation + Feel-Werte.
## Bewusst ein Bundle: die drei Teile gehoeren zusammen, weil das Angriffstiming der
## AnimationLibrary aus den Frame-Werten der TuningStats abgeleitet ist (siehe
## tools/build_figure_resources.gd). Ein Profil hier eintragen = eine neue Figur, ohne Code.

## Anzeigename fuers Debug-Overlay. Nicht spielrelevant — der Unterschied muss ohne HUD
## spuerbar sein (Kickoff, Phase 4).
@export var display_name: String = "?"
@export var frames: SpriteFrames
@export var anims: AnimationLibrary
@export var stats: TuningStats
