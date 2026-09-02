class_name ReifStats
extends Resource
## Feel-Werte des Reifs (Phase 5). Eigene Resource statt TuningStats, weil der Reif EIN
## Gegenstand ist, der weitergereicht wird — er gehoert keiner Figur. Die einzige figurabhaengige
## Achse (`corruption_gain_scale`) liegt dafuer in TuningStats.
##
## Wie ueberall im Projekt: Werte ausschliesslich im .tres aendern, nie im Code
## (CLAUDE.md > "Feel-Tuning -> Resource"). An Frames gekoppelte Timings als int.

@export_group("Kanalisierung")
## Zeitfaktor fuer Gegner, solange der Reif gehalten wird. 1.0 = keine Dehnung, 0.55 = Gegner
## bekommen 55 % ihrer Ticks. Umgesetzt als Duty-Cycle im HitstopManager, NIE ueber
## Engine.time_scale (CLAUDE.md > Kernmechanik-Merker).
@export_range(0.1, 1.0, 0.05) var time_scale: float = 0.55
## Faktor auf den Angriffsschaden waehrend des Kanals. Kurier 1 -> 2, Zwerg 2 -> 4 (roundi).
@export var damage_multiplier: float = 1.75

@export_group("Phase-Dash")
@export var dash_speed: float = 320.0
## Dauer in Physik-Frames. 320 px/s * 10 F / 60 ~= 53 px Strecke.
@export var dash_frames: int = 10
@export var dash_cooldown_frames: int = 18

@export_group("Korruption")
@export var corruption_max: float = 100.0
## Aufladung pro Sekunde Kanal. 9.0 -> ~11 s Dauerkanal bis zum Anschlag.
@export var corruption_per_second: float = 9.0
## Abbau pro Sekunde ohne Kanal. BEWUSST winzig: "Korruption baut sich extrem langsam ab"
## (Kickoff). 0.4 -> 250 s von voll auf leer. Der Spieler MUSS den Schaden auf seine Leute
## verteilen; wer das aendert, nimmt der Mechanik den Preis.
@export var corruption_decay_per_second: float = 0.4
## Schwellen fuer Stufe 1..4. Phase 5 verdrahtet Feedback nur fuer 1 (Vignette) und 2 (Dash-Drift);
## 3 (schlaegt von selbst zu) und 4 (Wechsel gesperrt) sind vom Zaehler gestuetzt, aber inaktiv.
@export var level_thresholds: Array[float] = [25.0, 55.0, 75.0, 92.0]

@export_group("Stufe 2 — Dash-Drift")
## Wahrscheinlichkeit, dass ein Dash weiter traegt als eingegeben. Soll sich wie ein Bug
## anfuehlen, nicht wie eine Strafe — darum selten und ohne eigenes Feedback.
@export_range(0.0, 1.0, 0.01) var drift_chance: float = 0.22
@export var drift_scale: float = 1.5
