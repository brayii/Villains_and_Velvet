var pointer_x = device_mouse_x_to_gui(0);
var pointer_y = device_mouse_y_to_gui(0);
if (action_cooldown > 0) action_cooldown--;
if (auto_timer > 0 && prompt_mode == "" && !game_over) {
    auto_timer--;
    if (auto_timer == 0) {
        if (phase == "enemy_continue_wait") draw_next_enemy_card();
        else command_action();
    }
}
if (!device_mouse_check_button_pressed(0, mb_left)) exit;

if (game_over) {
    if (point_in_rect(pointer_x, pointer_y, restart_rect)) reset_game();
    exit;
}

// Mandatory effects pause automatic turn-start resolution.
if (prompt_mode != "") {
    if (prompt_mode == "destroy_hand") {
        for (var hand_i = 0; hand_i < array_length(hand); hand_i++) {
            if (point_in_rect(pointer_x, pointer_y, hand_rects[hand_i])) {
                command_prompt_hand(hand_i);
                exit;
            }
        }
    } else {
        for (var build_i = 0; build_i < 3; build_i++) {
            if (point_in_rect(pointer_x, pointer_y, build_rects[build_i])) {
                command_prompt_build(build_i);
                exit;
            }
        }
    }
    log_add("Choose one of the highlighted cards.");
    exit;
}

if (point_in_rect(pointer_x, pointer_y, action_rect)) {
    var player_action_phase = phase == "step1_ready" || phase == "build" || phase == "attack";
    if (player_action_phase && action_cooldown <= 0 && command_action()) action_cooldown = 24;
    exit;
}

if (phase == "build") {
    for (var hand_i = 0; hand_i < array_length(hand); hand_i++) {
        if (point_in_rect(pointer_x, pointer_y, hand_rects[hand_i])) {
            command_select_hand(hand_i);
            exit;
        }
    }
    for (var build_i = 0; build_i < 3; build_i++) {
        if (point_in_rect(pointer_x, pointer_y, build_rects[build_i])) {
            command_select_build(build_i);
            exit;
        }
    }
}

if (phase == "attack") {
    for (var minion_i = 0; minion_i < 2; minion_i++) {
        if (point_in_rect(pointer_x, pointer_y, minion_rects[minion_i])) {
            command_attack_minion(minion_i);
            exit;
        }
    }
    if (point_in_rect(pointer_x, pointer_y, leader_rect)) {
        command_attack_leader();
        exit;
    }
}
