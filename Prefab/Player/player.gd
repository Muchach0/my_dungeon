extends CharacterBody2D
# This demo is an example of controling a high number of 2D objects with logic
# and collision without using nodes in the scene. This technique is a lot more
# efficient than using instancing and nodes, but requires more programming and
# is less visual. Bullets are managed together in the `bullets.gd` script.


@export var INIT_NUMBER_OF_LIFE := 5
## The number of bullets currently touched by the player.
var touching := 0


@export var speed: float = 300.0

@onready var sprite_size: Vector2 = ($Sprite2D.texture.get_size() * scale) / 2

var number_of_life := INIT_NUMBER_OF_LIFE
var is_invincible: bool = false # used with safe zone, can be used later to make the player invincible for a short time after being hit.
var is_hidden: bool = false # used when the player should be hidden

var init_position = position
@export var synced_position := Vector2()
# @onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Array of BulletStrategy holding all the strategies applied to the player
@export var bullet_strategies: Array[BulletStrategy] = []

@onready var state_machine : Node = $StateMachine
@onready var sprite: Sprite2D = $Sprite2D

var peer_id = 0
var motion:= Vector2()
var last_nonzero_motion: Vector2 = Vector2.DOWN

# Mapping from cardinal direction to Sprite2D horizontal frame index (hframe)
# Adjust these values in the editor to match your spritesheet layout.
@export var direction_frames := {"down": 0, "right": 1, "left": 2, "up": 3,}

var is_force_field_enabled: bool = false # used to enable/disable the force field effect
@onready var force_field_area: Area2D = $ForceFieldArea
@onready var force_field_timer: Timer = $ForceFieldArea/ForceFieldTimer
var bonus_number: int = 0 # The number of bonuses picked up by the player

@onready var sync = $MultiplayerSynchronizer
@onready var camera = $PlayerCamera
@onready var timer_glow: Timer = $TimerGlow
@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
    # Duplicate the shader material to make individual modifications
    if material != null:
        material = material.duplicate()
        material.set_shader_parameter("enable_effect", false)
    print("player.gd - _ready() - id: " + str(peer_id) + " - is_multiplayer_authority: " + str(is_multiplayer_authority()))
    EventBus.connect("sync_bonus_count", on_sync_bonus_count)
    EventBus.add_upgrade_to_player.connect(on_add_upgrade_to_player)
    
    # Enable camera for local player only
    # Use a timer to ensure multiplayer authority is properly set
    await get_tree().process_frame
    setup_camera()
    if timer_glow != null:
        timer_glow.timeout.connect(stop_glow)
    if health_bar != null:
        health_bar.value = number_of_life
    # EventBus.connect("player_respawned", _on_player_respawned)
    # The player follows the mouse cursor automatically, so there's no point
    # in displaying the mouse cursor.
    # Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func setup_camera() -> void:
    return
    # Only enable camera for the local player (the one with multiplayer authority)
    if multiplayer == null or is_multiplayer_authority():
        camera.enabled = true
        camera.make_current()
        print("Camera enabled for local player: " + str(peer_id))
    else:
        camera.enabled = false
        print("Camera disabled for remote player: " + str(peer_id))

func on_sync_bonus_count(bonus_number_from_server: int, _is_bonus_picked_up: bool = false) -> void:
    bonus_number = bonus_number_from_server

func main_action_pressed() -> void:
    # This function is called when the main action is pressed (e.g., spacebar).
    # It can be used to trigger an action, such as shooting or interacting.
    print("Main action pressed")
    
    if multiplayer != null and not is_multiplayer_authority():
        print("Not the authority, cannot perform main action")
        return

    # TODO: CHECKING HERE IF WE ARE ALLOWED TO DO THAT - we should check if a bonus is available - ignoring for now
    if bonus_number <= 0:
        print("No bonus available, cannot perform main action")
        return
    activation_of_force_field.rpc(true)  # Call the function to activate the force field effect on all peers
    force_field_timer.start()  # Start the force field timer to disable the effect after a certain time

    # Add your custom logic for main action here, e.g., shoot, interact, etc.



func _physics_process(_delta: float) -> void:
    if is_hidden:
        return  # If the player is hidden, we don't process anything.
    if multiplayer == null or is_multiplayer_authority():
        var x_input = Input.get_axis("ui_left", "ui_right")
        var y_input = Input.get_axis("ui_up", "ui_down")
        motion = Vector2(x_input, y_input).normalized()
        synced_position = position

        if motion.length() > 0.01:
            last_nonzero_motion = motion
            _update_sprite_direction_from_motion(last_nonzero_motion)

        if Input.is_action_just_pressed("ui_accept"):
            main_action_pressed()
            # Add your custom logic for ui_accept here, e.g., interact, shoot, etc.

    else:
        position = synced_position

    # TODO: Fix state machine later
    # # If the player is not moving, we don't need to update the state machine
    # if x_input == 0 and y_input == 0 and state_machine.current_state is not PlayerIdle:
    #     state_machine.current_state.emit_signal("transitioned", state_machine.current_state, "PlayerIdle")
    # elif x_input != 0 or y_input != 0:
    #     # If the player is moving, we can transition to the walking state
    #     if state_machine.current_state is not PlayerWandering:
    #         state_machine.current_state.emit_signal("transitioned", state_machine.current_state, "PlayerWandering")

    # Move the player according to the inputs
    
    # synced_position = position
    # else:
    #     position = synced_position
        # If this is not the authority, we just update the position
        # based on the motion vector.
    # position += motion * delta
    
    # Getting the movement of the mouse so the sprite can follow its position.
    # if event is InputEventMouseMotion:
    #     position = event.position - Vector2(0, 16)

    # # Get input from the joystick
    # var x_input = Input.get_axis("ui_left", "ui_right")
    # var y_input = Input.get_axis("ui_up", "ui_down")

    # If the player is not moving, we don't need to update the state machine
    if not motion and state_machine.current_state is not PlayerIdle:
        state_machine.current_state.emit_signal("transitioned", state_machine.current_state, "PlayerIdle")
    elif motion:
        # If the player is moving, we can transition to the walking state
        if state_machine.current_state is not PlayerWandering:
            state_machine.current_state.emit_signal("transitioned", state_machine.current_state, "PlayerWandering")
        

    # Move the player according to the inputs
    # var direction = Vector2(x_input, y_input).normalized()
    velocity = motion * speed
    move_and_slide()
    # position += motion * speed * delta

    # # Clamp the player's position to stay within the screen bounds
    # var screen_size = get_viewport_rect().size
    # position.x = clamp(position.x, 0 + sprite_size.x , screen_size.x - sprite_size.x)
    # position.y = clamp(position.y, 0 + sprite_size.y, screen_size.y - sprite_size.y)


# func _on_body_shape_exited(_body_id: RID, _body: Node2D, _body_shape_index: int, _local_shape_index: int) -> void:
#     touching -= 1
#     # When non of the bullets are touching the player,
#     # sprite changes to happy face.
#     if touching == 0:
#         material.set_shader_parameter("enable_effect", false)
#         # sprite.frame = 0


# func _on_area_entered(area: Area2D) -> void:
func _on_hitbox_area_entered(area: Area2D) -> void:
    print("Player body is touched - area group: ", area.get_groups(), " - name: ", area.name)
    if "star" in area.get_groups():
        if multiplayer == null or is_multiplayer_authority(): # Only the authority should emit the signal.
            print("The star is touched 3")
            EventBus.emit_signal("star_touched", name)
    if "safeZone" in area.get_groups():
        if multiplayer == null or is_multiplayer_authority(): # Only the authority should emit the signal.
            print("The safezone is entered by the player")
            is_invincible = true
    if "bonus" in area.get_groups():
        if multiplayer == null or is_multiplayer_authority(): # Only the authority should emit the signal.
            print("The bonus is touched by the player")
            EventBus.emit_signal("bonus_touched", area.name)  # Emit a signal to notify the game logic that the player touched a bonus
            print("Bonus touched: ", area.name)
    if "upgrade" in area.get_groups():
        if multiplayer == null or is_multiplayer_authority(): # Only the authority should emit the signal.
            print("The upgrade is touched by the player")
            EventBus.upgrade_touched_on_authority_player.emit(area.name, area.bullet_strategy, name)  # Emit a signal to notify the game logic that the player touched a bonus
            print("Upgrade touched: ", area.name)
            # bullet_strategies.append(area.bullet_strategy) # Adding the upgrade to the player's bullet strategies
            # print("Bullet strategies: ", bullet_strategies)

            # TODO: Adding the upgrade to the player's bullet strategies should be handled by the server and broadcasted.
            # TODO: The server should also remove the upgrade from the scene.

    pass # Replace with function body.

func _on_area_exited(area: Area2D) -> void:
    if "safeZone" in area.get_groups():
        if multiplayer == null or is_multiplayer_authority(): # Only the authority should emit the signal.
            print("The safezone is left by the player")
            is_invincible = false
    pass # Replace with function body.


func stop_glow() -> void:
    material.set_shader_parameter("enable_effect", false)
func start_glow() -> void:
    material.set_shader_parameter("enable_effect", true)
    timer_glow.start()

func take_damage(damage:int, from_player_id: int) -> void:
    # print("Player.gd - take_damage() - Taking damage: ", damage, " from player id: ", from_player_id)
    if multiplayer != null and not is_multiplayer_authority(): # If this is not the authority, we don't process the hit.
        # print("Player.gd - take_damage() - Not the authority, cannot take damage")
        return
    if is_invincible: # Do nothing if the player is invincible.
        # print("Player.gd - take_damage() - Player is invincible")
        return
    
    # Check if the bullet belongs to this player (prevent self-damage)
    if peer_id == from_player_id:
        # print("Player avoided self-damage from own bullet")
        return

    sync_take_damage_on_all_peers.rpc(number_of_life, damage, from_player_id)
    # If the player is invincible, we don't want to decrease the number of lives.
    # print("Player touched by a bullet")
    # touching += 1
    # start_glow()
    # number_of_life -= damage
    # print("Player took damage: ", damage, " from player id: ", from_player_id)
    # EventBus.emit_signal("player_hit", name, number_of_life)
    # # if touching >= 1:
    # #     material.set_shader_parameter("enable_effect", true)
    #     # sprite.frame = 1
    return # Replace with function body.


@rpc("any_peer", "call_local", "reliable") # Function called on local authority to all players to sync take damage
func sync_take_damage_on_all_peers(number_of_life_from_owner:int, damage:int, from_player_id: int) -> void:
    print("player.gd - sync_take_damage_on_all_peers() - Player took damage: ", damage, " from player id: ", from_player_id)
    number_of_life = number_of_life_from_owner - damage
    health_bar.value = number_of_life
    start_glow()
    var player_owner_id = multiplayer.get_remote_sender_id()
    EventBus.player_hit.emit(player_owner_id, name, number_of_life)
    return

func hide_player() -> void:
    # This function is called when the player is hit and should be hidden.
    # It can be used to hide the player sprite or disable player controls.
    print("Hiding player: " + name)
    is_hidden = true
    visible = false
    # Hide the player sprite
    $Sprite2D.visible = false
    # $DetectionArea.monitoring = false
    # $DetectionArea.monitorable = false
    # Disable player controls
    $StateMachine.current_state.emit_signal("transitioned", $StateMachine.current_state, "PlayerIdle")
    $Hitbox.monitoring = false
    $Hitbox.monitorable = false
    EventBus.player_died.emit(peer_id)
    if health_bar != null:
        health_bar.visible = false

func reset_player(new_position: Vector2) -> void:
    # This function is called when the player is respawned.
    is_hidden = false
    visible = true
    position = new_position
    synced_position = new_position
    number_of_life = INIT_NUMBER_OF_LIFE
    is_invincible = false  # Reset the invincibility state
    touching = 0  # Reset the number of bullets touching the player
    # Showing the player sprite and enabling the detection area
    $Sprite2D.visible = true
    # $DetectionArea.monitoring = true
    # $DetectionArea.monitorable = true
    $Hitbox.monitoring = true
    $Hitbox.monitorable = true
    material.set_shader_parameter("enable_effect", false)
    # Ensure camera is properly set up after respawn
    setup_camera()
    if health_bar != null:
        health_bar.visible = true
        health_bar.value = number_of_life


####################### FORCE FIELD SECTION #######################
@rpc("any_peer", "call_local", "reliable")
func activation_of_force_field(should_activate_force_field) -> void:
    # This function is called to activate the force field effect.
    if should_activate_force_field:
        print("Activating force field")
        is_force_field_enabled = true
        force_field_area.visible = true
        force_field_area.monitorable = true
        force_field_area.monitoring = true
        EventBus.emit_signal("bonus_used")  # Notify the game logic that a bonus was used
        

    else:
        print("Deactivating force field")
        is_force_field_enabled = false
        force_field_area.visible = false
        force_field_area.monitorable = false
        force_field_area.monitoring = false
    # material.set_shader_parameter("enable_effect", true)  # Enable the force field effect in the shader
    # sprite.frame = 1  # Change the sprite frame to indicate the force field is


func _on_force_field_timer_timeout() -> void: # When the timer of force field is over, we disable the force field effect on all peers from the authority.
    if multiplayer != null and not is_multiplayer_authority():
        print("Not the authority, cannot perform main action")
        return
    activation_of_force_field.rpc(false)


########################### UPGRADE SECTION #######################
func on_add_upgrade_to_player(bullet_strategy: BulletStrategy, player_name: String) -> void:
    if player_name != name:
        return
    print("player.gd - on_add_upgrade_to_player() - Adding upgrade to player: ", player_name)
    bullet_strategies.append(bullet_strategy)
    print("Bullet strategies: ", bullet_strategies)


# ------------------------- SPRITE DIRECTION SECTION -------------------------
func _get_cardinal_from_vector(direction: Vector2) -> String:
    # Returns one of: "left", "right", "up", "down"
    # Chooses the dominant axis to avoid flickering on diagonals
    if absf(direction.x) >= absf(direction.y):
        return "right" if direction.x > 0.0 else "left"
    else:
        return "down" if direction.y > 0.0 else "up"


func _update_sprite_direction_from_motion(direction: Vector2) -> void:
    if sprite == null:
        return
    # Only attempt to change frames if the texture is set up as a spritesheet
    if sprite.hframes <= 1 and sprite.vframes <= 1:
        return

    var dir_name := _get_cardinal_from_vector(direction)
    var target_frame: int = int(direction_frames.get(dir_name, 0))
    sprite.frame = target_frame
    # In Godot 4, set the horizontal frame using frame_coords.x
    # var coords := sprite.frame_coords
    # coords.x = target_hframe
    # sprite.frame_coords = coords
