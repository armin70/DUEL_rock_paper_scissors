class_name MatchEngine
extends RefCounted


var state: MatchState
var card_factory: CardFactory = CardFactory.new()
var active_battle_sequence: BattleSequence

func start_match(
	rules: MatchRules,
	player_one_deck: DeckDefinition,
	player_two_deck: DeckDefinition,
	dealer_deck: DeckDefinition
) -> MatchState:
	state = MatchState.new(rules)

	state.player_one.draw_pile = card_factory.build_deck(
		player_one_deck,
		1
	)

	state.player_two.draw_pile = card_factory.build_deck(
		player_two_deck,
		2
	)
	state.dealer.draw_pile = card_factory.build_deck(
		dealer_deck,
		0
	)

	DealerMover.deal_new_board(state.dealer)

	_run_dealer_enter_behaviors()

	_setup_player(state.player_one)
	_setup_player(state.player_two)

	state.turn_number = 1
	state.phase = MatchPhase.Type.MAIN

	return state

func _run_dealer_enter_behaviors() -> void:
	if state == null:
		return

	if state.dealer == null:
		return

	for dealer_slot_id: int in DealerSlotID.all_slots():
		var dealer_card: CardInstance = \
			state.dealer.slots.get(
				dealer_slot_id,
				null
			) as CardInstance

		if dealer_card == null:
			continue

		if dealer_card.definition == null:
			continue

		var dealer_behavior: DealerCardBehavior = \
			dealer_card.definition.dealer_behavior

		if dealer_behavior == null:
			continue

		dealer_behavior.on_enter_board(
			state,
			dealer_card,
			dealer_slot_id
		)



func _setup_player(player: PlayerState) -> void:
	player.mana_capacity = state.rules.starting_mana
	player.current_mana = player.mana_capacity

	for index: int in range(state.rules.starting_hand_size):
		CardMover.draw_to_hand(player)

func play_card(
	player_id: int,
	card: CardInstance,
	slot_id: int
) -> bool:
	if state == null:
		return false

	if state.phase != MatchPhase.Type.MAIN:
		return false

	var player: PlayerState = state.get_player(player_id)

	if player == null or card == null:
		return false
	if player.is_ready:
		return false
	if card.definition == null:
		return false

	if card.owner_id != player_id:
		return false

	if not player.hand.has(card):
		return false

	if not SlotID.is_valid(slot_id):
		return false

	if not player.board.is_slot_empty(slot_id):
		return false

	var mana_cost: int = card.definition.mana_cost

	if player.current_mana < mana_cost:
		return false

	if not CardMover.hand_to_board(player, card, slot_id):
		return false

	player.current_mana -= mana_cost
	card.turn_played = state.turn_number

	return true


func _start_new_turn_for_player(
	player: PlayerState
) -> void:

	player.mana_capacity = mini(
		player.mana_capacity + state.rules.mana_gain_per_turn,
		state.rules.maximum_mana
	)

	player.current_mana = player.mana_capacity

	for index: int in range(
		state.rules.cards_drawn_per_turn
	):
		CardMover.draw_to_hand(player)

func _run_start_combat_behaviors() -> void:
	if state == null:
		return

	# اول یک Snapshot می‌گیریم تا تغییر Board هنگام اجرای
	# Collector باعث خراب‌شدن Loop نشود.
	var behavior_cards: Array[Dictionary] = []

	for player_id in [1, 2]:
		var player: PlayerState = state.get_player(
			player_id
		)

		if player == null:
			continue

		for slot_id: int in SlotID.all_slots():
			var card: CardInstance = player.board.get_card(
				slot_id
			)

			if card == null:
				continue

			if card.definition == null:
				continue

			if card.definition.behavior == null:
				continue

			behavior_cards.append({
				"player_id": player_id,
				"slot_id": slot_id,
				"card": card
			})

	for entry: Dictionary in behavior_cards:
		var player_id: int = int(
			entry["player_id"]
		)

		var slot_id: int = int(
			entry["slot_id"]
		)

		var card: CardInstance = \
			entry["card"] as CardInstance

		if card == null:
			continue

		if card.definition == null:
			continue

		if card.definition.behavior == null:
			continue

		var context := CardBehaviorContext.new(
			state,
			card,
			player_id,
			slot_id
		)

		card.definition.behavior.on_start_combat(
			context
		)


func set_player_ready(player_id: int) -> bool:
	if state == null:
		return false

	if state.phase != MatchPhase.Type.MAIN:
		return false

	var player: PlayerState = state.get_player(player_id)

	if player == null:
		return false

	if player.is_ready:
		return false

	player.is_ready = true
	return true

func are_both_players_ready() -> bool:
	if state == null:
		return false

	return (
		state.player_one.is_ready
		and state.player_two.is_ready
	)


func begin_combat() -> BattleSequence:
	if state == null:
		return null

	if state.phase != MatchPhase.Type.MAIN:
			return null

	if not are_both_players_ready():
		return null

	state.phase = MatchPhase.Type.BATTLE
	# همه Behaviorهای Start Combat قبل از ساخت صف اجرا می‌شوند.
	_run_start_combat_behaviors()

	active_battle_sequence = \
		BattleResolver.build_sequence(state)

	return active_battle_sequence

func apply_battle_act(
	act: BattleAct
) -> bool:
	if state == null:
		return false

	if act == null:
		return false

	if state.phase != MatchPhase.Type.BATTLE:
		return false

	if act.resolved:
		return false

	var attacker_player: PlayerState = \
		state.get_player(
			act.attacker_owner_id
		)

	if attacker_player != null:
		attacker_player.score += \
			act.attacker_points

	if act.defender_owner_id != 0:
		var defender_player: PlayerState = \
			state.get_player(
				act.defender_owner_id
			)

		if defender_player != null:
			defender_player.score += \
				act.defender_points

	act.resolved = true

	print(
		"BATTLE ACT RESOLVED | type=",
		act.type,
		" | attacker_player=",
		act.attacker_owner_id,
		" | attacker_points=",
		act.attacker_points,
		" | defender_player=",
		act.defender_owner_id,
		" | defender_points=",
		act.defender_points
	)

	return true


func finish_combat() -> bool:
	if state == null:
		return false

	if state.phase != MatchPhase.Type.BATTLE:
		return false

	state.phase = MatchPhase.Type.CLEANUP

	var dealer_ready: bool = \
		DealerMover.deal_new_board(
			state.dealer
		)

	if not dealer_ready:
		push_error(
			"Dealer could not deal a new board."
		)

		state.phase = MatchPhase.Type.GAME_OVER
		return false

	# کارت‌های Dealer وارد زمین شده‌اند.
	# قدرت آن‌ها قبل از شروع چیدن اجرا می‌شود.
	_run_dealer_enter_behaviors()

	state.turn_number += 1

	_start_new_turn_for_player(
		state.player_one
	)

	_start_new_turn_for_player(
		state.player_two
	)

	state.player_one.is_ready = false
	state.player_two.is_ready = false

	active_battle_sequence = null

	state.phase = MatchPhase.Type.MAIN

	return true
