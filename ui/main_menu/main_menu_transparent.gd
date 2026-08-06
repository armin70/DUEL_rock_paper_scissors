class_name TransparentMainMenu
extends CanvasLayer


signal single_player_selected
signal two_player_selected
signal hardcore_selected


enum MenuPhase {
    IDLE,
    START_TRANSITION,
    MODE_SELECTION
}


@export_category("Transparent Video Pairs")
@export var idle_color_video: VideoStream
@export var idle_alpha_video: VideoStream
@export var start_color_video: VideoStream
@export var start_alpha_video: VideoStream

@export_category("Menu")
@export var pause_game_while_menu: bool = true
@export var disable_two_player_for_now: bool = true
@export_range(0.01, 0.25, 0.01)
var maximum_sync_drift: float = 0.06


@onready var menu_root: Control = $MenuRoot
@onready var color_player: VideoStreamPlayer = \
    $MenuRoot/ColorPlayer
@onready var alpha_player: VideoStreamPlayer = \
    $MenuRoot/AlphaPlayer
@onready var composite: ColorRect = \
    $MenuRoot/Composite
@onready var start_button: Button = \
    $MenuRoot/StartButton
@onready var mode_buttons: Control = \
    $MenuRoot/ModeButtons
@onready var single_player_button: Button = \
    $MenuRoot/ModeButtons/SinglePlayerButton
@onready var two_player_button: Button = \
    $MenuRoot/ModeButtons/TwoPlayerButton
@onready var hardcore_button: Button = \
    $MenuRoot/ModeButtons/HardcoreButton


var phase: MenuPhase = MenuPhase.IDLE
var transition_is_running: bool = false
var composite_material: ShaderMaterial


func _ready() -> void:
    # The menu and its videos continue while the game tree is paused.
    process_mode = Node.PROCESS_MODE_ALWAYS

    if pause_game_while_menu:
        get_tree().paused = true

    composite_material = composite.material as ShaderMaterial

    if composite_material == null:
        push_error(
            "Composite needs the transparent-video ShaderMaterial."
        )
        return

    start_button.show()
    mode_buttons.hide()

    two_player_button.disabled = disable_two_player_for_now

    start_button.pressed.connect(
        _on_start_button_pressed
    )
    single_player_button.pressed.connect(
        _on_single_player_button_pressed
    )
    two_player_button.pressed.connect(
        _on_two_player_button_pressed
    )
    hardcore_button.pressed.connect(
        _on_hardcore_button_pressed
    )
    color_player.finished.connect(
        _on_color_video_finished
    )

    await _play_video_pair(
        idle_color_video,
        idle_alpha_video,
        MenuPhase.IDLE
    )


func _exit_tree() -> void:
    # Prevent the game from remaining paused if this menu is removed.
    if pause_game_while_menu and get_tree() != null:
        get_tree().paused = false


func _process(_delta: float) -> void:
    if not color_player.is_playing():
        return

    if not alpha_player.is_playing():
        return

    var drift: float = absf(
        color_player.stream_position
        - alpha_player.stream_position
    )

    if drift > maximum_sync_drift:
        alpha_player.stream_position = \
            color_player.stream_position


func _play_video_pair(
    color_stream: VideoStream,
    alpha_stream: VideoStream,
    new_phase: MenuPhase
) -> void:
    if color_stream == null or alpha_stream == null:
        push_error("A color/alpha video pair is missing.")
        return

    phase = new_phase

    color_player.stop()
    alpha_player.stop()

    color_player.stream = color_stream
    alpha_player.stream = alpha_stream

    color_player.play()
    alpha_player.play()

    # VideoTexture becomes available after playback starts.
    await get_tree().process_frame

    composite_material.set_shader_parameter(
        "color_video",
        color_player.get_video_texture()
    )
    composite_material.set_shader_parameter(
        "alpha_video",
        alpha_player.get_video_texture()
    )


func _restart_idle_video() -> void:
    await _play_video_pair(
        idle_color_video,
        idle_alpha_video,
        MenuPhase.IDLE
    )


func _on_color_video_finished() -> void:
    match phase:
        MenuPhase.IDLE:
            # Manual looping keeps both files starting together.
            call_deferred("_restart_idle_video")

        MenuPhase.START_TRANSITION:
            transition_is_running = false
            phase = MenuPhase.MODE_SELECTION

            # Do not call stop(). The final menu frame stays visible.
            mode_buttons.show()

        MenuPhase.MODE_SELECTION:
            pass


func _on_start_button_pressed() -> void:
    if transition_is_running:
        return

    transition_is_running = true
    start_button.hide()
    mode_buttons.hide()

    await _play_video_pair(
        start_color_video,
        start_alpha_video,
        MenuPhase.START_TRANSITION
    )


func _on_single_player_button_pressed() -> void:
    if transition_is_running:
        return

    # Normal single-player is always the fair/default bot.
    ProjectSettings.set_setting(
        "gameplay/hardcore_bot",
        false
    )

    single_player_selected.emit()
    _close_menu_and_start_game()


func _on_hardcore_button_pressed() -> void:
    if transition_is_running:
        return

    # Secret single-player mode: the bot can inspect current-turn cards.
    ProjectSettings.set_setting(
        "gameplay/hardcore_bot",
        true
    )

    hardcore_selected.emit()
    single_player_selected.emit()
    _close_menu_and_start_game()


func _close_menu_and_start_game() -> void:
    if pause_game_while_menu:
        get_tree().paused = false

    queue_free()


func _on_two_player_button_pressed() -> void:
    if transition_is_running:
        return

    if disable_two_player_for_now:
        return

    two_player_selected.emit()
