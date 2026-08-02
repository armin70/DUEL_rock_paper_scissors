class_name CardBehavior
extends Resource


enum DealerAttackType {
	NORMAL,
	SWEEP_WIN
}


func on_start_combat(
	_context: CardBehaviorContext
) -> void:
	pass


func get_dealer_attack_type(
	_state: MatchState,
	_source_card: CardInstance
) -> int:
	return DealerAttackType.NORMAL


func modify_battle_outcome(
	_state: MatchState,
	_source_card: CardInstance,
	_opponent_card: CardInstance,
	current_outcome: int
) -> int:
	return current_outcome
