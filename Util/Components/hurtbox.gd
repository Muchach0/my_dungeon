class_name Hurtbox
extends Area2D

@export var damage: int = 1 # default damage value
@export var should_disapear_on_hit: bool = false # default value - should be true for projectiles, but false for melee attacks
var from_player_id: int = 1 # default value - should be the player id who shot the bullet


@onready var collision_shape: CollisionShape2D = $CollisionShape2D

signal attack_landed_signal

func attack_landed():
    attack_landed_signal.emit()