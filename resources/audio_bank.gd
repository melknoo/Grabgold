class_name AudioBank
extends Resource
## Verzeichnis aller Klaenge (Phase 10): Ereignis-ID -> Stream(s).
##
## Warum eine Resource und kein `const`-Dictionary im Autoload: dieselbe Regel, die
## `TuningStats`, `ReifStats`, `FigureProfile` und `RoomRegistry` tragen — ein neuer Klang ist ein
## Eintrag in einer Tabelle, kein Code. Und weil die Streams hier als Ext-Resources drinstehen,
## laedt der Autoload sie mit der Bank in einem Zug und muss zur Laufzeit nichts nachladen.
##
## Diese `.tres` wird GENERIERT (`tools/build_audio_resources.gd`) und nie von Hand editiert —
## dieselbe Regel wie bei `SpriteFrames`, `AnimationLibrary` und den Tilemaps. Die Zuordnung
## "Spielereignis -> Datei im Pack" steht als Tabelle im Tool und damit an genau einer Stelle.

## SFX: ID -> Array von `AudioStream`. Ein Array, weil ein Klang, der bei jedem Treffer identisch
## klingt, nach dem dritten Schlag zu Matsch wird — der AudioManager waehlt zufaellig aus.
## Der Werttyp bleibt untypisiert (`Array`), weil `Dictionary[StringName, Array[AudioStream]]`
## in GDScript kein gueltiger Typausdruck ist; das Tool fuellt ausschliesslich `AudioStream`.
@export var sounds: Dictionary[StringName, Array] = {}

## Musik und Jingles: ID -> genau EIN Stream. Keine Variation — ein Stueck ist ein Stueck.
@export var music: Dictionary[StringName, AudioStream] = {}

func has_sound(id: StringName) -> bool:
	return sounds.has(id) and not (sounds[id] as Array).is_empty()

func has_music(id: StringName) -> bool:
	return music.has(id) and music[id] != null

## Eine Variante des Klangs. `rng` kommt von aussen, damit der AudioManager seinen seedbaren
## Generator benutzt und ein Test die Auswahl deterministisch fahren kann (Muster aus `Reif`).
func pick_sound(id: StringName, rng: RandomNumberGenerator) -> AudioStream:
	if not has_sound(id):
		return null
	var variants: Array = sounds[id]
	if variants.size() == 1:
		return variants[0] as AudioStream
	return variants[rng.randi() % variants.size()] as AudioStream

func music_stream(id: StringName) -> AudioStream:
	return music.get(id, null) as AudioStream

## Anzahl Varianten einer ID (fuer Tests und den Report des Bau-Tools).
func variant_count(id: StringName) -> int:
	return (sounds[id] as Array).size() if sounds.has(id) else 0
