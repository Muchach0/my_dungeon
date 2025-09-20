extends State
class_name EnemyIdle

var enemy : Enemy

var state_animation_name: String = "idle"

const AGGRO_AREA_NAME = "AggroArea2D"

func _on_Area2D_body_entered(body):
    if not body.is_in_group("Player"):
        return
    # print_debug("EnemyIdle.gd - _on_Area2D_area_entered - Player entered the area")
    enemy.player = body
    if enemy.player.is_hidden:
        return
    print_debug("EnemyIdle.gd - _on_Area2D_area_entered - Player entered the area - Player: ", enemy.player)

    if enemy.get_node("StateMachine").states.has("EnemyRangedAttack".to_lower()):
        print_debug("EnemyIdle.gd - _on_Area2D_body_entered - Player entered the area - Transitioning to EnemyRangedAttack")
        emit_signal("transitioned", self, "EnemyRangedAttack")
        return
    
    if enemy.get_node("StateMachine").states.has("EnemyFollowing".to_lower()):
        print_debug("EnemyIdle.gd - _on_Area2D_body_entered - Player entered the area - Transitioning to EnemyFollowing")
        emit_signal("transitioned", self, "EnemyFollowing")
        return


# func _on_Area2D_area_entered(area):
#     if not area.is_in_group("Player"):
#         return
#     # print_debug("EnemyIdle.gd - _on_Area2D_area_entered - Player entered the area")
#     enemy.player = area.get_parent()
#     if enemy.player.is_hidden:
#         return
#     print_debug("EnemyIdle.gd - _on_Area2D_area_entered - Player entered the area - Player: ", enemy.player)

#     if enemy.get_node("StateMachine").states.has("EnemyAttackingDistance".to_lower()):
#         print_debug("EnemyIdle.gd - _on_Area2D_body_entered - Player entered the area - Transitioning to EnemyAttackingDistance")
#         emit_signal("transitioned", self, "EnemyAttackingDistance")
#         return
    
#     if enemy.get_node("StateMachine").states.has("EnemyFollowing".to_lower()):
#         print_debug("EnemyIdle.gd - _on_Area2D_body_entered - Player entered the area - Transitioning to EnemyFollowing")
#         emit_signal("transitioned", self, "EnemyFollowing")
#         return


func Enter():
    enemy = get_parent().get_parent() # Getting the grand-parent of the script, i.e. the KinematicBody2D node to move it
    # Connecting the enemy aggro area to the function _on_Area2D_body_entered
    # i.e. this is to be able to detect enemy entering the aggro area

    # Check if enemy.get_node("Area2D") is already connected:
    if enemy.has_node(AGGRO_AREA_NAME):
        print("Connecting Connecting the enemy aggro area to the function _on_Area2D_body_entered")
        # if enemy.get_node(AGGRO_AREA_NAME).is_connected("body_entered", _on_Area2D_body_entered) == false:
        #     print("Connecting Connecting the enemy aggro area to the function _on_Area2D_body_entered")
        #     enemy.get_node(AGGRO_AREA_NAME).connect("body_entered", _on_Area2D_body_entered)
        
        if enemy.get_node(AGGRO_AREA_NAME).is_connected("body_entered", _on_Area2D_body_entered) == false:
            print("Connecting Connecting the enemy aggro area to the function _on_Area2D_body_entered")
            enemy.get_node(AGGRO_AREA_NAME).connect("body_entered", _on_Area2D_body_entered)

    if enemy.get_node("AnimationPlayer").has_animation("idle"):
        enemy.get_node("AnimationPlayer").play("idle")

func Exit():
    if enemy.has_node(AGGRO_AREA_NAME):
        if enemy.get_node(AGGRO_AREA_NAME).is_connected("body_entered", _on_Area2D_body_entered):
            enemy.get_node(AGGRO_AREA_NAME).disconnect("body_entered", _on_Area2D_body_entered)
