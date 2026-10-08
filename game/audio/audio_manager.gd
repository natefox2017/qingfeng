extends Node

const BACKGROUND_PATH := "res://assets/audio/bg.mp3"
const BUTTON_CLICK_PATH := "res://assets/audio/button_click.ogg"
const BUTTON_FOCUS_PATH := "res://assets/audio/button_focus.ogg"
const AUDIO_BUS := "Master"
const MUSIC_LOOP_ENABLED := true

var music_player: AudioStreamPlayer
var click_player: AudioStreamPlayer
var focus_player: AudioStreamPlayer
var focus_play_requests := 0
var click_play_requests := 0

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	if DisplayServer.get_name() != "headless":
		initialize_audio()


func initialize_audio() -> void:
	if music_player != null:
		return
	var music_stream := _load_background_stream()
	music_player = _make_player("BackgroundMusic", music_stream)
	music_player.play()
	click_player = _make_player("ButtonClick", load(BUTTON_CLICK_PATH) as AudioStreamOggVorbis)
	focus_player = _make_player("ButtonFocus", load(BUTTON_FOCUS_PATH) as AudioStreamOggVorbis)

func _load_background_stream() -> AudioStreamMP3:
	var stream := load(BACKGROUND_PATH) as AudioStreamMP3
	if stream != null:
		stream.loop = MUSIC_LOOP_ENABLED
	return stream


func shutdown_audio() -> void:
	for player in [music_player, click_player, focus_player]:
		if player != null:
			player.stop()
			player.stream = null
			player.queue_free()
	music_player = null
	click_player = null
	focus_player = null

func _exit_tree() -> void:
	shutdown_audio()

func _make_player(player_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = AUDIO_BUS
	player.stream = stream
	add_child(player)
	return player

func _on_node_added(node: Node) -> void:
	if not node is BaseButton or node.has_meta("audio_hooked"):
		return
	node.set_meta("audio_hooked", true)
	var button := node as BaseButton
	button.mouse_entered.connect(_play_focus)
	button.focus_entered.connect(_play_focus)
	button.pressed.connect(_play_click)

func _play_focus() -> void:
	focus_play_requests += 1
	if focus_player != null:
		focus_player.play()

func _play_click() -> void:
	click_play_requests += 1
	if click_player != null:
		click_player.play()
