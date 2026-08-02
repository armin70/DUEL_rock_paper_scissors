class_name BotController
extends RefCounted


var random := RandomNumberGenerator.new()


func _init() -> void:
	random.randomize()


func play_turn(
	engine: MatchEngine,
	bot_player_id: int
) -> void:
	if engine == null or engine.state == null:
		return

	var state: MatchState = engine.state

	if state.phase != MatchPhase.Type.MAIN:
		return

	var bot: PlayerState = state.get_player(bot_player_id)

	if bot == null or bot.is_ready:
		return

	while true:
		var playable_cards: Array[CardInstance] = \
			_get_playable_cards(bot)

		var empty_slots: Array[int] = \
			_get_empty_slots(bot)

		if playable_cards.is_empty():
			break

		if empty_slots.is_empty():
			break

		var card: CardInstance = playable_cards[
			random.randi_range(
				0,
				playable_cards.size() - 1
			)
		]

		var slot_id: int = empty_slots[
			random.randi_range(
				0,
				empty_slots.size() - 1
			)
		]

		var success: bool = engine.play_card(
			bot_player_id,
			card,
			slot_id
		)

		if not success:
			break


func _get_playable_cards(
	player: PlayerState
) -> Array[CardInstance]:
	var result: Array[CardInstance] = []

	for card: CardInstance in player.hand:
		if card.definition == null:
			continue

		if card.definition.mana_cost <= player.current_mana:
			result.append(card)

	return result


func _get_empty_slots(
	player: PlayerState
) -> Array[int]:
	var result: Array[int] = []

	for slot_id: int in SlotID.all_slots():
		if player.board.is_slot_empty(slot_id):
			result.append(slot_id)

	return result
