/// UI layout, drawing, hit testing, and input routing.

function vv_ui_init() {
    COL_BG = make_color_rgb(18, 25, 36);
    COL_PANEL = make_color_rgb(31, 42, 57);
    COL_EDGE = make_color_rgb(91, 111, 139);
    COL_TEXT = make_color_rgb(239, 244, 252);
    COL_MUTED = make_color_rgb(164, 178, 198);
    COL_ACCENT = make_color_rgb(70, 190, 180);
    COL_DANGER = make_color_rgb(224, 82, 92);
    COL_GOLD = make_color_rgb(242, 190, 72);
    COL_LEGAL = make_color_rgb(114, 221, 130);

    leader_rect = {x:16, y:16, w:520, h:99};
    minion_rects = [{x:560, y:50, w:170, h:245}, {x:780, y:50, w:170, h:245}];
    build_rects = [];
    hand_rects = [];
    for (var layout_i = 0; layout_i < 3; layout_i++) {
        array_push(build_rects, {x:240 + layout_i * 245, y:305, w:240, h:200});
        array_push(hand_rects, {x:240 + layout_i * 245, y:520, w:240, h:195});
    }
    action_rect = {x:1025, y:628, w:235, h:68};
    restart_rect = {x:525, y:470, w:230, h:70};
    setup_start_rect = {x:480, y:635, w:320, h:60};
    setup_strike_page = 0;
    setup_twist_page = 0;
    setup_advanced_events = false;
    setup_event_defaults_restored = false;
    debug_event_log = false;

    pointer_card_down = false;
    pointer_card_type = "";
    pointer_card_index = -1;
    pointer_card_value = undefined;
    pointer_down_x = 0;
    pointer_down_y = 0;
    pointer_max_distance = 0;
    drag_active = false;
    drag_threshold = 8;
    tap_move_limit = 6;
    pending_tap_type = "";
    pending_tap_index = -1;
    pending_tap_value = undefined;
    pending_tap_frames = 0;
    double_tap_window = 18;
    card_popup = undefined;
    card_popup_type = "";
}

function setup_selector_button_rect(_category, _direction) {
    var panel_x = 55;
    if (_category == "scenario") panel_x = 355;
    else if (_category == "minion_set") panel_x = 655;
    return {x:panel_x, y:158, w:250, h:38};
}

function setup_gear_rect() {
    return {x:1190, y:24, w:50, h:50};
}

function setup_hero_button_rect(_slot, _direction) {
    return {x:955, y:151 + _slot * 42, w:250, h:35};
}

function setup_restore_defaults_rect() {
    return {x:930, y:66, w:230, h:44};
}

function point_in_rect(_px, _py, _rect) {
    return _px >= _rect.x && _px <= _rect.x + _rect.w
        && _py >= _rect.y && _py <= _rect.y + _rect.h;
}

function setup_event_definitions(_category) {
    return _category == "strike" ? enemy_leader.leader_strikes : enemy_scenario.twists;
}

function setup_event_selections(_category) {
    return _category == "strike" ? enemy_event_selection.leader_strikes : enemy_event_selection.twists;
}

function setup_event_category_rect(_category) {
    return _category == "strike" ? {x:50, y:310, w:560, h:280} : {x:670, y:310, w:560, h:280};
}

function setup_event_page_count(_category) {
    return max(1, ceil(array_length(setup_event_definitions(_category)) / 4));
}

function setup_event_get_page(_category) {
    var page_count = setup_event_page_count(_category);
    var page = _category == "strike" ? setup_strike_page : setup_twist_page;
    page = clamp(page, 0, page_count - 1);
    if (_category == "strike") setup_strike_page = page;
    else setup_twist_page = page;
    return page;
}

function setup_event_set_page(_category, _page) {
    var page = clamp(_page, 0, setup_event_page_count(_category) - 1);
    if (_category == "strike") setup_strike_page = page;
    else setup_twist_page = page;
}

function setup_event_page_button_rect(_category, _direction) {
    var panel = setup_event_category_rect(_category);
    return {x:panel.x + (_direction < 0 ? 448 : 504), y:319, w:44, h:34};
}

function setup_event_count_button_rect(_category, _visible_row, _direction) {
    var panel = setup_event_category_rect(_category);
    return {x:panel.x + (_direction < 0 ? 450 : 506), y:360 + _visible_row * 52, w:44, h:42};
}

function setup_event_handle_category_input(_category, _pointer_x, _pointer_y) {
    var definitions = setup_event_definitions(_category);
    var page = setup_event_get_page(_category);
    var page_count = setup_event_page_count(_category);
    if (page_count > 1) {
        if (point_in_rect(_pointer_x, _pointer_y, setup_event_page_button_rect(_category, -1))) {
            setup_event_set_page(_category, page - 1);
            return true;
        }
        if (point_in_rect(_pointer_x, _pointer_y, setup_event_page_button_rect(_category, 1))) {
            setup_event_set_page(_category, page + 1);
            return true;
        }
    }
    var first_definition = page * 4;
    var final_definition = min(array_length(definitions), first_definition + 4);
    var selections = setup_event_selections(_category);
    for (var definition_i = first_definition; definition_i < final_definition; definition_i++) {
        var visible_row = definition_i - first_definition;
        var selection_i = find_enemy_event_selection_index(selections, definitions[definition_i].card.id);
        if (selection_i >= 0) {
            if (point_in_rect(_pointer_x, _pointer_y, setup_event_count_button_rect(_category, visible_row, -1))) {
                command_adjust_enemy_event(_category, selection_i, -1);
                return true;
            }
            if (point_in_rect(_pointer_x, _pointer_y, setup_event_count_button_rect(_category, visible_row, 1))) {
                command_adjust_enemy_event(_category, selection_i, 1);
                return true;
            }
        }
    }
    return false;
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
    if (prompt_mode == "destroy_hand" && _type == "hand") return command_prompt_hand(_index);
    if (prompt_mode != "" && _type == "build") return command_prompt_build(_index);
    if (prompt_mode != "") return false;
    if (phase == "build") {
        if (_type == "hand") return command_select_hand(_index);
        if (_type == "build") return command_select_build(_index);
    }
    if (phase == "attack" && _type == "minion") return command_attack_minion(_index);
    if (phase == "attack" && _type == "leader") return command_attack_leader();
    return false;
}

function ui_finish_pending_tap() {
    if (pending_tap_type == "") return;
    var tap_type = pending_tap_type;
    var tap_index = pending_tap_index;
    pending_tap_type = "";
    pending_tap_index = -1;
    pending_tap_value = undefined;
    pending_tap_frames = 0;
    ui_run_card_tap(tap_type, tap_index);
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

    if (pending_tap_frames > 0) {
        pending_tap_frames--;
        if (pending_tap_frames <= 0 && !pointer_card_down) ui_finish_pending_tap();
    }
    if (pending_tap_type != "" && pending_tap_frames <= 0 && !pointer_card_down) ui_finish_pending_tap();

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
            drag_active = false;
            return;
        }
    }

    if (pointer_card_down) {
        if (pointer_held) {
            pointer_max_distance = max(pointer_max_distance,
                point_distance(pointer_down_x, pointer_down_y, pointer_x, pointer_y));
        }
        if (pointer_held && phase == "build" && prompt_mode == ""
        && (pointer_card_type == "hand" || pointer_card_type == "build")) {
            if (pointer_max_distance >= drag_threshold && !drag_active) {
                drag_active = true;
                // Once movement becomes a drag, it cannot complete an earlier double-tap.
                pending_tap_type = "";
                pending_tap_index = -1;
                pending_tap_frames = 0;
            }
        }
        if (pointer_released) {
            if (drag_active) {
                var drag_target = ui_drag_target_at_point(pointer_x, pointer_y);
                if (!is_undefined(drag_target)) {
                    command_drag_card(pointer_card_type, pointer_card_index, drag_target.type, drag_target.index);
                }
                pending_tap_type = "";
                pending_tap_frames = 0;
            } else {
                var released_card = ui_card_at_point(pointer_x, pointer_y);
                var same_card = !is_undefined(released_card)
                    && released_card.type == pointer_card_type && released_card.index == pointer_card_index;
                if (same_card && pointer_max_distance <= tap_move_limit) {
                    var immediate_attack = phase == "attack"
                        && (pointer_card_type == "minion" || pointer_card_type == "leader");
                    if (immediate_attack) {
                        pending_tap_type = "";
                        pending_tap_index = -1;
                        pending_tap_frames = 0;
                        ui_run_card_tap(pointer_card_type, pointer_card_index);
                    } else if (pending_tap_frames > 0 && pending_tap_type == pointer_card_type
                    && pending_tap_index == pointer_card_index) {
                        card_popup = pointer_card_value;
                        card_popup_type = pointer_card_type;
                        pending_tap_type = "";
                        pending_tap_index = -1;
                        pending_tap_value = undefined;
                        pending_tap_frames = 0;
                    } else {
                        if (pending_tap_type != "") ui_finish_pending_tap();
                        pending_tap_type = pointer_card_type;
                        pending_tap_index = pointer_card_index;
                        pending_tap_value = pointer_card_value;
                        pending_tap_frames = double_tap_window;
                    }
                }
            }
            pointer_card_down = false;
            pointer_card_type = "";
            pointer_card_index = -1;
            pointer_card_value = undefined;
            pointer_max_distance = 0;
            drag_active = false;
        }
        return;
    }

    if (!pointer_pressed) return;

    if (setup_active) {
        if (point_in_rect(pointer_x, pointer_y, setup_gear_rect())) {
            setup_advanced_events = !setup_advanced_events;
            return;
        }
        if (!content_registry_validation.valid) return;
        if (!setup_advanced_events) {
            if (point_in_rect(pointer_x, pointer_y, setup_start_rect)) command_start_game_from_setup();
            return;
        }
        if (point_in_rect(pointer_x, pointer_y, setup_selector_button_rect("leader", 1))) {
            command_select_leader(1);
            return;
        }
        if (point_in_rect(pointer_x, pointer_y, setup_selector_button_rect("scenario", 1))) {
            command_select_scenario(1);
            return;
        }
        if (point_in_rect(pointer_x, pointer_y, setup_selector_button_rect("minion_set", 1))) {
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
        if (point_in_rect(pointer_x, pointer_y, restart_rect)) command_open_setup();
        return;
    }

    // Mandatory effects take input priority and pause automatic resolution.
    if (prompt_mode != "") {
        log_add("Choose one of the highlighted cards.");
        return;
    }

    if (point_in_rect(pointer_x, pointer_y, action_rect)) {
        var player_action_phase = phase == "step1_ready" || phase == "build" || phase == "attack";
        if (player_action_phase && action_cooldown <= 0 && command_action()) action_cooldown = 24;
        return;
    }

    if (phase == "attack") {
        if (point_in_rect(pointer_x, pointer_y, leader_rect)) command_attack_leader();
    }
}

function draw_panel(_rect, _fill, _outline) {
    draw_set_color(_fill);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, false);
    draw_set_color(_outline);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, true);
}

function draw_center(_text, _x, _y, _color) {
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_color(_color);
    draw_text(_x, _y, _text);
}

function draw_art_contained(_sprite, _rect, _padding) {
    if (_sprite < 0) return;
    var source_w = sprite_get_width(_sprite);
    var source_h = sprite_get_height(_sprite);
    var scale = min((_rect.w - _padding * 2) / source_w, (_rect.h - _padding * 2) / source_h);
    var draw_w = source_w * scale;
    var draw_h = source_h * scale;
    var draw_x = _rect.x + (_rect.w - draw_w) / 2;
    var draw_y = _rect.y + (_rect.h - draw_h) / 2;
    draw_sprite_ext(_sprite, 0, draw_x, draw_y, scale, scale, 0, c_white, 1);
}

function draw_art_cover(_sprite, _rect) {
    if (_sprite < 0) return;
    var source_w = sprite_get_width(_sprite);
    var source_h = sprite_get_height(_sprite);
    var scale = max(_rect.w / source_w, _rect.h / source_h);
    var draw_x = _rect.x + (_rect.w - source_w * scale) / 2;
    var draw_y = _rect.y + (_rect.h - source_h * scale) / 2;
    draw_sprite_ext(_sprite, 0, draw_x, draw_y, scale, scale, 0, c_white, 1);
}

function card_abilities_text(_card) {
    if (!variable_struct_exists(_card, "abilities") || array_length(_card.abilities) == 0) return "No ability.";
    var result = "";
    for (var ability_i = 0; ability_i < array_length(_card.abilities); ability_i++) {
        var ability = _card.abilities[ability_i];
        if (result != "") result += "\n";
        result += ability.name + ": " + ability.text;
    }
    return result;
}

function draw_card(_card, _rect, _selected, _legal) {
    var fill = COL_PANEL;
    if (!is_undefined(_card)) {
        if (variable_struct_exists(_card, "theme_color")) fill = _card.theme_color;
        else fill = make_color_rgb(92, 47, 48);
    }
    var outline = COL_EDGE;
    if (_legal) outline = COL_LEGAL;
    if (_selected) outline = COL_GOLD;
    draw_panel(_rect, fill, outline);
    if (is_undefined(_card)) {
        draw_center("EMPTY", _rect.x + _rect.w / 2, _rect.y + _rect.h / 2, COL_MUTED);
    } else {
        var art_sprite = variable_struct_exists(_card, "art_file") ? get_art_sprite(_card.art_file) : -1;
        if (art_sprite >= 0) {
            draw_art_contained(art_sprite, _rect, 4);
        } else {
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
            draw_set_color(COL_TEXT);
            draw_text(_rect.x + 10, _rect.y + 8, _card.name);
            draw_set_color(COL_GOLD);
            draw_text(_rect.x + 10, _rect.y + 34, "ATK " + string(_card.atk));
            draw_set_color(COL_ACCENT);
            draw_text(_rect.x + _rect.w - 64, _rect.y + 34, "HP " + string(_card.hp));
            draw_set_color(COL_TEXT);
            draw_set_color(COL_MUTED);
            draw_text_ext(_rect.x + 10, _rect.y + 59, card_abilities_text(_card), 16, _rect.w - 20);
        }
    }
    draw_set_color(outline);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, true);
    if (_legal) {
        draw_set_color(COL_LEGAL);
        draw_roundrect(_rect.x + 2, _rect.y + 2, _rect.x + _rect.w - 2, _rect.y + _rect.h - 2, true);
    }
}

function draw_enemy_reveal(_card, _rect) {
    var reveal_fill = _card.card_type == "strike"
        ? make_color_rgb(105, 48, 42)
        : make_color_rgb(68, 48, 105);
    var reveal_edge = _card.card_type == "strike" ? COL_DANGER : COL_GOLD;
    draw_panel(_rect, reveal_fill, reveal_edge);
    var reveal_sprite = get_art_sprite(_card.art_file);
    if (reveal_sprite >= 0) draw_art_contained(reveal_sprite, _rect, 4);
    draw_set_color(reveal_edge);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, true);
}

function ui_drag_hides_card(_type, _index) {
    return pointer_card_down && drag_active && pointer_card_type == _type && pointer_card_index == _index;
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

function draw_setup_counter_button(_rect, _text, _enabled) {
    draw_panel(_rect, _enabled ? COL_ACCENT : COL_PANEL, _enabled ? COL_TEXT : COL_EDGE);
    draw_center(_text, _rect.x + _rect.w / 2, _rect.y + _rect.h / 2,
        _enabled ? COL_BG : COL_MUTED);
}

function draw_setup_gear(_rect, _active) {
    draw_panel(_rect, _active ? COL_ACCENT : COL_PANEL, COL_EDGE);
    var center_x = _rect.x + _rect.w / 2;
    var center_y = _rect.y + _rect.h / 2;
    var gear_color = _active ? COL_BG : COL_TEXT;
    draw_set_color(gear_color);
    draw_circle(center_x, center_y, 10, true);
    draw_circle(center_x, center_y, 4, true);
    for (var tooth_i = 0; tooth_i < 8; tooth_i++) {
        var angle = tooth_i * 45;
        draw_line_width(center_x + lengthdir_x(10, angle), center_y + lengthdir_y(10, angle),
            center_x + lengthdir_x(16, angle), center_y + lengthdir_y(16, angle), 4);
    }
}

function draw_setup_event_category(_category, _title) {
    var panel = setup_event_category_rect(_category);
    var definitions = setup_event_definitions(_category);
    var selections = setup_event_selections(_category);
    var page = setup_event_get_page(_category);
    var page_count = setup_event_page_count(_category);
    draw_panel(panel, make_color_rgb(24, 33, 46), COL_EDGE);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(COL_GOLD);
    draw_text(panel.x + 16, 324, _title);
    if (page_count > 1) {
        draw_center(string(page + 1) + " / " + string(page_count), panel.x + 418, 336, COL_MUTED);
        draw_setup_counter_button(setup_event_page_button_rect(_category, -1), "<", page > 0);
        draw_setup_counter_button(setup_event_page_button_rect(_category, 1), ">", page < page_count - 1);
    }
    if (array_length(definitions) == 0) {
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_color(COL_MUTED);
        draw_text(panel.x + 16, 375, "None available");
        return;
    }
    var first_definition = page * 4;
    var final_definition = min(array_length(definitions), first_definition + 4);
    for (var definition_i = first_definition; definition_i < final_definition; definition_i++) {
        var visible_row = definition_i - first_definition;
        var row_y = 360 + visible_row * 52;
        var definition = definitions[definition_i];
        var selection_i = find_enemy_event_selection_index(selections, definition.card.id);
        var copies = selection_i >= 0 ? selections[selection_i].copies : 0;
        draw_set_halign(fa_left);
        draw_set_valign(fa_middle);
        draw_set_color(selection_i >= 0 ? COL_TEXT : COL_DANGER);
        draw_text(panel.x + 16, row_y + 21, definition.card.name);
        draw_center(string(copies), panel.x + 424, row_y + 21, COL_TEXT);
        draw_setup_counter_button(setup_event_count_button_rect(_category, visible_row, -1), "-",
            selection_i >= 0 && copies > 0);
        draw_setup_counter_button(setup_event_count_button_rect(_category, visible_row, 1), "+",
            selection_i >= 0 && copies < definition.max_copies);
    }
}

function draw_setup_dropdown(_rect, _value) {
    draw_panel(_rect, make_color_rgb(24, 33, 46), COL_EDGE);
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_color(COL_TEXT);
    draw_text(_rect.x + 12, _rect.y + _rect.h / 2, _value);
    draw_center("v", _rect.x + _rect.w - 18, _rect.y + _rect.h / 2, COL_GOLD);
}

function setup_event_default_total(_definitions) {
    var total = 0;
    for (var definition_i = 0; definition_i < array_length(_definitions); definition_i++) {
        total += _definitions[definition_i].default_copies;
    }
    return total;
}

function vv_ui_draw_setup() {
    draw_center("VILLAINS & VELVET", 640, 40, COL_GOLD);
    draw_center(setup_advanced_events ? "BATTLE SETTINGS" : "CHOOSE YOUR BATTLE", 640, 70, COL_TEXT);
    var gear = setup_gear_rect();
    draw_setup_gear(gear, setup_advanced_events);

    if (!content_registry_validation.valid) {
        var content_error_panel = {x:290, y:190, w:700, h:230};
        draw_set_alpha(0.94);
        draw_panel(content_error_panel, COL_PANEL, COL_DANGER);
        draw_set_alpha(1);
        draw_center("CONTENT SETUP ERROR", 640, 230, COL_DANGER);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_color(COL_TEXT);
        draw_text_ext(330, 275, content_registry_validation.message, 20, 620);
        draw_center("Correct the content definition, then restart the game.", 640, 375, COL_MUTED);
        draw_panel(setup_start_rect, COL_PANEL, COL_EDGE);
        draw_center("START GAME UNAVAILABLE", setup_start_rect.x + setup_start_rect.w / 2,
            setup_start_rect.y + setup_start_rect.h / 2, COL_MUTED);
        return;
    }

    if (setup_advanced_events) {
        var setup_panels = [
            {x:35, y:120, w:280, h:175},
            {x:335, y:120, w:280, h:175},
            {x:635, y:120, w:280, h:175},
            {x:935, y:120, w:280, h:175}
        ];
        draw_set_alpha(0.92);
        for (var panel_i = 0; panel_i < 4; panel_i++) draw_panel(setup_panels[panel_i], COL_PANEL, COL_EDGE);
        draw_set_alpha(1);

        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_color(COL_GOLD);
        draw_text(55, 134, "LEADER");
        draw_text(355, 134, "SCENARIO");
        draw_text(655, 134, "MINION SET");
        draw_text(955, 134, "HERO TEAM");
        draw_setup_dropdown(setup_selector_button_rect("leader", 1), enemy_leader.name);
        draw_setup_dropdown(setup_selector_button_rect("scenario", 1), enemy_scenario.name);
        draw_setup_dropdown(setup_selector_button_rect("minion_set", 1), enemy_minion_set.name);

        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_color(COL_MUTED);
        draw_text(55, 208, "HEALTH  " + string(enemy_leader.starting_hp));
        draw_text(165, 208, "ATTACK  " + string(enemy_leader.attack));
        draw_text(55, 236, "DEFAULT STRIKES  " + string(setup_event_default_total(enemy_leader.leader_strikes)));
        draw_text(355, 208, "DEFAULT TWISTS  " + string(setup_event_default_total(enemy_scenario.twists)));
        draw_text(355, 236, "RULES  " + string(array_length(enemy_scenario.setup_rules)));
        draw_text(655, 208, "MINION CARDS  " + string(CORE_MINION_TOTAL));
        draw_text(655, 236, "NORMAL / ABILITY / SPECIAL");

        for (var setup_hero_i = 0; setup_hero_i < array_length(selected_hero_ids); setup_hero_i++) {
            var setup_hero = find_hero_definition(available_heroes, selected_hero_ids[setup_hero_i]);
            if (!is_undefined(setup_hero)) draw_setup_dropdown(setup_hero_button_rect(setup_hero_i, 1), setup_hero.name);
        }

        draw_setup_event_category("strike", "LEADER STRIKES");
        draw_setup_event_category("twist", "TWISTS");
        var restore_rect = setup_restore_defaults_rect();
        draw_panel(restore_rect, setup_event_defaults_restored ? COL_ACCENT : COL_PANEL,
            setup_event_defaults_restored ? COL_TEXT : COL_EDGE);
        var default_strikes = setup_event_default_total(enemy_leader.leader_strikes);
        var default_twists = setup_event_default_total(enemy_scenario.twists);
        draw_center(setup_event_defaults_restored ? "DEFAULT MIX RESTORED" : "RESTORE DEFAULT MIX",
            restore_rect.x + restore_rect.w / 2, restore_rect.y + 14,
            setup_event_defaults_restored ? COL_BG : COL_TEXT);
        draw_center(string(default_strikes) + " STRIKES  /  " + string(default_twists) + " TWISTS",
            restore_rect.x + restore_rect.w / 2, restore_rect.y + 31,
            setup_event_defaults_restored ? COL_BG : COL_MUTED);
    } else {
        draw_center(enemy_leader.name + "   |   " + enemy_scenario.name + "   |   " + enemy_minion_set.name,
            640, 126, COL_TEXT);
        var hero_summary = "";
        for (var summary_i = 0; summary_i < array_length(selected_hero_ids); summary_i++) {
            var summary_hero = find_hero_definition(available_heroes, selected_hero_ids[summary_i]);
            if (!is_undefined(summary_hero)) {
                if (hero_summary != "") hero_summary += "   |   ";
                hero_summary += summary_hero.name;
            }
        }
        draw_center(hero_summary, 640, 158, COL_MUTED);
        draw_center("Use the gear to change the battle.", 640, 194, COL_MUTED);
        if (!enemy_event_validation.valid) draw_center("Enemy Events must total 8.", 640, 535, COL_DANGER);
    }

    draw_set_color(setup_validation.valid ? COL_LEGAL : COL_DANGER);
    var setup_status = "READY";
    if (enemy_event_validation.total > CORE_ENEMY_EVENT_SLOTS) {
        setup_status = "REMOVE " + string(enemy_event_validation.total - CORE_ENEMY_EVENT_SLOTS);
    } else if (enemy_event_validation.total < CORE_ENEMY_EVENT_SLOTS) {
        setup_status = "ADD " + string(CORE_ENEMY_EVENT_SLOTS - enemy_event_validation.total);
    } else if (!setup_validation.valid) {
        setup_status = "CHECK SELECTION";
    }
    draw_center("ENEMY EVENTS  " + string(enemy_event_validation.total)
        + " / " + string(CORE_ENEMY_EVENT_SLOTS) + "    " + setup_status,
        640, 612, setup_validation.valid ? COL_LEGAL : COL_DANGER);

    draw_panel(setup_start_rect, setup_validation.valid ? COL_ACCENT : COL_PANEL,
        setup_validation.valid ? COL_TEXT : COL_EDGE);
    draw_center("START GAME", setup_start_rect.x + setup_start_rect.w / 2,
        setup_start_rect.y + setup_start_rect.h / 2,
        setup_validation.valid ? COL_BG : COL_MUTED);
}

function vv_ui_draw_game() {
draw_clear(COL_BG);
// Battlefield artwork with a dark veil keeps the cards and instructions readable.
var background_rect = {x:0, y:0, w:1280, h:720};
draw_art_cover(background_art_sprite, background_rect);
draw_set_alpha(setup_active ? 0.30 : 0.62);
draw_set_color(COL_BG);
draw_rectangle(0, 0, 1280, 720, false);
draw_set_alpha(1);

if (setup_active) {
    vv_ui_draw_setup();
    return;
}

// Leader and Minions.
draw_panel(leader_rect, make_color_rgb(72, 37, 48), leader_is_protected() ? COL_GOLD : COL_DANGER);
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
draw_set_color(leader_is_protected() ? COL_GOLD : COL_DANGER);
draw_roundrect(leader_rect.x, leader_rect.y, leader_rect.x + leader_rect.w, leader_rect.y + leader_rect.h, true);

draw_center("AREA 2", 645, 17, COL_GOLD);
draw_center("ESCAPES WHEN PUSHED", 645, 36, COL_MUTED);
if (!is_undefined(revealed_enemy_card)) {
    draw_center(revealed_enemy_card.card_type == "strike" ? "LEADER STRIKE" : "TWIST", 865, 17, COL_GOLD);
    draw_center(revealed_enemy_card.name, 865, 36, COL_TEXT);
} else {
    draw_center("AREA 1", 865, 17, COL_GOLD);
    draw_center("MINIONS ENTER HERE", 865, 36, COL_MUTED);
}
draw_card(minions[0], minion_rects[0], false, false);
if (!is_undefined(revealed_enemy_card)) draw_enemy_reveal(revealed_enemy_card, minion_rects[1]);
else draw_card(minions[1], minion_rects[1], false, false);
draw_center("←", 755, 186, COL_ACCENT);

// Build and Hand.
draw_center("BUILD AREA", 640, 297, COL_MUTED);
for (var build_i = 0; build_i < 3; build_i++) {
    var legal_build = (prompt_mode != "" && prompt_build_is_legal(build_i))
        || (phase == "build" && prompt_mode == "" && selected_hand >= 0)
        || ui_drag_target_is_legal("build", build_i);
    var visible_build_card = ui_drag_hides_card("build", build_i) ? undefined : build[build_i];
    draw_card(visible_build_card, build_rects[build_i], selected_build == build_i, legal_build);
}

draw_center("HAND", 640, 512, COL_MUTED);
for (var hand_i = 0; hand_i < 3; hand_i++) {
    var hand_card = hand_i < array_length(hand) ? hand[hand_i] : undefined;
    var legal_hand = prompt_mode == "destroy_hand" && hand_i < array_length(hand)
        && !is_undefined(hand_card);
    legal_hand = legal_hand || ui_drag_target_is_legal("hand", hand_i);
    if (ui_drag_hides_card("hand", hand_i)) hand_card = undefined;
    draw_card(hand_card, hand_rects[hand_i], selected_hand == hand_i, legal_hand);
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
if (prompt_mode == "" && enemy_attack_notice != "") instruction = enemy_attack_notice;
else if (prompt_mode == "enemy_attack") instruction = "Choose a highlighted Build card.";
else if (prompt_mode == "disrupt") instruction = "Choose a highlighted Build card.";
else if (prompt_mode == "shatter") instruction = "Choose a highlighted card with the lowest HP.";
else if (prompt_mode == "destroy_hand") instruction = prompt_source + "\nChoose a highlighted Hand card.\n"
    + string(escape_cards_remaining) + " remaining.";
else if (phase == "step1_ready") instruction = turn_number == 1
    ? "Tap START TURN to draw three cards."
    : "Tap START NEXT TURN to draw three cards.";
else if (phase == "step2_ready") instruction = "Minions advance and escape.";
else if (phase == "step3_ready" || phase == "enemy_continue_wait") instruction = "Enemy cards are being drawn.";
else if (phase == "step4_ready") instruction = "Build phase is opening.";
else if (phase == "start_resolving") instruction = step_number == 2
    ? "Resolving Minion movement and escapes..."
    : "Resolving the Enemy Draw...";
else if (phase == "build") {
    if (selected_hand >= 0) instruction = "Hand card selected. Tap a Build space to place or swap it.";
    else if (selected_build >= 0) instruction = "Build card selected. Tap a Hand card to swap it.";
    else instruction = "Place or swap cards in the Build Area.\nTap DONE BUILDING when finished.";
} else if (phase == "attack") instruction = "Attack " + string(attack_left)
    + ": tap a Minion or the Leader.\nToo little Attack is not spent.\nTap DONE ATTACKING when finished.";
else if (phase == "step5_ready") instruction = "Calculating your Attack...";
else if (phase == "step6_ready") instruction = "Discarding the cards left in your Hand...";
else if (phase == "end_ready") instruction = "Ending your turn...";
if (prompt_mode == "enemy_attack") {
    instruction = prompt_source + "\nAttack: " + string(prompt_value) + "\n"
        + (build_has_priority() ? "Choose a highlighted Guard or Fortress." : "Choose a card this Attack can defeat.");
}
var context_panel = {x:985, y:16, w:280, h:190};
draw_panel(context_panel, make_color_rgb(24, 33, 46), COL_EDGE);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(COL_MUTED);
draw_text(1000, 29, "TURN STEPS");
var step_list = [
    "STEP 1: DRAW CARDS",
    "STEP 2: ADVANCE / ESCAPE",
    "STEP 3: ENEMY DRAW",
    "STEP 4: BUILD",
    "STEP 5: PLAYER ATTACK",
    "STEP 6: DISCARD",
    "STEP 7: END TURN"
];
for (var step_i = 0; step_i < 7; step_i++) {
    draw_set_color(step_i + 1 == step_number ? COL_GOLD : COL_MUTED);
    draw_text(1000, 53 + step_i * 19, step_list[step_i]);
}

// Short current instruction remains separate from the permanent step list.
draw_set_color(prompt_mode == "enemy_attack" ? COL_DANGER : COL_TEXT);
draw_text_ext(1000, 225, instruction, 18, 250);

// A selected card gets a readable description without covering the board.
var detail_card = undefined;
if (selected_hand >= 0 && selected_hand < array_length(hand)) detail_card = hand[selected_hand];
else if (selected_build >= 0 && selected_build < 3) detail_card = build[selected_build];
else if (!is_undefined(revealed_enemy_card)) detail_card = revealed_enemy_card;
else if (!is_undefined(minions[1])) detail_card = minions[1];
else if (!is_undefined(minions[0])) detail_card = minions[0];

if (!is_undefined(detail_card)) {
    var detail_panel = {x:985, y:325, w:280, h:170};
    draw_panel(detail_panel, make_color_rgb(24, 33, 46), COL_EDGE);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(COL_MUTED);
    draw_text(1000, 337, "CARD DETAILS");
    draw_set_color(COL_TEXT);
    draw_text(1000, 361, string_upper(detail_card.name));
    if (variable_struct_exists(detail_card, "atk")) {
        draw_set_color(COL_GOLD);
        draw_text(1000, 385, "ATK " + string(detail_card.atk));
        draw_set_color(COL_ACCENT);
        draw_text(1090, 385, "HP " + string(detail_card.hp));
    }
    var detail_y = variable_struct_exists(detail_card, "atk") ? 410 : 385;
    draw_set_color(COL_TEXT);
    var detail_text = variable_struct_exists(detail_card, "abilities")
        ? card_abilities_text(detail_card)
        : (detail_card.effect != "" ? detail_card.effect : "No ability.");
    draw_text_ext(1000, detail_y, detail_text, 15, 250);
}

// Main action.
var match_panel = {x:1025, y:515, w:235, h:96};
draw_panel(match_panel, make_color_rgb(24, 33, 46), COL_EDGE);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(COL_GOLD);
draw_text(1038, 526, "TURN " + string(turn_number));
draw_set_color(COL_MUTED);
draw_text(1038, 548, "PLAYER DECK: " + string(array_length(player_deck)));
draw_text(1038, 570, "DISCARD: " + string(array_length(player_discard)));
draw_text(1038, 590, "ENEMY DECK: " + string(array_length(enemy_deck)));

var button_enabled = prompt_mode == "" && action_cooldown <= 0
    && (phase == "step1_ready" || phase == "build" || phase == "attack");
draw_panel(action_rect, button_enabled ? COL_ACCENT : COL_PANEL, button_enabled ? COL_TEXT : COL_EDGE);
var button_text = "";
if (prompt_mode != "") button_text = "SELECT HIGHLIGHTED CARD";
else if (phase == "step1_ready") button_text = turn_number == 1 ? "START TURN" : "START NEXT TURN";
else if (phase == "build") button_text = "DONE BUILDING";
else if (phase == "attack") button_text = "DONE ATTACKING";
else button_text = "RESOLVING...";
draw_center(button_text, action_rect.x + action_rect.w / 2, action_rect.y + action_rect.h / 2,
    button_enabled ? COL_BG : COL_MUTED);

// The dragged card follows the pointer and is drawn above the board.
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
    draw_center(victory ? "VICTORY" : "DEFEAT", 640, 305, victory ? COL_ACCENT : COL_DANGER);
    draw_center(victory ? "The Enemy Leader has been defeated." : "The Enemy Deck ran out before the Leader fell.",
        640, 365, COL_TEXT);
    draw_panel(restart_rect, COL_GOLD, COL_TEXT);
    draw_center("PLAY AGAIN", 640, 505, COL_BG);
}
}
