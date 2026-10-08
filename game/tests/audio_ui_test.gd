extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL audio_ui ", label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var audio = root.get_node_or_null("AudioManager")
	check(audio != null, "audio manager autoload exists")
	if audio == null:
		quit(1)
		return
	check(ResourceLoader.exists(audio.BACKGROUND_PATH), "background resource path exists")
	check(ResourceLoader.exists(audio.BUTTON_CLICK_PATH), "click resource path exists")
	check(ResourceLoader.exists(audio.BUTTON_FOCUS_PATH), "focus resource path exists")
	var music_stream: AudioStreamMP3 = audio._load_background_stream()
	check(music_stream != null and music_stream.loop, "loaded background stream is configured to loop")
	music_stream = null
	check(audio.AUDIO_BUS == "Master", "all players follow Master volume")

	var button := Button.new()
	root.add_child(button)
	var focus_requests: int = audio.focus_play_requests
	button.mouse_entered.emit()
	check(audio.focus_play_requests == focus_requests + 1, "dynamic button hover requests focus effect")
	button.focus_entered.emit()
	check(audio.focus_play_requests == focus_requests + 2, "dynamic button keyboard focus requests focus effect")
	button.pressed.emit()
	check(audio.click_play_requests == 1, "dynamic button press requests click effect")

	print("AUDIO_UI_PASS checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
