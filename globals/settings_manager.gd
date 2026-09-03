extends Node
## Autoload "Settings" (Phase 11). Spieler-EINSTELLUNGEN — nicht Spielstand, nicht Fortschritt.
##
## Aufteilung der Autoloads, vierter Besitzer: der `RoomManager` besitzt den Raum, der
## `SaveManager` den Fortschritt, der `AudioManager` den Ton, dieser hier die Einstellungen.
## Er liegt bewusst NICHT im Spielstand: eine Lautstaerke gehoert dem Geraet, nicht dem
## Durchlauf — wer Slot 2 laedt, will nicht die Pegel von Slot 1.
##
## Warum `ConfigFile` und nicht JSON wie `SaveData` (Phase 9): fuer Einstellungen ist es die
## Einrichtung der Engine, sie ist von Hand lesbar (INI), und `get_value(section, key, default)`
## traegt ein spaeter dazukommendes Feld von selbst — genau die Eigenschaft, die in Phase 9 fuer
## JSON gesprochen hat. Eine Versionsnummer braucht sie darum nicht: eine unbekannte Datei
## verliert hier hoechstens eine Lautstaerke, waehrend ein halb angewandter Spielstand ein
## kaputtes Spiel waere.
##
## Der Pegel wird als STUFE 0..10 gehalten, nicht als dB: das ist, was die UI anzeigt und was
## der Spieler einstellt. Und er ist RELATIV zur Vorgabe aus `default_bus_layout.tres` — Stufe
## 10 heisst "wie der Autor es gemischt hat" (Musik -9 dB), nicht "0 dB". Sonst haette der
## erste Griff an den Regler die Mischung der Phase 10 eingerissen.

## Eine Einstellung hat sich geaendert (Andockpunkt fuer eine Anzeige).
signal changed

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "audio"

## Stufen von 0 (stumm) bis STEPS (Vorgabe des Mixes).
const STEPS := 10

## Stufe 0 ist echte Stille, nicht "sehr leise": `linear_to_db(0.0)` waere -inf.
const SILENT_DB := -80.0

## Reihenfolge = Reihenfolge im Optionsmenue. Master zuerst, weil er die anderen beiden traegt.
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX"]

## Anzeigenamen. Deutsch wie die uebrige UI; die Bus-Namen selbst bleiben englisch, weil sie im
## generierten Layout stehen.
const LABELS: Dictionary[StringName, String] = {
	&"Master": "Gesamt",
	&"Music": "Musik",
	&"SFX": "Effekte",
}

## Zur Laufzeit umsetzbar, damit die Testszene NICHT die echte Einstellungsdatei des Users
## anfasst (gleicher Grund wie `SaveManager.save_dir`, Phase 9).
var path: String = DEFAULT_PATH

var _steps: Dictionary[StringName, int] = {}
## Die Vorgabe aus dem Bus-Layout, EINMAL beim Start gelesen. Sie ist der Nullpunkt jedes
## Reglers — danach steht im AudioServer schon ein verstellter Wert, und ein zweites Auslesen
## wuerde die eigene Einstellung als Vorgabe missverstehen.
var _default_db: Dictionary[StringName, float] = {}


func _ready() -> void:
	for bus: StringName in BUSES:
		_default_db[bus] = AudioManager.bus_db(bus) if AudioManager.has_bus(bus) else 0.0
		_steps[bus] = STEPS
	load_from_disk()
	apply()


func label(bus: StringName) -> String:
	return LABELS.get(bus, String(bus))


func volume_step(bus: StringName) -> int:
	return _steps.get(bus, STEPS)


## Fuer die Anzeige. Ueber `float` gerechnet, damit `STEPS` sich aendern darf, ohne dass hier
## eine Ganzzahldivision still das Falsche tut.
func volume_percent(bus: StringName) -> int:
	return int(round(100.0 * float(volume_step(bus)) / float(STEPS)))


## Stufe setzen, anwenden, schreiben. Geschrieben wird bei JEDEM Schritt und nicht erst beim
## Schliessen des Menues: drei Zeilen INI kosten nichts, und ein "dirty"-Merker waere ein
## Zustand, den man falsch machen kann.
func set_volume_step(bus: StringName, step: int) -> void:
	if not _steps.has(bus):
		push_error("Settings: unbekannter Bus '%s'." % bus)
		return
	var next: int = clampi(step, 0, STEPS)
	if next == _steps[bus]:
		return
	_steps[bus] = next
	_apply_bus(bus)
	save()
	changed.emit()


## Alle Pegel in den AudioServer. Beim Start und nach dem Laden.
func apply() -> void:
	for bus: StringName in BUSES:
		_apply_bus(bus)


func _apply_bus(bus: StringName) -> void:
	if not AudioManager.has_bus(bus):
		return
	AudioManager.set_bus_db(bus, db_for(bus))


## Stufe -> dB. Relativ zur Vorgabe des Mixes (siehe Kopf).
func db_for(bus: StringName) -> float:
	var step: int = volume_step(bus)
	if step <= 0:
		return SILENT_DB
	return _default_db.get(bus, 0.0) + linear_to_db(float(step) / float(STEPS))


## Alles auf Vorgabe. Oeffentlich, weil ein Optionsmenue das braucht, sobald es mehr als drei
## Regler hat — und weil der Test einen definierten Ausgangszustand braucht.
func reset() -> void:
	for bus: StringName in BUSES:
		_steps[bus] = STEPS
	apply()
	save()
	changed.emit()


func save() -> bool:
	var cfg := ConfigFile.new()
	for bus: StringName in BUSES:
		cfg.set_value(SECTION, String(bus), _steps[bus])
	var err: int = cfg.save(path)
	if err != OK:
		push_error("Settings: '%s' nicht schreibbar (%d)." % [path, err])
		return false
	return true


## Datei lesen. Eine fehlende oder kaputte Datei ist KEIN Fehler — es ist der erste Start.
##
## Uebernommen wird SCHLUESSEL FUER SCHLUESSEL, und nur was da ist und eine Zahl ist. Das ist
## der Unterschied zum Spielstand (Phase 9), wo `from_dict()` alles oder nichts anwendet: ein
## unbrauchbarer Wert kostet hier eine Lautstaerke, kein Spiel. Ein fehlender Schluessel laesst
## den laufenden Wert stehen, statt ihn auf die Vorgabe zurueckzusetzen — sonst wuerde eine
## halb geschriebene Datei die anderen Regler mitreissen.
##
## `ConfigFile` ist dabei nachsichtig: Zeilen, die es nicht versteht, ueberliest es und meldet
## trotzdem OK. Genau darum kann der Rueckgabewert nicht die Pruefung sein.
func load_from_disk() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	for bus: StringName in BUSES:
		var key: String = String(bus)
		if not cfg.has_section_key(SECTION, key):
			continue
		var raw: Variant = cfg.get_value(SECTION, key)
		if raw is not int and raw is not float:
			continue
		_steps[bus] = clampi(int(raw), 0, STEPS)
	return true


func has_file() -> bool:
	return FileAccess.file_exists(path)
