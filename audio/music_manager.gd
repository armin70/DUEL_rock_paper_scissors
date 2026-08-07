extends Node


@export var background_music: AudioStream

@export_range(-80.0, 10.0, 0.5)
var music_volume_db: float = -10.0


@onready var music_player: AudioStreamPlayer = \
	$MusicPlayer


func _ready() -> void:
	# موزیک حتی هنگام Pause شدن بازی ادامه پیدا می‌کند.
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS

	music_player.volume_db = music_volume_db

	if background_music == null:
		push_error("Background music is not assigned.")
		return

	_enable_music_loop(background_music)

	music_player.stream = background_music

	if not music_player.playing:
		music_player.play()


func _enable_music_loop(
	audio_stream: AudioStream
) -> void:
	if audio_stream is AudioStreamOggVorbis:
		var ogg_stream := \
			audio_stream as AudioStreamOggVorbis

		ogg_stream.loop = true

	elif audio_stream is AudioStreamMP3:
		var mp3_stream := \
			audio_stream as AudioStreamMP3

		mp3_stream.loop = true


func play_music() -> void:
	if music_player.stream == null:
		return

	if not music_player.playing:
		music_player.play()


func stop_music() -> void:
	music_player.stop()


func pause_music() -> void:
	music_player.stream_paused = true


func resume_music() -> void:
	music_player.stream_paused = false


func set_music_volume(
	new_volume_db: float
) -> void:
	music_volume_db = new_volume_db
	music_player.volume_db = new_volume_db
