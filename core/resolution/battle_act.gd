class_name BattleAct
extends RefCounted


enum Type {
	PLAYER_VS_DEALER,
	PLAYER_VS_PLAYER
}


enum Outcome {
	WIN,
	TIE,
	LOSS
}


var type: Type = Type.PLAYER_VS_DEALER

var attacker: CardInstance
var defender: CardInstance

var attacker_owner_id: int = 0
var defender_owner_id: int = 0

var attacker_slot_id: int = -1
var defender_slot_id: int = -1
var dealer_slot_id: int = -1

var attacker_outcome: Outcome = Outcome.TIE
var defender_outcome: Outcome = Outcome.TIE

var attacker_points: int = 0
var defender_points: int = 0

var resolved: bool = false
