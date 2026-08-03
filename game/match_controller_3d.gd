class_name MatchController3D
extends Node3D


const SLOT_COLLISION_MASK: int = 2


@export_category("Match Resources")
@export var rules: MatchRules
@export var player_one_deck: DeckDefinition
@export var player_two_deck: DeckDefinition
@export var dealer_deck: DeckDefinition


@export_category("Scene References")
@export var game_layout: GameLayout3D
@export var card_scene: PackedScene
@export var runtime_cards: Node3D
@export var camera_3d: Camera3D
@export var hud: GameHUD


@export_category("Drag")
@export_range(1, 2, 1)
var local_player_id: int = 1

@export var drag_plane_height: float = 0.8


@export_category("Bot and Reveal")
@export var bot_think_time: float = 0.3
@export var reveal_step_time: float = 0.3
@export var reveal_drop_height: float = 1.2


var engine: MatchEngine
var state: MatchState

var bot_controller: BotController = BotController.new()
var bot_player_id: int = 2

var interaction_locked: bool = false

var card_views: Dictionary = {}
var opponent_hand_views: Dictionary = {}
var dragged_card: Card3D

var pending_local_cards: Array[CardInstance] = []
var pending_bot_cards: Array[CardInstance] = []


func _ready() -> void:
	
	if not _resources_are_valid():
		return

	bot_player_id = 2 if local_player_id == 1 else 1

	engine = MatchEngine.new()

	state = engine.start_match(
		rules,
		player_one_deck,
		player_two_deck,
		dealer_deck
	)

	hud.end_turn_pressed.connect(
		Callable(self, "_on_end_turn_pressed")
	)

	await _sync_visual_state()

	hud.refresh(
		state,
		local_player_id
	)

	# ربات هم‌زمان با بازیکن، مخفیانه برنامه‌ریزی می‌کند.
	_prepare_bot_turn()

	print("Simultaneous match started.")


func _prepare_bot_turn() -> void:
	if state == null:
		return

	if state.phase != MatchPhase.Type.MAIN:
		return

	var bot: PlayerState = state.get_player(
		bot_player_id
	)

	if bot == null:
		return

	if bot.is_ready:
		return

	pending_bot_cards.clear()

	var previous_card_ids: Dictionary = \
		_get_board_card_ids(bot_player_id)

	# کارت‌های ربات فقط داخل Engine قرار می‌گیرند.
	# در اینجا ظاهر سه‌بعدی Refresh نمی‌شود.
	bot_controller.play_turn(
		engine,
		bot_player_id
	)

	pending_bot_cards = _get_cards_not_in_snapshot(
		bot_player_id,
		previous_card_ids
	)

	engine.set_player_ready(bot_player_id)

	print(
		"Bot completed hidden planning with ",
		pending_bot_cards.size(),
		" new cards."
	)


func _get_board_card_ids(
	player_id: int
) -> Dictionary:
	var result: Dictionary = {}

	var player: PlayerState = state.get_player(
		player_id
	)

	if player == null:
		return result

	for slot_id: int in SlotID.all_slots():
		var card: CardInstance = player.board.get_card(
			slot_id
		)

		if card != null:
			result[card.instance_id] = true

	return result


func _get_cards_not_in_snapshot(
	player_id: int,
	previous_card_ids: Dictionary
) -> Array[CardInstance]:
	var result: Array[CardInstance] = []

	var player: PlayerState = state.get_player(
		player_id
	)

	if player == null:
		return result

	for slot_id: int in SlotID.all_slots():
		var card: CardInstance = player.board.get_card(
			slot_id
		)

		if card == null:
			continue

		if not previous_card_ids.has(card.instance_id):
			result.append(card)

	return result


func _on_end_turn_pressed() -> void:
	if interaction_locked:
		return

	if state == null:
		return

	var player: PlayerState = state.get_player(
		local_player_id
	)

	if player == null:
		return

	if player.is_ready:
		return

	var success: bool = engine.set_player_ready(
		local_player_id
	)

	if not success:
		return

	interaction_locked = true

	hud.set_interaction_enabled(false)

	hud.refresh(
		state,
		local_player_id
	)

	if _are_both_players_ready():
		await _run_reveal_and_battle()


func _are_both_players_ready() -> bool:
	if state == null:
		return false

	var player_one: PlayerState = state.get_player(1)
	var player_two: PlayerState = state.get_player(2)

	if player_one == null or player_two == null:
		return false

	return (
		player_one.is_ready
		and player_two.is_ready
	)


func _run_reveal_and_battle() -> void:
	await get_tree().create_timer(
		bot_think_time
	).timeout
	# کارت‌های Coverشده Bot درست هنگام Reveal ناپدید می‌شوند.
	_remove_discarded_card_views()
	await _reveal_cards_one_by_one(
		pending_local_cards,
		pending_bot_cards
	)

	pending_local_cards.clear()
	pending_bot_cards.clear()

	await _start_animated_combat()


func _reveal_cards_one_by_one(
	player_cards: Array[CardInstance],
	bot_cards: Array[CardInstance]
) -> void:
	var maximum_count: int = max(
		player_cards.size(),
		bot_cards.size()
	)

	for index: int in range(maximum_count):
		if index < player_cards.size():
			await _pulse_existing_card(
				player_cards[index]
			)

		if index < bot_cards.size():
			await _reveal_bot_card(
				bot_cards[index]
			)

	await _refresh_opponent_hand_positions()

func _pulse_existing_card(
	card: CardInstance
) -> void:
	var card_view := card_views.get(
		card.instance_id,
		null
	) as Card3D

	if card_view == null:
		return

	var original_position: Vector3 = \
		card_view.global_position

	var lifted_position: Vector3 = (
		original_position
		+ Vector3.UP * 0.35
	)

	var tween: Tween = create_tween()

	tween.tween_property(
		card_view,
		"global_position",
		lifted_position,
		reveal_step_time * 0.5
	)

	tween.tween_property(
		card_view,
		"global_position",
		original_position,
		reveal_step_time * 0.5
	)

	await tween.finished


func _reveal_bot_card(
	card: CardInstance
) -> void:
	var slot_id: int = _find_card_slot(
		bot_player_id,
		card
	)

	if slot_id == -1:
		push_error(
			"Could not find bot card slot."
		)
		return

	var place: CardPlace3D = \
		game_layout.get_board_place(
			bot_player_id,
			slot_id
		)

	if place == null:
		push_error(
			"Missing opponent board place."
		)
		return

	var target_transform: Transform3D = \
		place.card_anchor.global_transform

	var card_view := opponent_hand_views.get(
		card.instance_id,
		null
	) as Card3D

	# حالت اضطراری، در صورتی که View دست پیدا نشد.
	if card_view == null:
		var start_transform: Transform3D = \
			target_transform

		start_transform.origin += \
			Vector3.UP * reveal_drop_height

		card_view = _create_card_view(
			card,
			start_transform,
			false,
			false,
			false
		)

	if card_view == null:
		return

	opponent_hand_views.erase(
		card.instance_id
	)

	var start_position: Vector3 = \
		card_view.global_position

	var target_position: Vector3 = \
		target_transform.origin

	var middle_position: Vector3 = (
		(start_position + target_position) / 2.0
		+ Vector3.UP * reveal_drop_height
	)

	var tween: Tween = create_tween()

	tween.tween_property(
		card_view,
		"global_position",
		middle_position,
		reveal_step_time * 0.45
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_callback(
		Callable(
			card_view,
			"set_face_up"
		).bind(true)
	)

	tween.tween_property(
		card_view,
		"global_transform",
		target_transform,
		reveal_step_time * 0.55
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)

	await tween.finished

	card_view.move_home(
		target_transform
	)

	card_views[
		card.instance_id
	] = card_view
func _find_card_slot(
	player_id: int,
	target_card: CardInstance
) -> int:
	var player: PlayerState = state.get_player(
		player_id
	)

	if player == null:
		return -1

	for slot_id: int in SlotID.all_slots():
		var card: CardInstance = player.board.get_card(
			slot_id
		)

		if card == target_card:
			return slot_id

	return -1


func _sync_visual_state() -> void:
	dragged_card = null

	for child: Node in runtime_cards.get_children():
		child.queue_free()

	card_views.clear()
	opponent_hand_views.clear()

	await get_tree().process_frame

	_spawn_dealer_cards()

	_spawn_board_cards(1)
	_spawn_board_cards(2)

	_spawn_hand_cards()
	_spawn_opponent_hand_cards()
	_refresh_board_disabled_visuals()
	_refresh_pile_entities()
func _spawn_dealer_cards() -> void:
	for slot_id: int in DealerSlotID.all_slots():
		var card: CardInstance = state.dealer.slots.get(
			slot_id,
			null
		)

		if card == null:
			continue

		var anchor: Marker3D = \
			game_layout.get_dealer_anchor(
				slot_id
			)

		if anchor == null:
			push_error(
				"Missing dealer anchor: %s"
				% slot_id
			)
			continue

		_create_card_view(
			card,
			anchor.global_transform,
			false
		)


func _spawn_board_cards(
	player_id: int
) -> void:
	var player: PlayerState = state.get_player(
		player_id
	)

	if player == null:
		return

	for slot_id: int in SlotID.all_slots():
		var card: CardInstance = \
			player.board.get_card(
				slot_id
			)

		if card == null:
			continue

		var place: CardPlace3D = \
			game_layout.get_board_place(
				player_id,
				slot_id
			)

		if place == null:
			push_error(
				"Missing place for player %d, slot %d"
				% [player_id, slot_id]
			)
			continue

		# فقط کارت‌های Board بازیکن محلی Drag می‌شوند.
		var draggable: bool = (
			player_id == local_player_id
		)

		var card_view: Card3D = \
			_create_card_view(
				card,
				place.card_anchor.global_transform,
				draggable
			)

		if card_view == null:
			continue

		if draggable:
			card_view.drag_requested.connect(
				Callable(
					self,
					"_start_card_drag"
				)
			)
func _spawn_hand_cards() -> void:
	var player: PlayerState = state.get_player(
		local_player_id
	)

	if player == null:
		return

	for index: int in range(player.hand.size()):
		var card: CardInstance = player.hand[index]

		var target_transform: Transform3D = \
			game_layout.get_hand_transform(
				local_player_id,
				index,
				player.hand.size()
			)

		var card_view: Card3D = _create_card_view(
			card,
			target_transform,
			true
		)

		card_view.drag_requested.connect(
			Callable(self, "_start_card_drag")
		)

func _create_card_view(
	card: CardInstance,
	target_transform: Transform3D,
	draggable: bool,
	face_up: bool = true,
	register_as_main_view: bool = true
) -> Card3D:
	var card_view := \
		card_scene.instantiate() as Card3D

	if card_view == null:
		push_error(
			"Card scene root must be Card3D."
		)
		return null

	runtime_cards.add_child(card_view)

	card_view.setup(
		card,
		target_transform,
		draggable,
		face_up
	)

	if register_as_main_view:
		card_views[card.instance_id] = card_view

	return card_view

func _start_card_drag(
	card_view: Card3D
) -> void:
	if interaction_locked:
		return

	if state == null:
		return

	if state.phase != MatchPhase.Type.MAIN:
		return

	var player: PlayerState = state.get_player(
		local_player_id
	)

	if player == null or player.is_ready:
		return

	if card_view == null:
		return

	if card_view.card_instance == null:
		return

	if (
		card_view.card_instance.owner_id
		!= local_player_id
	):
		return

	var card_zone: CardZone.Type = \
		card_view.card_instance.zone

	if (
		card_zone != CardZone.Type.HAND
		and card_zone != CardZone.Type.BOARD
	):
		return

	dragged_card = card_view


func _input(event: InputEvent) -> void:
	if dragged_card == null:
		return

	if event is InputEventMouseMotion:
		_move_dragged_card(
			event.position
		)

	elif event is InputEventMouseButton:
		if (
			event.button_index
			== MOUSE_BUTTON_LEFT
			and not event.pressed
		):
			_finish_card_drag(
				event.position
			)


func _move_dragged_card(
	screen_position: Vector2
) -> void:
	var ray_origin: Vector3 = \
		camera_3d.project_ray_origin(
			screen_position
		)

	var ray_direction: Vector3 = \
		camera_3d.project_ray_normal(
			screen_position
		)

	var drag_plane := Plane(
		Vector3.UP,
		drag_plane_height
	)

	var intersection: Variant = \
		drag_plane.intersects_ray(
			ray_origin,
			ray_direction
		)

	if intersection == null:
		return

	dragged_card.global_position = intersection

func _finish_card_drag(
	screen_position: Vector2
) -> void:
	var card_view: Card3D = dragged_card
	dragged_card = null

	if card_view == null:
		return

	var place: CardPlace3D = \
		_get_place_under_mouse(
			screen_position
		)

	if place == null:
		card_view.return_home()
		return

	if (
		place.kind
		!= CardPlace3D.Kind.PLAYER_BOARD
	):
		card_view.return_home()
		return

	if place.owner_id != local_player_id:
		card_view.return_home()
		return

	var card: CardInstance = \
		card_view.card_instance

	if card == null:
		card_view.return_home()
		return

	var original_zone: CardZone.Type = \
		card.zone

	# -----------------------------------------
	# کارت از Hand وارد Board می‌شود.
	# -----------------------------------------
	if original_zone == CardZone.Type.HAND:
		var was_played: bool = \
			engine.play_card(
				local_player_id,
				card,
				place.logical_id
			)
		if not was_played:
			card_view.return_home()
			return

		_remove_pile_card_views()
		_spawn_missing_local_hand_cards()

		_refresh_pile_entities()
		_refresh_board_disabled_visuals()

		pending_local_cards.append(
			card
		)

		card_view.is_draggable = true

		card_view.move_home(
			place.card_anchor.global_transform
		)

		hud.refresh(
			state,
			local_player_id
		)

		await _refresh_hand_positions()
		if not was_played:
			card_view.return_home()
			return

		# برای سیستم Cover که قبلاً اضافه کردیم.
		_remove_discarded_card_views()
		_refresh_pile_entities()

		pending_local_cards.append(card)

		# کارت حالا روی Board است و می‌تواند Drag شود.
		card_view.is_draggable = true

		card_view.move_home(
			place.card_anchor.global_transform
		)

		hud.refresh(
			state,
			local_player_id
		)

		await _refresh_hand_positions()
		return

	# -----------------------------------------
	# کارت موجود روی Board جابه‌جا می‌شود.
	# -----------------------------------------
	if original_zone == CardZone.Type.BOARD:
		var from_slot_id: int = \
			card.current_slot

		var was_moved: bool = \
			engine.move_board_card(
				local_player_id,
				from_slot_id,
				place.logical_id
			)

		if not was_moved:
			card_view.return_home()
			return

		card_view.move_home(
			place.card_anchor.global_transform
		)

		hud.refresh(
			state,
			local_player_id
		)

		return

	card_view.return_home()
func _get_place_under_mouse(
	screen_position: Vector2
) -> CardPlace3D:
	var ray_origin: Vector3 = \
		camera_3d.project_ray_origin(
			screen_position
		)

	var ray_direction: Vector3 = \
		camera_3d.project_ray_normal(
			screen_position
		)

	var query := \
		PhysicsRayQueryParameters3D.create(
			ray_origin,
			ray_origin + ray_direction * 1000.0
		)

	query.collision_mask = SLOT_COLLISION_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result: Dictionary = \
		get_world_3d().direct_space_state.intersect_ray(
			query
		)

	if result.is_empty():
		return null

	return result.get(
		"collider",
		null
	) as CardPlace3D


func _refresh_hand_positions() -> void:
	var player: PlayerState = state.get_player(
		local_player_id
	)

	if player == null:
		return

	for index: int in range(player.hand.size()):
		var card: CardInstance = player.hand[index]

		var card_view := card_views.get(
			card.instance_id,
			null
		) as Card3D

		if card_view == null:
			continue

		var target_transform: Transform3D = \
			game_layout.get_hand_transform(
				local_player_id,
				index,
				player.hand.size()
			)

		card_view.move_home(
			target_transform
		)


func _resources_are_valid() -> bool:
	if rules == null:
		push_error("Rules are missing.")
		return false

	if player_one_deck == null:
		push_error("Player one deck is missing.")
		return false

	if player_two_deck == null:
		push_error("Player two deck is missing.")
		return false

	if dealer_deck == null:
		push_error("Dealer deck is missing.")
		return false

	if game_layout == null:
		push_error("GameLayout is missing.")
		return false

	if card_scene == null:
		push_error("Card scene is missing.")
		return false

	if runtime_cards == null:
		push_error("RuntimeCards is missing.")
		return false

	if camera_3d == null:
		push_error("Camera3D is missing.")
		return false

	if hud == null:
		push_error("HUD is missing.")
		return false

	return true


func _spawn_opponent_hand_cards() -> void:
	var opponent: PlayerState = state.get_player(
		bot_player_id
	)

	if opponent == null:
		return

	for index: int in range(
		opponent.hand.size()
	):
		var card: CardInstance = \
			opponent.hand[index]

		var target_transform: Transform3D = \
			game_layout.get_hand_transform(
				bot_player_id,
				index,
				opponent.hand.size()
			)

		var card_view: Card3D = \
			_create_card_view(
				card,
				target_transform,
				false,
				false,
				false
			)

		if card_view == null:
			continue

		opponent_hand_views[
			card.instance_id
		] = card_view


func _refresh_opponent_hand_positions() -> void:
	var opponent: PlayerState = state.get_player(
		bot_player_id
	)

	if opponent == null:
		return

	for index: int in range(
		opponent.hand.size()
	):
		var card: CardInstance = \
			opponent.hand[index]

		var card_view := \
			opponent_hand_views.get(
				card.instance_id,
				null
			) as Card3D

		if card_view == null:
			continue

		var target_transform: Transform3D = \
			game_layout.get_hand_transform(
				bot_player_id,
				index,
				opponent.hand.size()
			)

		card_view.move_home(
			target_transform
		)

func _refresh_board_disabled_visuals() -> void:
	if engine == null:
		return

	if engine.state == null:
		return

	for player_id: int in [1, 2]:
		var player: PlayerState = \
			engine.state.get_player(
				player_id
			)

		if player == null:
			continue

		for slot_id: int in SlotID.all_slots():
			var card: CardInstance = \
				player.board.get_card(
					slot_id
				)

			if card == null:
				continue

			var card_view := card_views.get(
				card.instance_id,
				null
			) as Card3D

			if card_view == null:
				continue

			var disabled: bool = \
				DisableGestureBehavior.is_card_disabled(
					engine.state,
					player_id,
					slot_id,
					card
				)

			card_view.set_disabled(disabled)
func _start_animated_combat() -> void:
	interaction_locked = true

	var sequence: BattleSequence = engine.begin_combat()

	if sequence == null:
		push_error("Could not begin battle sequence.")
		interaction_locked = false
		hud.set_interaction_enabled(true)
		return

	# مهم: صبر می‌کنیم Viewهای جدید کامل ساخته شوند.
	await _sync_visual_state()

	_refresh_board_disabled_visuals()
	_refresh_battle_scores()

	print(
		"ANIMATED COMBAT STARTED | acts=",
		sequence.acts.size()
	)

	while sequence.has_next():
		var act: BattleAct = sequence.get_next()

		if act == null:
			continue

		print(
			"ANIMATING ACT | type=",
			act.type,
			" | attacker=",
			act.attacker.definition.display_name
		)

		await _animate_battle_act(act)

		engine.apply_battle_act(act)

		_refresh_battle_scores()

		await get_tree().create_timer(
			0.25
		).timeout

	engine.finish_combat()

	# اینجا هم باید await داشته باشد.
	await _sync_visual_state()

	_refresh_battle_scores()
	_refresh_board_disabled_visuals()

	interaction_locked = false
	hud.set_interaction_enabled(true)

	_prepare_bot_turn()
func _animate_battle_act(
	act: BattleAct
) -> void:
	if act == null:
		return

	match act.type:
		BattleAct.Type.PLAYER_VS_DEALER:
			await _animate_player_vs_dealer(
				act
			)

		BattleAct.Type.PLAYER_VS_PLAYER:
			await _animate_player_clash(
				act
			)
		

func _animate_player_vs_dealer(
	act: BattleAct
) -> void:
	if act == null:
		return

	if act.attacker == null:
		return

	if act.defender == null:
		return

	var attacker_view := card_views.get(
		act.attacker.instance_id,
		null
	) as Card3D

	var dealer_view := card_views.get(
		act.defender.instance_id,
		null
	) as Card3D

	if attacker_view == null:
		push_error(
			"Missing attacker view: %s | id=%s"
			% [
				act.attacker.definition.display_name,
				act.attacker.instance_id
			]
		)
		return

	if dealer_view == null:
		push_error(
			"Missing dealer view: %s | id=%s"
			% [
				act.defender.definition.display_name,
				act.defender.instance_id
			]
		)
		return

	var attacker_start: Vector3 = \
		attacker_view.global_position

	var dealer_position: Vector3 = \
		dealer_view.global_position

	var hit_position: Vector3 = dealer_position.lerp(
		attacker_start,
		0.15
	)

	hit_position.y += 0.45

	var attack_tween: Tween = create_tween()

	attack_tween.tween_property(
		attacker_view,
		"global_position",
		hit_position,
		0.28
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)

	await attack_tween.finished

	await get_tree().create_timer(
		0.10
	).timeout

	var return_tween: Tween = create_tween()

	return_tween.tween_property(
		attacker_view,
		"global_position",
		attacker_start,
		0.28
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	await return_tween.finished

func _animate_player_clash(
	act: BattleAct
) -> void:
	if act == null:
		return

	if act.attacker == null:
		return

	if act.defender == null:
		return

	var first_view := card_views.get(
		act.attacker.instance_id,
		null
	) as Card3D

	var second_view := card_views.get(
		act.defender.instance_id,
		null
	) as Card3D

	if first_view == null:
		push_error(
			"Missing first clash view: %s"
			% act.attacker.definition.display_name
		)
		return

	if second_view == null:
		push_error(
			"Missing second clash view: %s"
			% act.defender.definition.display_name
		)
		return

	var first_start: Vector3 = \
		first_view.global_position

	var second_start: Vector3 = \
		second_view.global_position

	var clash_center: Vector3 = (
		first_start + second_start
	) * 0.5

	clash_center.y += 1.25

	var direction: Vector3 = \
		second_start - first_start

	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()

	var first_target: Vector3 = \
		clash_center - direction * 0.22

	var second_target: Vector3 = \
		clash_center + direction * 0.22

	var clash_tween: Tween = create_tween()
	clash_tween.set_parallel(true)

	clash_tween.tween_property(
		first_view,
		"global_position",
		first_target,
		0.32
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)

	clash_tween.tween_property(
		second_view,
		"global_position",
		second_target,
		0.32
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)

	await clash_tween.finished

	await get_tree().create_timer(
		0.15
	).timeout

	var return_tween: Tween = create_tween()
	return_tween.set_parallel(true)

	return_tween.tween_property(
		first_view,
		"global_position",
		first_start,
		0.32
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	return_tween.tween_property(
		second_view,
		"global_position",
		second_start,
		0.32
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	await return_tween.finished

func _refresh_battle_scores() -> void:
	if engine == null:
		return

	if engine.state == null:
		return

	if hud == null:
		return

	hud.set_scores(
		engine.state.player_one.score,
		engine.state.player_two.score
	)


func _remove_discarded_card_views() -> void:
	for instance_id: Variant in card_views.keys():
		var card_view := card_views.get(
			instance_id,
			null
		) as Card3D

		if card_view == null:
			continue

		if card_view.card_instance == null:
			continue

		if (
			card_view.card_instance.zone
			!= CardZone.Type.DISCARD
		):
			continue

		card_views.erase(instance_id)
		card_view.queue_free()


func _refresh_pile_entities() -> void:
	if state == null:
		return

	if not is_instance_valid(game_layout):
		return

	for player_id: int in [1, 2]:
		var player: PlayerState = \
			state.get_player(player_id)

		if player == null:
			continue

		for pile_type: int in \
			CardPile3D.Type.values():

			var pile_entity: CardPile3D = \
				game_layout.get_pile_entity(
					player_id,
					pile_type
				)

			if pile_entity == null:
				continue

			pile_entity.refresh_from_player(
				player
			)


func _remove_pile_card_views() -> void:
	for instance_id: Variant in card_views.keys():
		var card_view := card_views.get(
			instance_id,
			null
		) as Card3D

		if card_view == null:
			continue

		var card: CardInstance = \
			card_view.card_instance

		if card == null:
			continue

		var is_in_hidden_pile: bool = (
			card.zone == CardZone.Type.DRAW
			or card.zone == CardZone.Type.DISCARD
			or card.zone == CardZone.Type.RESERVE
		)

		if not is_in_hidden_pile:
			continue

		card_views.erase(instance_id)
		card_view.queue_free()
		
func _spawn_missing_local_hand_cards() -> void:
	var player: PlayerState = state.get_player(
		local_player_id
	)

	if player == null:
		return

	for index: int in range(player.hand.size()):
		var card: CardInstance = \
			player.hand[index]

		if card == null:
			continue

		if card_views.has(card.instance_id):
			continue

		var target_transform: Transform3D = \
			game_layout.get_hand_transform(
				local_player_id,
				index,
				player.hand.size()
			)

		var card_view: Card3D = \
			_create_card_view(
				card,
				target_transform,
				true
			)

		if card_view == null:
			continue

		card_view.drag_requested.connect(
			Callable(
				self,
				"_start_card_drag"
			)
		)
