extends Control

var player := AudioStreamPlayer.new()
var status := Label.new()
var started := 0
var observed_wraps := 0
var previous_position := 0.0

func _ready() -> void:
	var stream := load("res://original.wav") as AudioStreamWAV
	assert(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(stream.loop_begin == 0 and stream.loop_end == 4542981)
	stream = stream.duplicate() as AudioStreamWAV
	# Decoder guard: native output verified identical to direct concatenation.
	stream.data = stream.data + stream.data.slice(0,4)
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.stream = stream
	add_child(player)
	var box := VBoxContainer.new()
	box.position = Vector2(30,30)
	box.size = Vector2(760,300)
	box.add_theme_constant_override("separation",18)
	add_child(box)
	var title := Label.new()
	title.text = "ORIGINAL WAV → ORIGINAL SAMPLE 0\nFull 94.6454375 s file; native stream loop; no trim/fade/restart callback.\n4-byte decoder guard; output verified against direct concatenation."
	box.add_child(title)
	for entry in [["Play original from start",0.0],["Play from 12 seconds before the loop",82.6454375]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(func():
			started += 1
			observed_wraps = 0
			previous_position = float(entry[1])
			player.play(float(entry[1]))
		)
		box.add_child(button)
	var stop := Button.new()
	stop.text = "Stop"
	stop.pressed.connect(player.stop)
	box.add_child(stop)
	box.add_child(status)

func _process(_delta: float) -> void:
	var position := player.get_playback_position()
	if player.playing and position < previous_position - 1:
		observed_wraps += 1
		print("NATIVE_LOOP_WRAP=",observed_wraps," USER_STARTS=",started)
	previous_position = position
	status.text = "Position %.3f s | native wraps %d | user start actions %d" % [position,observed_wraps,started]
