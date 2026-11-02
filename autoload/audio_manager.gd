extends Node
## Music and sound effects. Music follows the kit's audio.md: it never starts
## before the player's first tap, crossfades between scenes, ducks while paused
## or waiting for a duel's bell, stops on failure, and obeys both the sound
## switch and the separate music switch.

const FADE := 0.5
const SFX_VOICES := 10

var sound_on := true
var music_on := true

var _unlocked := false
var _want: String = ""
var _current: String = ""
var _duck := 1.0
var _cues := {}
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _sting: AudioStreamPlayer
var _sfx_streams := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice := 0
## The last effect asked for and its pitch (the tests check feedback with them).
var last_sfx := ""
var last_pitch := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sound_on = SaveManager.get_setting("sound", true)
	music_on = SaveManager.get_setting("music", true)
	var loops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.MUSIC_DIR + "loop_points.json"))
	for cue in loops:
		var stream: AudioStreamOggVorbis = load(GameState.MUSIC_DIR + cue + ".ogg")
		stream.loop = not loops[cue].plays_once
		stream.loop_offset = loops[cue].loop_start_seconds
		_cues[cue] = stream
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	_sting = AudioStreamPlayer.new()
	add_child(_sting)
	_sfx_streams = SfxSynth.build_all()
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)


## Call on the first tap; music is held until then.
func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	if _want != "":
		var w := _want
		_want = ""
		play(w)


func play(cue: String) -> void:
	if not _unlocked:
		_want = cue
		return
	if cue == _current and _players[_active].playing:
		return
	_current = cue
	var old := _players[_active]
	_active = 1 - _active
	var p := _players[_active]
	p.stream = _cues[cue]
	p.volume_db = -60.0
	if _music_live():
		p.play()
	_fade(p, _target_db())
	_fade(old, -80.0, true)


func stop() -> void:
	_current = ""
	_want = ""
	_fade(_players[_active], -80.0, true)


func sting(cue: String) -> void:
	stop()
	if _unlocked and _music_live():
		_sting.stream = _cues[cue]
		_sting.volume_db = 0.0
		_sting.play()


## 1.0 is full volume; the prototype ducks to 0.3 when paused and 0.35 while waiting for a bell.
func duck(amount: float) -> void:
	_duck = amount
	if _current != "":
		_fade(_players[_active], _target_db(), false, 0.25)


func set_sound(on: bool) -> void:
	sound_on = on
	SaveManager.set_setting("sound", on)
	_refresh()


func set_music(on: bool) -> void:
	music_on = on
	SaveManager.set_setting("music", on)
	_refresh()


## pitch: 1 as rendered; FeedbackDirector varies it a little so repeated sounds never sound canned.
func sfx(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	last_sfx = name  # for the tests
	last_pitch = pitch
	if not sound_on:
		return
	var p := _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	p.stream = _sfx_streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func _music_live() -> bool:
	return sound_on and music_on


func _target_db() -> float:
	return linear_to_db(maxf(0.001, _duck)) - 4.0


func _refresh() -> void:
	var p := _players[_active]
	if not _music_live():
		p.stop()
		_sting.stop()
	elif _current != "" and not p.playing and _unlocked:
		p.play()
		_fade(p, _target_db())


func _fade(p: AudioStreamPlayer, db: float, stop_after := false, time := FADE) -> void:
	var tw := create_tween()
	tw.tween_property(p, "volume_db", db, time)
	if stop_after:
		tw.tween_callback(p.stop)
