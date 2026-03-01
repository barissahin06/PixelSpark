extends Node

## AudioManager — Autoload singleton for all game audio.
## BGM: background music loop, pauses during modals/battle
## SFX: one-shot effects (sword hit, win/lose)
## UI: ambient modal sounds (kitchen, market, train, upgrade), stops on modal close

# Audio paths
const AUDIO_DIR := "res://assets/audio/"
const BGM_MAIN := AUDIO_DIR + "Eagle_of_the_Arena-main-thema.mp3"
const SFX_SWORD_HIT := AUDIO_DIR + "sword_hit.wav"
const SFX_WIN := AUDIO_DIR + "won_Battle.wav"
const SFX_LOSE := AUDIO_DIR + "lose_Battle.wav"
const UI_KITCHEN := AUDIO_DIR + "Kitchen_UI.wav"
const UI_MARKET := AUDIO_DIR + "Market_Uı.wav"
const UI_TRAIN := AUDIO_DIR + "Train_Uı.wav"
const UI_UPGRADE := AUDIO_DIR + "Upgrade_Uı.wav"

# Players
var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var ui_player: AudioStreamPlayer

# State
var _bgm_paused_position: float = 0.0
var _bgm_was_playing: bool = false

func _ready() -> void:
	# BGM player (loops)
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.volume_db = -10.0 # Slightly quieter
	add_child(bgm_player)
	
	# SFX player (one-shot effects)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	add_child(sfx_player)
	
	# UI player (modal ambient sounds, stops on close)
	ui_player = AudioStreamPlayer.new()
	ui_player.bus = "Master"
	ui_player.volume_db = -5.0
	add_child(ui_player)
	
	# Start BGM
	play_bgm()

# ================= BGM =================

func play_bgm() -> void:
	if not ResourceLoader.exists(BGM_MAIN):
		push_warning("AudioManager: BGM file not found: " + BGM_MAIN)
		return
	var stream = load(BGM_MAIN)
	if stream is AudioStream:
		bgm_player.stream = stream
		# Enable looping for MP3
		if stream is AudioStreamMP3:
			stream.loop = true
		bgm_player.play()

func pause_bgm() -> void:
	if bgm_player.playing:
		_bgm_paused_position = bgm_player.get_playback_position()
		_bgm_was_playing = true
		bgm_player.stop()

func resume_bgm() -> void:
	if _bgm_was_playing and not bgm_player.playing:
		bgm_player.play(_bgm_paused_position)
		_bgm_was_playing = false

func stop_bgm() -> void:
	bgm_player.stop()
	_bgm_was_playing = false
	_bgm_paused_position = 0.0

# ================= SFX =================

func play_sfx(sound_name: String) -> void:
	var path = ""
	match sound_name:
		"sword_hit": path = SFX_SWORD_HIT
		"win": path = SFX_WIN
		"lose": path = SFX_LOSE
		_:
			push_warning("AudioManager: Unknown SFX: " + sound_name)
			return
	
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: SFX file not found: " + path)
		return
	sfx_player.stream = load(path)
	sfx_player.play()

# ================= UI Sounds =================

func play_ui(sound_name: String) -> void:
	var path = ""
	match sound_name:
		"kitchen": path = UI_KITCHEN
		"market": path = UI_MARKET
		"train": path = UI_TRAIN
		"upgrade": path = UI_UPGRADE
		_:
			push_warning("AudioManager: Unknown UI sound: " + sound_name)
			return
	
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: UI sound not found: " + path)
		return
	ui_player.stream = load(path)
	ui_player.play()

func stop_ui() -> void:
	ui_player.stop()
