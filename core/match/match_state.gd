class_name MatchState
extends RefCounted


var rules: MatchRules

var player_one: PlayerState
var player_two: PlayerState
var dealer: DealerState

var turn_number: int = 0
var phase: MatchPhase.Type = MatchPhase.Type.SETUP


func _init(
	new_rules: MatchRules
) -> void:
	rules = new_rules

	player_one = PlayerState.new(1)
	player_two = PlayerState.new(2)
	dealer = DealerState.new()


func get_player(player_id: int) -> PlayerState:
	if player_one.player_id == player_id:
		return player_one

	if player_two.player_id == player_id:
		return player_two

	return null
