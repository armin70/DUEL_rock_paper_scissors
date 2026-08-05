class_name Card3D
extends Area3D


signal drag_requested(card_view: Card3D)


var card_instance: CardInstance
var home_transform: Transform3D
var is_draggable: bool = false
@export_category("Visual")
@export var back_texture: Texture2D


@onready var card_art: MeshInstance3D = $CardArt
@onready var disabled_label: Label3D = $DisabledLabel
@onready var shield_badge: Node3D = %ShieldBadge
@onready var shield_count_label: Label3D = %ShieldCount
var displayed_shield_count: int = 0
var shield_badge_base_scale: Vector3 = Vector3.ONE
var card_material: StandardMaterial3D

var is_disabled: bool = false
func _ready() -> void:
	shield_badge_base_scale = shield_badge.scale
	shield_badge.visible = false
	collision_layer = 1
	collision_mask = 0
	input_ray_pickable = true

	_create_card_material()


func _create_card_material() -> void:
	if card_material != null:
		return

	card_material = StandardMaterial3D.new()

	# رنگ تصویر تحت تأثیر نور میز تغییر نمی‌کند.
	card_material.shading_mode = \
		BaseMaterial3D.SHADING_MODE_UNSHADED

	# تصویر از هر دو سمت قابل رندر است.
	card_material.cull_mode = \
		BaseMaterial3D.CULL_DISABLED

	card_art.material_override = card_material


func setup(
	new_card_instance: CardInstance,
	new_home_transform: Transform3D,
	new_is_draggable: bool,
	start_face_up: bool = true
) -> void:
	card_instance = new_card_instance
	home_transform = new_home_transform
	is_draggable = new_is_draggable

	global_transform = home_transform

	_create_card_material()
	set_face_up(start_face_up)


func set_face_up(value: bool) -> void:
	_create_card_material()

	if card_material == null:
		return

	if value:
		if (
			card_instance != null
			and card_instance.definition != null
			and card_instance.definition.front_texture != null
		):
			card_material.albedo_texture = \
				card_instance.definition.front_texture
		else:
			card_material.albedo_texture = null

			push_warning(
				"Card front texture is missing."
			)
	else:
		card_material.albedo_texture = back_texture

func move_home(
	new_home_transform: Transform3D
) -> void:
	home_transform = new_home_transform
	global_transform = home_transform


func return_home() -> void:
	global_transform = home_transform


func _input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_index: int
) -> void:
	if not is_draggable:
		print("card input false")
		return

	if event is InputEventMouseButton:
		if (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		):
			print(
				"CARD INPUT | draggable=",
				is_draggable,
				" | card=",
				card_instance.definition.display_name
			)

			drag_requested.emit(self)

func set_disabled(value: bool) -> void:
	is_disabled = value
	disabled_label.visible = value

	# Disabled بودن فقط نتیجه Combat را تغییر می‌دهد.
	# نباید Drag یا دریافت Input کارت را خاموش کند.
	input_ray_pickable = true


func set_shield_count(
	new_count: int,
	animate_change: bool = true
) -> void:
	new_count = maxi(new_count, 0)

	var previous_count: int = displayed_shield_count
	displayed_shield_count = new_count

	shield_badge.visible = new_count > 0

	if new_count <= 0:
		return

	shield_count_label.text = str(new_count)

	if animate_change and new_count != previous_count:
		_play_shield_badge_pulse()


func _play_shield_badge_pulse() -> void:
	shield_badge.scale = (
		shield_badge_base_scale
		* 1.35
	)

	var tween: Tween = create_tween()

	tween.set_trans(
		Tween.TRANS_BACK
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		shield_badge,
		"scale",
		shield_badge_base_scale,
		0.25
	)
