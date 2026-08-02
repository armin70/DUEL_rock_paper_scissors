class_name DisableGestureBehavior
extends CardBehavior


@export var disabled_gesture: CardGesture.Type = \
	CardGesture.Type.ROCK


func on_start_combat(
	context: CardBehaviorContext
) -> void:
	if context == null:
		return

	if context.state == null:
		return

	var source_card: CardInstance = context.source_card

	if source_card == null:
		return

	if source_card.ability_used:
		print(
			"DISABLER SKIPPED | already used | card=",
			source_card.definition.display_name
		)
		return

	var opponent_id: int = 2 if context.owner_id == 1 else 1

	var opponent: PlayerState = context.state.get_player(
		opponent_id
	)
	if opponent == null:
		return

	var disabled_count: int = 0

	for slot_id: int in SlotID.all_slots():
		var target_card: CardInstance = \
			opponent.board.get_card(slot_id)

		if target_card == null:
			continue

		if target_card.definition == null:
			continue

		if (
			target_card.definition.gesture
			!= disabled_gesture
		):
			continue

		target_card.disabled_combat_turn = \
			context.state.turn_number

		disabled_count += 1

		print(
			"TARGET DISABLED | source_owner=",
			context.owner_id,
			" | target_owner=",
			opponent.player_id,
			" | target=",
			target_card.definition.display_name,
			" | slot=",
			slot_id,
			" | turn=",
			target_card.disabled_combat_turn
		)

	# حتی اگر هدفی پیدا نشد، قابلیت مصرف می‌شود.
	source_card.ability_used = true

	print(
		"DISABLER FINISHED | source=",
		source_card.definition.display_name,
		" | gesture=",
		int(disabled_gesture),
		" | disabled_count=",
		disabled_count
	)
