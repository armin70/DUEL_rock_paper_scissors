class_name CollectorBehavior
extends CardBehavior


@export var collected_gesture: CardGesture.Type = \
	CardGesture.Type.ROCK

@export var points_per_discarded_card: int = 1

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

	# Collector فقط یک‌بار فعال می‌شود.
	if source_card.ability_used:
		return

	var owner: PlayerState = context.get_owner()

	if owner == null:
		return

	source_card.ability_used = true

	# اول Slot کارت‌های قابل جمع‌شدن را ذخیره می‌کنیم.
	var target_slots: Array[int] = []

	for slot_id: int in SlotID.all_slots():
		var target_card: CardInstance = \
			owner.board.get_card(slot_id)

		if target_card == null:
			continue

		if target_card.definition == null:
			continue

		# Collector خودش را جمع نمی‌کند.
		if target_card == source_card:
			continue

		# کارت بازی‌شده در همین Turn جمع نمی‌شود.
		if (
			target_card.turn_played
			>= context.state.turn_number
		):
			continue

		if (
			target_card.definition.gesture
			!= collected_gesture
		):
			continue

		target_slots.append(slot_id)

	var discarded_count: int = 0

	# بعد از پایان Search، کارت‌ها را Discard می‌کنیم.
	for target_slot_id: int in target_slots:
		var discarded_card: CardInstance = \
			CardMover.board_to_discard(
				owner,
				target_slot_id
			)

		if discarded_card == null:
			continue

		discarded_count += 1

		print(
			"COLLECTOR DISCARDED | owner=",
			context.owner_id,
			" | card=",
			discarded_card.definition.display_name,
			" | slot=",
			target_slot_id
		)

	var gained_points: int = (
		discarded_count
		* points_per_discarded_card
	)

	owner.score += gained_points

	print(
		"COLLECTOR FINISHED | owner=",
		context.owner_id,
		" | discarded=",
		discarded_count,
		" | gained_points=",
		gained_points
	)
