class_name TuningStats
extends Resource
## Zentrale Feel-Tuning-Resource. ALLE Feel-Werte hier, NIE im Skript (siehe CLAUDE.md >
## "Feel-Tuning -> Resource"). Pro Aktor ein eigenes .tres. An Animation gekoppelte Timings
## stehen in FRAMES (int, 60 FPS Physik-Tick), nicht in Sekunden.

@export_group("Movement")
## Vollgeschwindigkeit in px/s.
@export var max_speed: float = 95.0
## Beschleunigung in px/s^2. BEWUSST hoch: Vollspeed in ~2-3 Physik-Frames (95/2400 s ~= 2.4 F).
## ALTTP-Tempo, kein Metroidvania-Momentum. Siehe CLAUDE.md > Movement- und Combat-Konventionen
## (Punkt 1): NICHT ohne Ruecksprache senken — aendert das Spielgefuehl grundlegend.
@export var acceleration: float = 2400.0
## Reibung in px/s^2. Stopp nahezu instant (95/3200 s ~= 1.8 F). Gleiche Regel wie acceleration.
@export var friction: float = 3200.0

@export_group("Attack Timing (Frames)")
## Abgeleitet aus Pack: NinjaGreen Attack = 4 Sprite-Frames (Separate/Attack.png, 4x4 @32px).
## Bei 3 Engine-Frames/Sprite-Frame -> 12 Engine-Frames gesamt (0.2s @60 FPS): Frame0=Startup,
## Frames1-2=Active (Hitbox an, ab Phase 2), Frame3=Recovery. Facing gesperrt Startup..Active-Ende
## (CLAUDE.md > Movement- und Combat-Konventionen, Punkt 3).
@export var attack_startup_frames: int = 3
@export var attack_active_frames: int = 6
@export var attack_recovery_frames: int = 3

@export_group("Attack Reach (Phase 4)")
## Abstand der Hitbox-Mitte vom Aktor-Zentrum in px, in Facing-Richtung. War bis Phase 3 eine
## const im Player-Skript; ist ein Feel-/Reichweiten-Wert und muss pro Figur unterschiedlich
## sein (32px-Ninja vs. 16px-Knight), darum hier.
@export var hitbox_offset: float = 13.0

@export_group("Hit Feedback (Phase 2)")
@export var knockback_speed: float = 220.0
@export var knockback_curve: Curve
@export var knockback_duration: float = 0.18
@export var hitstop_frames: int = 6

@export_group("Defense (Phase 2)")
## Faktor auf den EINGESTECKTEN Knockback. 1.0 = wird normal weggestossen, 0.0 = steht wie ein
## Fels (Zwerg, Phase 4). Absichtlich float und kein bool: Zwischenwerte sind tunebar.
@export var knockback_taken_scale: float = 1.0
@export var iframe_duration: float = 0.6
@export var iframe_blink_interval: float = 0.06

@export_group("Input")
@export var attack_buffer_frames: int = 6

@export_group("Combat Numbers")
@export var attack_damage: int = 1
@export var max_health: int = 6
