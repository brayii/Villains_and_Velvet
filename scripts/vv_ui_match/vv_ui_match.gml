function auto_toggle_hit_rect() {
    return {x:auto_toggle_rect.x, y:auto_toggle_rect.y,
        w:112, h:auto_toggle_rect.h};
}

function ui_card_at_point(_pointer_x, _pointer_y) {
    if (point_in_rect(_pointer_x, _pointer_y, leader_rect)) {
        return {type:"leader", index:0, card:enemy_leader};
    }
    for (var hand_i = 0; hand_i < 3; hand_i++) {
        if (point_in_rect(_pointer_x, _pointer_y, hand_rects[hand_i])
        && hand_i < array_length(hand) && !is_undefined(hand[hand_i])) {
            return {type:"hand", index:hand_i, card:hand[hand_i]};
        }
    }
    for (var build_i = 0; build_i < 3; build_i++) {
        if (point_in_rect(_pointer_x, _pointer_y, build_rects[build_i]) && !is_undefined(build[build_i])) {
            return {type:"build", index:build_i, card:build[build_i]};
        }
    }
    if (!is_undefined(revealed_enemy_card) && point_in_rect(_pointer_x, _pointer_y, minion_rects[1])) {
        return {type:"reveal", index:0, card:revealed_enemy_card};
    }
    for (var minion_i = 0; minion_i < 2; minion_i++) {
        if (point_in_rect(_pointer_x, _pointer_y, minion_rects[minion_i]) && !is_undefined(minions[minion_i])) {
            return {type:"minion", index:minion_i, card:minions[minion_i]};
        }
    }
    return undefined;
}

function ui_run_card_tap(_type, _index) {
    if (enemy_auto_play && (prompt_mode == "enemy_attack"
    || prompt_mode == "enemy_attack_hand")) return false;
    if ((prompt_mode == "destroy_hand" || prompt_mode == "enemy_attack_hand")
    && _type == "hand") return command_prompt_hand(_index);
    if (prompt_mode != "" && _type == "build") return command_prompt_build(_index);
    if (prompt_mode != "") return false;
    if (phase == "build") {
        if (_type == "hand") {
            detail_card_selected = undefined;
            return command_select_hand(_index);
        }
        if (_type == "build") {
            detail_card_selected = undefined;
            return command_select_build(_index);
        }
    }
    if (phase == "attack" && _type == "minion") return command_attack_minion(_index);
    if (phase == "attack" && _type == "leader") return command_attack_leader();
    if (_type == "leader") detail_card_selected = enemy_leader;
    else if (_type == "reveal") detail_card_selected = revealed_enemy_card;
    else if (_type == "minion") detail_card_selected = minions[_index];
    else if (_type == "hand" && _index < array_length(hand)) detail_card_selected = hand[_index];
    else if (_type == "build") detail_card_selected = build[_index];
    return !is_undefined(detail_card_selected);
}

function ui_drag_target_at_point(_pointer_x, _pointer_y) {
    for (var hand_i = 0; hand_i < 3; hand_i++) {
        if (point_in_rect(_pointer_x, _pointer_y, hand_rects[hand_i])) return {type:"hand", index:hand_i};
    }
    for (var build_i = 0; build_i < 3; build_i++) {
        if (point_in_rect(_pointer_x, _pointer_y, build_rects[build_i])) return {type:"build", index:build_i};
    }
    return undefined;
}

function ui_drag_target_is_legal(_target_type, _target_index) {
    if (!pointer_card_down || !drag_active || pointer_card_type == _target_type) return false;
    if (pointer_card_type == "hand" && _target_type == "build") return true;
    if (pointer_card_type == "build" && _target_type == "hand") {
        return _target_index >= 0 && _target_index < array_length(hand)
            && !is_undefined(hand[_target_index]);
    }
    return false;
}

function vv_ui_handle_input() {
    var pointer_x = device_mouse_x_to_gui(0);
    var pointer_y = device_mouse_y_to_gui(0);
    var pointer_pressed = device_mouse_check_button_pressed(0, mb_left);
    var pointer_held = device_mouse_check_button(0, mb_left);
    var pointer_released = device_mouse_check_button_released(0, mb_left);

    if (!is_undefined(card_popup)) {
        if (pointer_pressed) {
            card_popup = undefined;
            card_popup_type = "";
        }
        return;
    }

    if (pointer_pressed && !setup_active && !game_over && !match_menu_active
    && point_in_rect(pointer_x, pointer_y, auto_toggle_hit_rect())) {
        vv_settings_toggle_enemy_auto();
        return;
    }

    if (pointer_pressed && !setup_active && !game_over && !match_menu_active
    && point_in_rect(pointer_x, pointer_y, match_menu_rect)) {
        enemy_ai_cancel_pending_targeting();
        match_menu_active = true;
        quit_match_confirm = false;
        return;
    }

    if (match_menu_active) {
        if (!pointer_pressed) return;
        if (quit_match_confirm) {
            if (point_in_rect(pointer_x, pointer_y, menu_confirm_rect)) {
                match_menu_active = false;
                quit_match_confirm = false;
                command_open_setup();
            } else if (point_in_rect(pointer_x, pointer_y, menu_cancel_rect)) {
                quit_match_confirm = false;
            }
            return;
        }
        if (point_in_rect(pointer_x, pointer_y, menu_resume_rect)) {
            match_menu_active = false;
        } else if (point_in_rect(pointer_x, pointer_y, menu_options_rect)) {
            quit_match_confirm = true;
        } else if (point_in_rect(pointer_x, pointer_y, menu_exit_rect)) {
            game_end();
        }
        return;
    }

    if (!setup_active && !game_over && pointer_pressed) {
        var pressed_card = ui_card_at_point(pointer_x, pointer_y);
        if (!is_undefined(pressed_card)) {
            pointer_card_down = true;
            pointer_card_type = pressed_card.type;
            pointer_card_index = pressed_card.index;
            pointer_card_value = pressed_card.card;
            pointer_down_x = pointer_x;
            pointer_down_y = pointer_y;
            pointer_max_distance = 0;
            pointer_hold_frames = 0;
            drag_active = false;
            return;
        }
        detail_card_selected = undefined;
    }

    if (pointer_card_down) {
        if (pointer_held) {
            pointer_max_distance = max(pointer_max_distance,
                point_distance(pointer_down_x, pointer_down_y, pointer_x, pointer_y));
        }
        if (pointer_held && pointer_max_distance <= tap_move_limit) {
            pointer_hold_frames++;
            if (pointer_hold_frames >= inspect_hold_frames) {
                card_popup = pointer_card_value;
                card_popup_type = pointer_card_type;
                pointer_card_down = false;
                pointer_card_type = "";
                pointer_card_index = -1;
                pointer_card_value = undefined;
                pointer_hold_frames = 0;
                return;
            }
        }
        if (pointer_held && phase == "build" && prompt_mode == ""
        && (pointer_card_type == "hand" || pointer_card_type == "build")) {
            if (pointer_max_distance >= drag_threshold && !drag_active) {
                drag_active = true;
                pointer_hold_frames = 0;
            }
        }
        if (pointer_released) {
            if (drag_active) {
                var drag_target = ui_drag_target_at_point(pointer_x, pointer_y);
                if (!is_undefined(drag_target)) {
                    command_drag_card(pointer_card_type, pointer_card_index, drag_target.type, drag_target.index);
                }
            } else {
                var released_card = ui_card_at_point(pointer_x, pointer_y);
                var same_card = !is_undefined(released_card)
                    && released_card.type == pointer_card_type && released_card.index == pointer_card_index;
                if (same_card && pointer_max_distance <= tap_move_limit) {
                    ui_run_card_tap(pointer_card_type, pointer_card_index);
                }
            }
            pointer_card_down = false;
            pointer_card_type = "";
            pointer_card_index = -1;
            pointer_card_value = undefined;
            pointer_max_distance = 0;
            pointer_hold_frames = 0;
            drag_active = false;
        }
        return;
    }

    if (!pointer_pressed) return;

    if (setup_active) {
        if (point_in_rect(pointer_x, pointer_y, setup_exit_rect)) {
            game_end();
            return;
        }
        if (point_in_rect(pointer_x, pointer_y, setup_gear_rect())) {
            setup_advanced_events = !setup_advanced_events;
            return;
        }
        if (!content_registry_validation.valid) return;
        if (!setup_advanced_events) {
            if (point_in_rect(pointer_x, pointer_y, setup_start_rect)) command_start_game_from_setup();
            return;
        }
        if (point_in_rect(pointer_x, pointer_y, setup_selector_button_rect("leader"))) {
            command_select_leader(1);
            return;
        }
        if (point_in_rect(pointer_x, pointer_y, setup_selector_button_rect("scenario"))) {
            command_select_scenario(1);
            return;
        }
        if (point_in_rect(pointer_x, pointer_y, setup_selector_button_rect("minion_set"))) {
            command_select_minion_set(1);
            return;
        }
        for (var setup_slot = 0; setup_slot < CORE_HERO_COUNT; setup_slot++) {
            if (point_in_rect(pointer_x, pointer_y, setup_hero_button_rect(setup_slot, 1))) {
                command_cycle_hero_slot(setup_slot, 1);
                return;
            }
        }
        if (point_in_rect(pointer_x, pointer_y, setup_restore_defaults_rect())) {
            command_restore_enemy_event_defaults();
            return;
        }
        if (setup_advanced_events && setup_event_handle_category_input("strike", pointer_x, pointer_y)) return;
        if (setup_advanced_events && setup_event_handle_category_input("twist", pointer_x, pointer_y)) return;
        if (point_in_rect(pointer_x, pointer_y, setup_start_rect)) command_start_game_from_setup();
        return;
    }

    if (game_over) {
        if (point_in_rect(pointer_x, pointer_y, result_play_rect)) {
            reset_game();
            setup_active = false;
        } else if (point_in_rect(pointer_x, pointer_y, result_options_rect)) {
            command_open_setup();
        } else if (point_in_rect(pointer_x, pointer_y, result_exit_rect)) {
            game_end();
        }
        return;
    }

    // Mandatory effects take input priority and pause automatic resolution.
    if (prompt_mode != "") {
        log_add("Choose one of the highlighted cards.");
        return;
    }

    if (point_in_rect(pointer_x, pointer_y, action_rect)) {
        var player_action_phase = phase == "step1_ready" || phase == "build" || phase == "attack";
        if (player_action_phase && action_cooldown <= 0 && command_action()) {
            detail_card_selected = undefined;
            action_cooldown = 24;
        }
        return;
    }

    if (phase == "attack") {
        if (point_in_rect(pointer_x, pointer_y, leader_rect)) command_attack_leader();
    }
}

function ui_drag_hides_card(_type, _index) {
    return pointer_card_down && drag_active && pointer_card_type == _type && pointer_card_index == _index;
}

function ui_card_rect(_type, _index) {
    if (_type == "leader") return leader_rect;
    if (_type == "hand" && _index >= 0 && _index < 3) return hand_rects[_index];
    if (_type == "build" && _index >= 0 && _index < 3) return build_rects[_index];
    if (_type == "reveal") return minion_rects[1];
    if (_type == "minion" && _index >= 0 && _index < 2) return minion_rects[_index];
    return undefined;
}

function draw_hold_feedback() {
    if (!pointer_card_down || drag_active || pointer_hold_frames <= 0) return;
    var held_rect = ui_card_rect(pointer_card_type, pointer_card_index);
    if (is_undefined(held_rect)) return;
    var hold_progress = clamp(pointer_hold_frames / inspect_hold_frames, 0, 1);
    draw_set_alpha(0.45 + hold_progress * 0.55);
    draw_set_color(COL_GOLD);
    draw_roundrect(held_rect.x - 2, held_rect.y - 2,
        held_rect.x + held_rect.w + 2, held_rect.y + held_rect.h + 2, true);
    draw_rectangle(held_rect.x, held_rect.y + held_rect.h - 5,
        held_rect.x + held_rect.w * hold_progress, held_rect.y + held_rect.h, false);
    draw_set_alpha(1);
}

function draw_card_popup() {
    if (is_undefined(card_popup)) return;
    draw_set_alpha(0.88);
    draw_set_color(COL_BG);
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1);

    if (card_popup_type == "leader") {
        var leader_popup = {x:40, y:220, w:1200, h:228};
        draw_panel({x:25, y:205, w:1230, h:258}, make_color_rgb(24, 33, 46), COL_GOLD);
        draw_art_contained(leader_art_sprite, leader_popup, 2);

        var leader_scale = leader_popup.w / leader_rect.w;
        draw_center(string(leader_hp), leader_popup.x + 224 * leader_scale,
            leader_popup.y + 61 * leader_scale, make_color_rgb(43, 24, 24));
        var strikes_left = 0;
        for (var popup_strike_i = 0; popup_strike_i < array_length(enemy_deck); popup_strike_i++) {
            if (enemy_deck[popup_strike_i].card_type == "strike") strikes_left++;
        }
        draw_set_color(make_color_rgb(17, 22, 36));
        draw_rectangle(leader_popup.x + 253 * leader_scale, leader_popup.y + 82 * leader_scale,
            leader_popup.x + 272 * leader_scale, leader_popup.y + 97 * leader_scale, false);
        draw_center(string(strikes_left), leader_popup.x + 263 * leader_scale,
            leader_popup.y + 89 * leader_scale, COL_TEXT);
        draw_set_color(COL_GOLD);
        draw_roundrect(leader_popup.x, leader_popup.y,
            leader_popup.x + leader_popup.w, leader_popup.y + leader_popup.h, true);
    } else if (card_popup_type == "reveal") {
        var reveal_popup_rect = {x:425, y:25, w:430, h:645};
        draw_panel({x:410, y:10, w:460, h:700}, make_color_rgb(24, 33, 46), COL_GOLD);
        draw_enemy_reveal(card_popup, reveal_popup_rect);
    } else {
        var popup_rect = {x:425, y:25, w:430, h:645};
        draw_panel({x:410, y:10, w:460, h:700}, make_color_rgb(24, 33, 46), COL_GOLD);
        draw_card(card_popup, popup_rect, false, false);
    }
    draw_center("TAP ANYWHERE TO CLOSE", 640, 690, COL_TEXT);
}

function draw_auto_checkbox(_rect) {
    draw_set_alpha(0.28);
    draw_set_color(COL_PANEL);
    draw_rectangle(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, false);
    draw_set_alpha(0.85);
    draw_set_color(enemy_auto_play ? COL_ACCENT : COL_EDGE);
    draw_rectangle(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, true);
    draw_set_alpha(1);
    if (enemy_auto_play) {
        draw_set_color(COL_ACCENT);
        draw_line_width(_rect.x + 11, _rect.y + 24,
            _rect.x + 20, _rect.y + 33, 4);
        draw_line_width(_rect.x + 20, _rect.y + 33,
            _rect.x + 36, _rect.y + 13, 4);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_color(COL_TEXT);
    draw_text(_rect.x + _rect.w + 8, _rect.y + _rect.h / 2, "AUTO");
}

function vv_ui_draw_game() {
vv_ui_set_font(UI_FONT_BODY);
draw_clear(COL_BG);
// A light global veil preserves the artwork; local glass and shadows carry text contrast.
var background_rect = {x:0, y:0, w:1280, h:720};
draw_art_cover(background_art_sprite, background_rect);
draw_set_alpha(setup_active ? 0.30 : 0.34);
draw_set_color(COL_BG);
draw_rectangle(0, 0, 1280, 720, false);
draw_set_alpha(1);

if (setup_active) {
    vv_ui_draw_setup();
    return;
}

// Leader and Minions.
draw_setup_gear(match_menu_rect, match_menu_active);
draw_auto_checkbox(auto_toggle_rect);
var leader_protected = leader_is_protected();
draw_panel(leader_rect, make_color_rgb(72, 37, 48), leader_protected ? COL_GOLD : COL_DANGER);
draw_art_contained(leader_art_sprite, leader_rect, 2);

// Live values are placed in the fields built into the Leader artwork.
draw_center(string(leader_hp), leader_rect.x + 224, leader_rect.y + 61, make_color_rgb(43, 24, 24));
var leader_strikes_remaining = 0;
for (var strike_i = 0; strike_i < array_length(enemy_deck); strike_i++) {
    if (enemy_deck[strike_i].card_type == "strike") leader_strikes_remaining++;
}
draw_set_color(make_color_rgb(17, 22, 36));
draw_rectangle(leader_rect.x + 253, leader_rect.y + 82,
    leader_rect.x + 272, leader_rect.y + 97, false);
draw_center(string(leader_strikes_remaining), leader_rect.x + 263, leader_rect.y + 89, COL_TEXT);
draw_set_color(leader_protected ? COL_GOLD : COL_DANGER);
draw_roundrect(leader_rect.x, leader_rect.y, leader_rect.x + leader_rect.w, leader_rect.y + leader_rect.h, true);

draw_center_shadow("AREA 2", 645, 17, COL_GOLD);
vv_ui_set_font(UI_FONT_SMALL);
draw_center_shadow("ESCAPES WHEN PUSHED", 645, 36, COL_MUTED);
vv_ui_set_font(UI_FONT_BODY);
if (!is_undefined(revealed_enemy_card)) {
    draw_center_shadow("ENEMY DRAW #" + string(revealed_enemy_draw_number) + " — "
        + (revealed_enemy_card.card_type == "strike" ? "LEADER STRIKE" : "TWIST"), 865, 17, COL_GOLD);
    draw_center_shadow(revealed_enemy_card.name, 865, 36, COL_TEXT);
} else {
    draw_center_shadow("AREA 1", 865, 17, COL_GOLD);
    vv_ui_set_font(UI_FONT_SMALL);
    draw_center_shadow("MINIONS ENTER HERE", 865, 36, COL_MUTED);
    vv_ui_set_font(UI_FONT_BODY);
}
draw_card(minions[0], minion_rects[0], false, false);
if (!is_undefined(revealed_enemy_card)) draw_enemy_reveal(revealed_enemy_card, minion_rects[1]);
else draw_card(minions[1], minion_rects[1], false, false);
draw_center_shadow("←", 755, 186, COL_ACCENT);

// Build and Hand.
draw_center_shadow("BUILD AREA", 640, 297, COL_MUTED);
for (var build_i = 0; build_i < 3; build_i++) {
    var legal_build = (prompt_mode != "" && prompt_build_is_legal(build_i))
        || (phase == "build" && prompt_mode == "" && selected_hand >= 0)
        || ui_drag_target_is_legal("build", build_i);
    var visible_build_card = ui_drag_hides_card("build", build_i) ? undefined : build[build_i];
    var auto_selected = enemy_auto_play && enemy_ai_visual_stage == "targeting"
        && enemy_ai_pending_zone == "build"
        && enemy_ai_selected_slot == build_i;
    draw_card(visible_build_card, build_rects[build_i], selected_build == build_i || auto_selected, legal_build);
}

draw_center_shadow("HAND", 640, 512, COL_MUTED);
for (var hand_i = 0; hand_i < 3; hand_i++) {
    var hand_card = hand_i < array_length(hand) ? hand[hand_i] : undefined;
    var legal_hand = ((prompt_mode == "destroy_hand" && hand_i < array_length(hand)
        && !is_undefined(hand_card))
        || (prompt_mode == "enemy_attack_hand" && enemy_hand_target_is_legal(hand_i, prompt_value)));
    legal_hand = legal_hand || ui_drag_target_is_legal("hand", hand_i);
    if (ui_drag_hides_card("hand", hand_i)) hand_card = undefined;
    var auto_hand_selected = enemy_auto_play && enemy_ai_visual_stage == "targeting"
        && enemy_ai_pending_zone == "hand" && enemy_ai_selected_slot == hand_i;
    draw_card(hand_card, hand_rects[hand_i], selected_hand == hand_i || auto_hand_selected, legal_hand);
}

// Event log.
if (debug_event_log) {
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(COL_MUTED);
    draw_text(16, 222, "EVENT LOG");
    for (var log_i = 0; log_i < array_length(log_lines); log_i++) {
        var log_box = {x:12, y:244 + log_i * 67, w:270, h:60};
        draw_panel(log_box, make_color_rgb(24, 33, 46), COL_EDGE);
        draw_text_ext(log_box.x + 8, log_box.y + 7, log_lines[log_i], 16, log_box.w - 16);
    }
}

// Context help.
var instruction = "";
var build_confirm_heading = "";
if (prompt_mode == "" && enemy_attack_notice != "") instruction = enemy_attack_notice;
else if (prompt_mode == "enemy_attack") instruction = "Choose a highlighted Build card.";
else if (prompt_mode == "enemy_attack_hand") instruction = "The Build is empty. Choose a highlighted Hand card.";
else if (prompt_mode == "disrupt") instruction = "Choose a highlighted Build card.";
else if (prompt_mode == "shatter") instruction = "Choose a highlighted card with the lowest HP.";
else if (prompt_mode == "full_assault_disrupt") instruction = "Disrupt: choose a highlighted Build card.";
else if (prompt_mode == "full_assault_shatter") instruction = "Shatter: choose a highlighted lowest-HP card.";
else if (prompt_mode == "destroy_hand") instruction = prompt_source + "\nChoose a highlighted Hand card.\n"
    + string(escape_cards_remaining) + " remaining.";
else if (phase == "step1_ready") instruction = turn_number == 1
    ? "Draw three cards to begin."
    : "Draw three cards for the next turn.";
else if (phase == "step2_ready") instruction = "Advance Minions and resolve escapes.";
else if (phase == "step3_ready") instruction = "Draw an Enemy card and resolve its attack.";
else if (phase == "step4_ready") instruction = "Build phase is opening.";
else if (phase == "start_resolving") instruction = step_number == 2
    ? "Resolving Minion movement and escapes..."
    : "Resolving the Enemy Draw and Attack...";
else if (phase == "build") {
    if (build_finish_confirm) {
        var empty_build_spaces = 0;
        for (var warning_build_i = 0; warning_build_i < 3; warning_build_i++) {
            if (is_undefined(build[warning_build_i])) empty_build_spaces++;
        }
        if (!build_changed && empty_build_spaces > 0) build_confirm_heading = "NO CHANGES · EMPTY SPACES";
        else if (!build_changed) build_confirm_heading = "NO BUILD CHANGES";
        else build_confirm_heading = "EMPTY BUILD SPACES";
        instruction = "Confirm your Build or move a card.";
    } else if (selected_hand >= 0) instruction = "Hand card selected. Tap a Build space to place or swap it.\nHold to inspect.";
    else if (selected_build >= 0) instruction = "Build card selected. Tap a Hand card to swap it.\nHold to inspect.";
    else instruction = "Build your attack.\nTap or drag cards. Hold to inspect.";
} else if (phase == "attack") instruction = "ATTACK " + string(attack_left)
    + "\nTap a target. Hold to inspect.\nToo little Attack is not spent.";
else if (phase == "attack_complete_wait") instruction = attack_notice_text;
else if (phase == "step5_ready") instruction = "Calculating your Attack...";
else if (phase == "step6_ready") instruction = "Discarding the cards left in your Hand...";
else if (phase == "end_ready") instruction = "Ending your turn...";
else if (phase == "enemy_event_reveal_wait") instruction = "Enemy Event resolved.\nAnother Enemy card must be drawn.";
else if (phase == "enemy_event_gap_wait") instruction = "Drawing the next Enemy card...";
if (prompt_mode == "enemy_attack") {
    instruction = prompt_source + "\nAttack remaining: " + string(prompt_value) + "\n"
        + (enemy_auto_play && enemy_ai_visual_stage == "targeting"
            ? "Target: " + build[enemy_ai_selected_slot].name
            : (enemy_auto_play ? "Enemy is choosing a target."
            : (build_has_priority() ? "Choose a highlighted Guard or Fortress." : "Choose a card this Attack can defeat.")));
}
if (prompt_mode == "enemy_attack_hand") {
    instruction = prompt_source + "\nAttack remaining: " + string(prompt_value) + "\n"
        + (enemy_auto_play && enemy_ai_visual_stage == "targeting"
            ? "Target: " + hand[enemy_ai_selected_slot].name
            : (enemy_auto_play ? "Enemy is choosing a Hand target."
            : "Choose a Hand card this Attack can defeat."));
}
if (enemy_auto_play && enemy_ai_visual_stage == "result") {
    instruction = enemy_ai_result_heading + "\n" + enemy_ai_result_text;
}
var phase_names = [
    "DRAW CARDS", "ADVANCE / ESCAPE", "ENEMY DRAW / ATTACK", "BUILD",
    "PLAYER ATTACK", "DISCARD", "END TURN"
];
var context_panel = {x:985, y:16, w:280, h:174};
draw_glass_panel(context_panel, make_color_rgb(24, 33, 46), COL_EDGE, 0.62);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(COL_GOLD);
draw_text(1000, 27, "STEP " + string(step_number) + " — " + phase_names[step_number - 1]);
vv_ui_set_font(UI_FONT_SMALL);
draw_set_color(COL_MUTED);
draw_text(1000, 51, "TURN STEPS");
for (var step_i = 0; step_i < 7; step_i++) {
    var active_step = step_i + 1 == step_number;
    draw_set_alpha(active_step ? 1 : 0.58);
    draw_set_color(active_step ? COL_GOLD : COL_MUTED);
    draw_text(1000, 70 + step_i * 14, string(step_i + 1) + "  " + phase_names[step_i]);
}
draw_set_alpha(1);
vv_ui_set_font(UI_FONT_BODY);

// Short current instruction remains separate from the permanent step list.
if (build_finish_confirm && phase == "build") {
    var build_warning_rect = {x:985, y:199, w:280, h:105};
    draw_glass_panel(build_warning_rect, make_color_rgb(42, 35, 24), COL_GOLD, 0.48);
    draw_set_color(COL_GOLD);
    draw_text_ext(1000, 214, build_confirm_heading, 18, 250);
    draw_set_color(COL_TEXT);
    draw_text_ext(1000, 244, instruction, 18, 250);
} else if ((attack_finish_confirm && phase == "attack") || phase == "attack_complete_wait") {
    var attack_warning_rect = {x:985, y:199, w:280, h:105};
    draw_glass_panel(attack_warning_rect, make_color_rgb(42, 35, 24), COL_GOLD, 0.48);
    draw_set_color(COL_GOLD);
    var attack_heading = phase == "attack_complete_wait"
        ? attack_notice_heading
        : "UNUSED ATTACK: " + string(attack_left);
    draw_text_ext(1000, 214, attack_heading, 18, 250);
    draw_set_color(COL_TEXT);
    var attack_warning_text = phase == "attack_complete_wait"
        ? attack_notice_text
        : "Confirm the end of your Attack step or attack a target.";
    draw_text_ext(1000, 244, attack_warning_text, 18, 250);
} else {
    var instruction_panel = {x:985, y:199, w:280, h:116};
    draw_glass_panel(instruction_panel, make_color_rgb(24, 33, 46), COL_EDGE, 0.38);
    draw_set_color(prompt_mode == "enemy_attack" ? COL_DANGER : COL_TEXT);
    draw_text_ext(1000, 211, instruction, 18, 250);
}

// A selected card gets a readable description without covering the board.
var detail_card = undefined;
if (selected_hand >= 0 && selected_hand < array_length(hand)) detail_card = hand[selected_hand];
else if (selected_build >= 0 && selected_build < 3) detail_card = build[selected_build];
else detail_card = detail_card_selected;

if (!is_undefined(detail_card)) {
    var detail_panel = {x:985, y:326, w:280, h:162};
    draw_glass_panel(detail_panel, make_color_rgb(24, 33, 46), COL_EDGE, 0.84);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(COL_MUTED);
    draw_text(1000, 338, "CARD DETAILS");
    draw_set_color(COL_TEXT);
    draw_text(1000, 362, string_upper(detail_card.name));
    if (variable_struct_exists(detail_card, "atk")) {
        draw_set_color(COL_GOLD);
        draw_text(1000, 386, "ATK " + string(detail_card.atk));
        draw_set_color(COL_ACCENT);
        draw_text(1090, 386, "HP " + string(detail_card.hp));
    }
    var detail_y = variable_struct_exists(detail_card, "atk") ? 411 : 386;
    draw_set_color(COL_TEXT);
    var detail_text = variable_struct_exists(detail_card, "abilities")
        ? card_abilities_text(detail_card)
        : (detail_card.effect != "" ? detail_card.effect : "No ability.");
    draw_text_ext(1000, detail_y, detail_text, 15, 250);
}

// Main action.
var match_panel = {x:985, y:550, w:280, h:48};
draw_glass_panel(match_panel, make_color_rgb(24, 33, 46), COL_EDGE, 0.62);
vv_ui_set_font(UI_FONT_SMALL);
draw_set_halign(fa_left);
draw_set_valign(fa_middle);
draw_set_color(COL_TEXT);
draw_text(997, 574, "T" + string(turn_number)
    + " · DECK " + string(array_length(player_deck))
    + " · DISC " + string(array_length(player_discard))
    + " · ENEMY " + string(array_length(enemy_deck)));
vv_ui_set_font(UI_FONT_BODY);

var button_enabled = prompt_mode == "" && action_cooldown <= 0
    && (phase == "step1_ready" || phase == "build" || phase == "attack");
var confirming_build = phase == "build" && build_finish_confirm;
var confirming_attack = phase == "attack" && attack_finish_confirm;
var button_fill = button_enabled ? ((confirming_build || confirming_attack) ? COL_GOLD : COL_ACCENT) : COL_PANEL;
var button_outline = button_enabled ? COL_TEXT : COL_EDGE;
draw_panel(action_rect, button_fill, button_outline);
var button_text = "";
if (enemy_auto_play && enemy_ai_visual_stage == "result") button_text = "ATTACK RESOLVED";
else if (prompt_mode == "enemy_attack" && enemy_auto_play) button_text = "ENEMY TARGETING...";
else if (prompt_mode != "") button_text = "SELECT HIGHLIGHTED CARD";
else if (phase == "step1_ready") button_text = turn_number == 1 ? "START TURN" : "START NEXT TURN";
else if (phase == "build") button_text = confirming_build ? "CONFIRM BUILD" : "DONE BUILDING";
else if (phase == "attack") button_text = confirming_attack ? "CONFIRM END" : "DONE ATTACKING";
else button_text = "RESOLVING...";
draw_center(button_text, action_rect.x + action_rect.w / 2, action_rect.y + action_rect.h / 2,
    button_enabled ? COL_BG : COL_MUTED);

// The dragged card follows the pointer and is drawn above the board.
draw_hold_feedback();

if (pointer_card_down && drag_active && !is_undefined(pointer_card_value)) {
    var drag_w = pointer_card_type == "hand" ? hand_rects[0].w : build_rects[0].w;
    var drag_h = pointer_card_type == "hand" ? hand_rects[0].h : build_rects[0].h;
    var drag_x = device_mouse_x_to_gui(0) - drag_w / 2;
    var drag_y = device_mouse_y_to_gui(0) - drag_h / 2;
    draw_card(pointer_card_value, {x:drag_x, y:drag_y, w:drag_w, h:drag_h}, true, false);
}

draw_card_popup();

if (game_over) {
    draw_set_alpha(0.9);
    draw_set_color(COL_BG);
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1);
    vv_ui_set_font(UI_FONT_TITLE);
    draw_center(victory ? "VICTORY" : "DEFEAT", 640, 270, victory ? COL_ACCENT : COL_DANGER);
    vv_ui_set_font(UI_FONT_BODY);
    draw_center(victory ? "The Enemy Leader has been defeated." : "The Enemy Deck ran out before the Leader fell.",
        640, 325, COL_TEXT);
    draw_panel(result_play_rect, COL_ACCENT, COL_TEXT);
    draw_center("PLAY AGAIN", 640, result_play_rect.y + result_play_rect.h / 2, COL_BG);
    draw_panel(result_options_rect, COL_PANEL, COL_EDGE);
    draw_center("GAME OPTIONS", 640, result_options_rect.y + result_options_rect.h / 2, COL_TEXT);
    draw_panel(result_exit_rect, COL_PANEL, COL_EDGE);
    draw_center("EXIT GAME", 640, result_exit_rect.y + result_exit_rect.h / 2, COL_TEXT);
}

if (match_menu_active) {
    draw_set_alpha(0.88);
    draw_set_color(COL_BG);
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1);
    vv_ui_set_font(UI_FONT_TITLE);
    if (quit_match_confirm) {
        draw_center("QUIT THIS MATCH?", 640, 250, COL_GOLD);
        vv_ui_set_font(UI_FONT_BODY);
        draw_center("Your current match progress will be lost.", 640, 300, COL_TEXT);
        draw_panel(menu_confirm_rect, COL_DANGER, COL_TEXT);
        draw_center("QUIT TO GAME OPTIONS", 640, menu_confirm_rect.y + menu_confirm_rect.h / 2, COL_TEXT);
        draw_panel(menu_cancel_rect, COL_PANEL, COL_EDGE);
        draw_center("CONTINUE PLAYING", 640, menu_cancel_rect.y + menu_cancel_rect.h / 2, COL_TEXT);
    } else {
        draw_center("GAME MENU", 640, 225, COL_GOLD);
        vv_ui_set_font(UI_FONT_BODY);
        draw_panel(menu_resume_rect, COL_ACCENT, COL_TEXT);
        draw_center("RESUME GAME", 640, menu_resume_rect.y + menu_resume_rect.h / 2, COL_BG);
        draw_panel(menu_options_rect, COL_PANEL, COL_EDGE);
        draw_center("QUIT TO GAME OPTIONS", 640, menu_options_rect.y + menu_options_rect.h / 2, COL_TEXT);
        draw_panel(menu_exit_rect, COL_PANEL, COL_EDGE);
        draw_center("EXIT GAME", 640, menu_exit_rect.y + menu_exit_rect.h / 2, COL_TEXT);
    }
}
}
