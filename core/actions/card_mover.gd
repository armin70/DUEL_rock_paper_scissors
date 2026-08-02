class_name CardMover
extends RefCounted

static func discard_to_draw(player: PlayerState) -> bool:
	if player == null:
		return false

	if player.discard_pile.is_empty():
		return false

	for card: CardInstance in player.discard_pile:
		card.zone = CardZone.Type.DRAW
		card.current_slot = CardInstance.NO_SLOT
		player.draw_pile.append(card)

	player.discard_pile.clear()
	player.draw_pile.shuffle()

	return true


static func draw_to_hand(
	player: PlayerState
) -> CardInstance:
	if player == null:
		return null

	if player.draw_pile.is_empty():
		discard_to_draw(player)

	if player.draw_pile.is_empty():
		return null

	var card: CardInstance = player.draw_pile.pop_back()

	card.zone = CardZone.Type.HAND
	card.current_slot = CardInstance.NO_SLOT

	player.hand.append(card)

	return card

static func hand_to_board(
	player: PlayerState,
	card: CardInstance,
	slot_id: int
) -> bool:
	if player == null or card == null:
		return false

	if not player.hand.has(card):
		return false

	if not player.board.is_slot_empty(slot_id):
		return false

	player.hand.erase(card)

	if not player.board.place_card(slot_id, card):
		player.hand.append(card)
		return false

	return true


static func board_to_discard(
	player: PlayerState,
	slot_id: int
) -> CardInstance:
	if player == null:
		return null

	var card: CardInstance = player.board.remove_card(slot_id)

	if card == null:
		return null

	card.zone = CardZone.Type.DISCARD
	card.current_slot = CardInstance.NO_SLOT

	player.discard_pile.append(card)

	return card
