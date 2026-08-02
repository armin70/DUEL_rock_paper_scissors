class_name GameHUD
extends CanvasLayer


signal end_turn_pressed



@onready var turn_label: Label = $Root/PlayerInfo/TurnLabel
@onready var player_score_label: Label = $Root/PlayerInfo/PlayerScoreLabel
@onready var opponent_score_label: Label = $Root/PlayerInfo/OpponentScoreLabel
@onready var player_mana_label: Label = $Root/PlayerInfo/PlayerManaLabel
@onready var opponent_mana_label: Label = $Root/PlayerInfo/OpponentManaLabel
@onready var end_turn_button: Button = $Root/EndTurnButton



func _ready() -> void:
	end_turn_button.pressed.connect(
		_on_end_turn_button_pressed
	)


func refresh(
	state: MatchState,
	local_player_id: int
) -> void:
	if state == null:
		return

	var player: PlayerState = state.get_player(
		local_player_id
	)

	var opponent_id: int = 2 if local_player_id == 1 else 1

	var opponent: PlayerState = state.get_player(
		opponent_id
	)

	if player == null or opponent == null:
		return

	turn_label.text = "Turn: %d" % state.turn_number

	player_score_label.text = \
		"Your Score: %d" % player.score

	opponent_score_label.text = \
		"Opponent Score: %d" % opponent.score

	player_mana_label.text = \
		"Mana: %d / %d" % [
			player.current_mana,
			player.mana_capacity
		]

	opponent_mana_label.text = \
		"Opponent Mana: %d / %d" % [
			opponent.current_mana,
			opponent.mana_capacity
		]

	end_turn_button.disabled = (
		player.is_ready
		or state.phase != MatchPhase.Type.MAIN
	)

	if player.is_ready:
		end_turn_button.text = "WAITING..."
	else:
		end_turn_button.text = "END TURN"


func set_interaction_enabled(enabled: bool) -> void:
	end_turn_button.disabled = not enabled


func _on_end_turn_button_pressed() -> void:
	end_turn_pressed.emit()


func set_scores(
	player_one_score: int,
	player_two_score: int
) -> void:
	if player_score_label != null:
		player_score_label.text = \
			str(player_one_score)

	if opponent_score_label != null:
		opponent_score_label.text = \
			str(player_two_score)
