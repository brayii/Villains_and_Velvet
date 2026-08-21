/// UI layout, drawing, hit testing, and input routing.

function vv_ui_init() {
    COL_BG = make_color_rgb(15, 22, 33);
    COL_PANEL = make_color_rgb(29, 40, 56);
    COL_EDGE = make_color_rgb(112, 132, 159);
    COL_TEXT = make_color_rgb(247, 244, 238);
    COL_MUTED = make_color_rgb(178, 190, 207);
    COL_ACCENT = make_color_rgb(73, 194, 184);
    COL_DANGER = make_color_rgb(228, 88, 99);
    COL_GOLD = make_color_rgb(246, 191, 66);
    COL_LEGAL = make_color_rgb(124, 224, 142);

    var ui_font_file = working_directory + "atkinson_hyperlegible_next_medium.ttf";
    UI_FONT_SMALL = -1;
    UI_FONT_BODY = -1;
    UI_FONT_TITLE = -1;
    if (file_exists(ui_font_file)) {
        UI_FONT_SMALL = font_add(ui_font_file, 13, false, false, 32, 255);
        UI_FONT_BODY = font_add(ui_font_file, 15, false, false, 32, 255);
        UI_FONT_TITLE = font_add(ui_font_file, 20, false, false, 32, 255);
    }

    leader_rect = {x:16, y:16, w:520, h:99};
    minion_rects = [{x:560, y:50, w:170, h:245}, {x:780, y:50, w:170, h:245}];
    build_rects = [];
    hand_rects = [];
    for (var layout_i = 0; layout_i < 3; layout_i++) {
        array_push(build_rects, {x:240 + layout_i * 245, y:305, w:240, h:200});
        array_push(hand_rects, {x:240 + layout_i * 245, y:520, w:240, h:195});
    }
    action_rect = {x:1025, y:628, w:235, h:68};
    setup_start_rect = {x:480, y:635, w:320, h:60};
    setup_exit_rect = {x:1080, y:650, w:160, h:46};
    match_menu_rect = {x:20, y:130, w:46, h:46};
    auto_toggle_rect = {x:76, y:130, w:46, h:46};
    menu_resume_rect = {x:490, y:280, w:300, h:58};
    menu_sound_rect = {x:490, y:352, w:300, h:58};
    menu_options_rect = {x:490, y:424, w:300, h:58};
    menu_exit_rect = {x:490, y:496, w:300, h:58};
    menu_confirm_rect = {x:490, y:344, w:300, h:58};
    menu_cancel_rect = {x:490, y:416, w:300, h:58};
    result_play_rect = {x:490, y:400, w:300, h:54};
    result_options_rect = {x:490, y:466, w:300, h:54};
    result_exit_rect = {x:490, y:532, w:300, h:54};
    tutorial_real_match_rect = {x:470, y:530, w:340, h:62};
    tutorial_continue_rect = {x:1000, y:612, w:250, h:62};
    setup_strike_page = 0;
    setup_twist_page = 0;
    setup_advanced_events = false;
    setup_event_defaults_restored = false;
    debug_event_log = false;
    vv_tutorial_init();
    escape_card_surface = -1;

    drag_threshold = 8;
    tap_move_limit = 6;
    inspect_hold_frames = 30;
    vv_feedback_audio_init();
    vv_ui_reset_match_interaction();
}

function vv_ui_cleanup() {
    var ui_fonts = [UI_FONT_SMALL, UI_FONT_BODY, UI_FONT_TITLE];
    for (var font_i = 0; font_i < array_length(ui_fonts); font_i++) {
        if (ui_fonts[font_i] >= 0 && font_exists(ui_fonts[font_i])) font_delete(ui_fonts[font_i]);
    }
    UI_FONT_SMALL = -1;
    UI_FONT_BODY = -1;
    UI_FONT_TITLE = -1;
    if (surface_exists(escape_card_surface)) surface_free(escape_card_surface);
    escape_card_surface = -1;
    vv_feedback_audio_cleanup();
}

function vv_ui_set_font(_font) {
    draw_set_font(_font >= 0 && font_exists(_font) ? _font : -1);
}

function vv_ui_reset_match_interaction() {
    enemy_ai_cancel_pending_targeting();
    pointer_card_down = false;
    pointer_card_type = "";
    pointer_card_index = -1;
    pointer_card_value = undefined;
    pointer_down_x = 0;
    pointer_down_y = 0;
    pointer_max_distance = 0;
    pointer_hold_frames = 0;
    drag_active = false;
    card_popup = undefined;
    card_popup_type = "";
    detail_card_selected = undefined;
    interaction_feedback_rect = undefined;
    interaction_feedback_kind = "";
    interaction_feedback_timer = 0;
    action_press_timer = 0;
    build_changed = false;
    build_finish_confirm = false;
    attack_finish_confirm = false;
    attack_notice_heading = "";
    attack_notice_text = "";
    match_menu_active = false;
    quit_match_confirm = false;
    feedback_ready = false;
    feedback_fx = [];
    feedback_phase_timer = 0;
    feedback_phase_text = "";
    battle_music_started = false;
}

function vv_feedback_audio_init() {
    feedback_sound_pickup = snd_card_pickup;
    feedback_sound_drop = snd_card_drop;
    feedback_sound_button = snd_button_confirm;
    feedback_sound_hit = snd_attack_hit;
    feedback_sound_move = snd_minion_move;
    feedback_sound_event = snd_event_reveal;
    feedback_sound_leader_damage = snd_leader_damage;
    feedback_sound_destroy = snd_destruction;
    feedback_sound_heal = snd_healing;
    feedback_sound_victory = snd_victory;
    feedback_sound_defeat = snd_defeat;
    feedback_music = mus_storybook_loop;
    feedback_battle_music = mus_battle_loop;
    feedback_music_instance = -1;
    feedback_battle_music_instance = -1;
    feedback_music_mode = "setup";
    if (feedback_music >= 0) {
        feedback_music_instance = audio_play_sound(feedback_music, -10, true);
        // Settings apply the audible gain immediately after audio initialization.
        audio_sound_gain(feedback_music_instance, 0, 0);
    }
    if (feedback_battle_music >= 0) {
        feedback_battle_music_instance = audio_play_sound(feedback_battle_music, -10, true);
        audio_sound_gain(feedback_battle_music_instance, 0, 0);
    }
}

function vv_feedback_audio_cleanup() {
    if (feedback_music_instance >= 0) audio_stop_sound(feedback_music_instance);
    if (feedback_battle_music_instance >= 0) audio_stop_sound(feedback_battle_music_instance);
    feedback_music_instance = -1;
    feedback_battle_music_instance = -1;
}

function vv_feedback_play(_sound) {
    if (audio_enabled && _sound >= 0) audio_play_sound(_sound, 0, false);
}

function vv_feedback_apply_audio_enabled() {
    if (!variable_instance_exists(id, "feedback_music_instance")) return;
    var setup_gain = audio_enabled && feedback_music_mode == "setup" ? 0.38 : 0;
    var battle_gain = audio_enabled && feedback_music_mode == "battle" ? 0.34 : 0;
    if (feedback_music_instance >= 0) {
        audio_sound_gain(feedback_music_instance, setup_gain, 180);
    }
    if (feedback_battle_music_instance >= 0) {
        audio_sound_gain(feedback_battle_music_instance, battle_gain, 180);
    }
}

function vv_feedback_update_music_context() {
    if (!setup_active && !battle_music_started && phase != "step1_ready") {
        battle_music_started = true;
    }
    var next_mode = setup_active ? "setup" : (battle_music_started ? "battle" : "silent");
    if (feedback_music_mode == next_mode) return;
    feedback_music_mode = next_mode;
    vv_feedback_apply_audio_enabled();
}

function vv_feedback_card_present(_card) {
    if (is_undefined(_card)) return false;
    for (var present_i = 0; present_i < 3; present_i++) {
        if (build[present_i] == _card) return true;
        if (present_i < array_length(hand) && hand[present_i] == _card) return true;
    }
    return minions[0] == _card || minions[1] == _card;
}

function vv_feedback_add_card_fx(_card, _rect, _kind) {
    if (is_undefined(_card)) return;
    array_push(feedback_fx, {card:_card, rect:_rect, kind:_kind, timer:18, duration:18});
}

function vv_feedback_add_escape_fx(_card) {
    if (is_undefined(_card)) return;
    var escape_heal = 0;
    if (variable_struct_exists(_card, "escape_effects")) {
        for (var effect_i = 0; effect_i < array_length(_card.escape_effects); effect_i++) {
            var escape_effect = _card.escape_effects[effect_i];
            if (escape_effect.id == EFFECT_HEAL_LEADER) escape_heal = escape_effect.params.amount;
        }
    }
    array_push(feedback_fx, {card:_card, rect:minion_rects[0], kind:"escape",
        timer:90, duration:90, escape_heal:escape_heal});
    vv_feedback_play(feedback_sound_move);
}

function vv_feedback_has_card_fx(_card, _kind) {
    for (var fx_i = 0; fx_i < array_length(feedback_fx); fx_i++) {
        if (feedback_fx[fx_i].card == _card && feedback_fx[fx_i].kind == _kind) return true;
    }
    return false;
}

function vv_feedback_has_fx_kind(_kind) {
    for (var fx_i = 0; fx_i < array_length(feedback_fx); fx_i++) {
        if (feedback_fx[fx_i].kind == _kind) return true;
    }
    return false;
}

function vv_feedback_snapshot() {
    feedback_minions = [minions[0], minions[1]];
    feedback_build = [build[0], build[1], build[2]];
    feedback_hand = [hand[0], hand[1], hand[2]];
    feedback_leader_hp = leader_hp;
    feedback_revealed_card = revealed_enemy_card;
    feedback_step = step_number;
    feedback_game_over = game_over;
}

function vv_feedback_update() {
    vv_feedback_update_music_context();
    if (setup_active) {
        feedback_ready = false;
        return;
    }
    if (!feedback_ready) {
        vv_feedback_snapshot();
        feedback_ready = true;
        return;
    }

    if (feedback_step != step_number) {
        feedback_phase_text = "STEP " + string(step_number) + "  ·  " + vv_step_name(step_number);
        feedback_phase_timer = 28;
        vv_feedback_play(feedback_sound_button);
    }
    if (feedback_minions[1] == minions[0] && !is_undefined(minions[0])) {
        var move_duration = tutorial_mode ? 60 : 22;
        array_push(feedback_fx, {card:minions[0], rect:minion_rects[1], end_rect:minion_rects[0],
            kind:"move", timer:move_duration, duration:move_duration});
        vv_feedback_play(feedback_sound_move);
    }
    if (is_undefined(feedback_revealed_card) && !is_undefined(revealed_enemy_card)) {
        array_push(feedback_fx, {card:revealed_enemy_card, rect:minion_rects[1], kind:"reveal",
            timer:20, duration:20});
        vv_feedback_play(feedback_sound_event);
    }
    if (!is_undefined(feedback_revealed_card) && is_undefined(revealed_enemy_card)) {
        vv_settings_mark_hint("enemy_event");
    }
    if (build_changed) vv_settings_mark_hint("build");
    if (feedback_leader_hp != leader_hp) {
        var hp_change = leader_hp - feedback_leader_hp;
        array_push(feedback_fx, {card:undefined, rect:leader_rect, kind:hp_change > 0 ? "heal" : "damage",
            amount:abs(hp_change), timer:24, duration:24});
        vv_feedback_play(hp_change > 0 ? feedback_sound_heal : feedback_sound_leader_damage);
    }
    for (var old_build_i = 0; old_build_i < 3; old_build_i++) {
        if (!is_undefined(feedback_build[old_build_i]) && !vv_feedback_card_present(feedback_build[old_build_i])) {
            vv_feedback_add_card_fx(feedback_build[old_build_i], build_rects[old_build_i], "destroy");
            vv_feedback_play(feedback_sound_destroy);
        }
    }
    for (var old_minion_i = 0; old_minion_i < 2; old_minion_i++) {
        if (!is_undefined(feedback_minions[old_minion_i]) && !vv_feedback_card_present(feedback_minions[old_minion_i])) {
            if (!vv_feedback_has_card_fx(feedback_minions[old_minion_i], "escape")) {
                vv_feedback_add_card_fx(feedback_minions[old_minion_i], minion_rects[old_minion_i], "destroy");
                vv_feedback_play(feedback_sound_hit);
            }
        }
    }
    if (!feedback_game_over && game_over) vv_feedback_play(victory
        ? feedback_sound_victory : feedback_sound_defeat);

    for (var fx_i = array_length(feedback_fx) - 1; fx_i >= 0; fx_i--) {
        feedback_fx[fx_i].timer--;
        if (feedback_fx[fx_i].timer <= 0) array_delete(feedback_fx, fx_i, 1);
    }
    if (feedback_phase_timer > 0) feedback_phase_timer--;
    vv_feedback_snapshot();
}

function vv_feedback_draw() {
    for (var fx_i = 0; fx_i < array_length(feedback_fx); fx_i++) {
        var fx = feedback_fx[fx_i];
        var progress = 1 - fx.timer / fx.duration;
        if (fx.kind == "move") {
            var move_rect = {x:lerp(fx.rect.x, fx.end_rect.x, progress),
                y:lerp(fx.rect.y, fx.end_rect.y, progress), w:fx.rect.w, h:fx.rect.h};
            draw_card(fx.card, move_rect, true, false);
        } else if (fx.kind == "escape") {
            if (!surface_exists(escape_card_surface)) {
                escape_card_surface = surface_create(round(fx.rect.w), round(fx.rect.h));
            }
            if (surface_exists(escape_card_surface)) {
                surface_set_target(escape_card_surface);
                draw_clear_alpha(c_black, 0);
                draw_card(fx.card, {x:0, y:0, w:fx.rect.w, h:fx.rect.h}, false, false);
                surface_reset_target();
                var portal = {x:430, y:145, w:105, h:150};
                var center_x = lerp(fx.rect.x + fx.rect.w / 2, portal.x + portal.w / 2, progress);
                var center_y = lerp(fx.rect.y + fx.rect.h / 2, portal.y + portal.h / 2, progress);
                var escape_scale = max(0.03, 1 - progress * 0.96);
                var escape_angle = progress * 540;
                var angle_cos = dcos(escape_angle);
                var angle_sin = dsin(escape_angle);
                var offset_x = -fx.rect.w * escape_scale / 2;
                var offset_y = -fx.rect.h * escape_scale / 2;
                var draw_x = center_x + offset_x * angle_cos - offset_y * angle_sin;
                var draw_y = center_y + offset_x * angle_sin + offset_y * angle_cos;
                draw_set_alpha(max(0.15, 1 - progress * 0.85));
                draw_surface_ext(escape_card_surface, draw_x, draw_y,
                    escape_scale, escape_scale, escape_angle, c_white, 1);
                draw_set_alpha(1);
                if (progress > 0.42) {
                    vv_ui_set_font(UI_FONT_SMALL);
                    draw_center_shadow("ESCAPED", portal.x + portal.w / 2,
                        portal.y + portal.h - 31, COL_GOLD);
                    if (fx.escape_heal > 0) {
                        draw_center_shadow("LEADER +" + string(fx.escape_heal) + " HP",
                            portal.x + portal.w / 2, portal.y + portal.h - 14, COL_LEGAL);
                    }
                    vv_ui_set_font(UI_FONT_BODY);
                }
            }
        } else if (fx.kind == "reveal") {
            var reveal_scale = 0.82 + 0.18 * min(1, progress * 1.6);
            var reveal_rect = {x:fx.rect.x + fx.rect.w * (1 - reveal_scale) / 2,
                y:fx.rect.y + fx.rect.h * (1 - reveal_scale) / 2,
                w:fx.rect.w * reveal_scale, h:fx.rect.h * reveal_scale};
            draw_set_alpha(min(1, progress * 2));
            draw_enemy_reveal(fx.card, reveal_rect);
            draw_set_alpha(1);
        } else if (fx.kind == "destroy") {
            draw_set_alpha(max(0, 1 - progress));
            draw_card(fx.card, fx.rect, false, false);
            draw_set_alpha(1);
        } else {
            var effect_color = fx.kind == "heal" ? COL_LEGAL : COL_DANGER;
            draw_set_alpha(max(0, 1 - progress));
            draw_set_color(effect_color);
            draw_rectangle(fx.rect.x, fx.rect.y, fx.rect.x + fx.rect.w, fx.rect.y + fx.rect.h, true);
            vv_ui_set_font(UI_FONT_TITLE);
            draw_center((fx.kind == "heal" ? "+" : "−") + string(fx.amount),
                fx.rect.x + fx.rect.w / 2, fx.rect.y + fx.rect.h / 2 - progress * 18, effect_color);
            draw_set_alpha(1);
            vv_ui_set_font(UI_FONT_BODY);
        }
    }
    if (feedback_phase_timer > 0) {
        var phase_alpha = min(1, feedback_phase_timer / 8);
        draw_set_alpha(phase_alpha);
        draw_glass_panel({x:1030, y:252, w:225, h:34}, COL_PANEL, COL_GOLD, 0.84);
        vv_ui_set_font(UI_FONT_SMALL);
        draw_center(feedback_phase_text, 1142, 269, COL_GOLD);
        draw_set_alpha(1);
        vv_ui_set_font(UI_FONT_BODY);
    }
}

function vv_feedback_hides_minion(_index) {
    for (var hide_i = 0; hide_i < array_length(feedback_fx); hide_i++) {
        var hide_fx = feedback_fx[hide_i];
        if (_index == 0 && hide_fx.kind == "move") return true;
        if (_index == 1 && hide_fx.kind == "reveal") return true;
    }
    return false;
}

function vv_step_name(_step) {
    var names = ["", "DRAW", "ADVANCE / ESCAPE", "ENEMY DRAW / ATTACK", "BUILD",
        "PLAYER ATTACK", "DISCARD", "END TURN"];
    return names[clamp(_step, 1, 7)];
}

function point_in_rect(_px, _py, _rect) {
    return _px >= _rect.x && _px <= _rect.x + _rect.w
        && _py >= _rect.y && _py <= _rect.y + _rect.h;
}

function draw_panel(_rect, _fill, _outline) {
    draw_set_color(_fill);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, false);
    draw_set_color(_outline);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, true);
}

function draw_glass_panel(_rect, _fill, _outline, _alpha) {
    draw_set_alpha(_alpha);
    draw_set_color(_fill);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, false);
    draw_set_alpha(1);
    draw_set_color(_outline);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, true);
}

function draw_center(_text, _x, _y, _color) {
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_color(_color);
    draw_text(_x, _y, _text);
}

function draw_center_shadow(_text, _x, _y, _color) {
    draw_set_alpha(0.78);
    draw_center(_text, _x + 1, _y + 2, COL_BG);
    draw_set_alpha(1);
    draw_center(_text, _x, _y, _color);
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
    // The castle and its flags are the background's focal point. Crop excess
    // ground at the bottom instead of cutting artwork from the top.
    var draw_y = _rect.y;
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
    var card_rect = _selected && !is_undefined(_card)
        ? {x:_rect.x, y:_rect.y - 4, w:_rect.w, h:_rect.h}
        : _rect;
    var fill = COL_PANEL;
    if (!is_undefined(_card)) {
        if (variable_struct_exists(_card, "theme_color")) fill = _card.theme_color;
        else fill = make_color_rgb(92, 47, 48);
    }
    var outline = COL_EDGE;
    if (_legal) outline = COL_LEGAL;
    if (_selected) outline = COL_GOLD;
    if (is_undefined(_card)) {
        draw_set_alpha(_legal ? 0.26 : 0.12);
        draw_set_color(fill);
        draw_roundrect(card_rect.x, card_rect.y, card_rect.x + card_rect.w, card_rect.y + card_rect.h, false);
        draw_set_alpha(1);
    } else {
        draw_set_alpha(_selected ? 0.34 : 0.22);
        draw_set_color(COL_BG);
        draw_roundrect(card_rect.x + 5, card_rect.y + 7,
            card_rect.x + card_rect.w + 5, card_rect.y + card_rect.h + 7, false);
        draw_set_alpha(1);
        draw_panel(card_rect, fill, outline);
    }
    if (!is_undefined(_card)) {
        var art_sprite = variable_struct_exists(_card, "art_file") ? get_art_sprite(_card.art_file) : -1;
        if (art_sprite >= 0) {
            draw_art_contained(art_sprite, card_rect, 4);
        } else {
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
            draw_set_color(COL_TEXT);
            draw_text(card_rect.x + 10, card_rect.y + 8, _card.name);
            draw_set_color(COL_GOLD);
            draw_text(card_rect.x + 10, card_rect.y + 34, "ATK " + string(_card.atk));
            draw_set_color(COL_ACCENT);
            draw_text(card_rect.x + card_rect.w - 64, card_rect.y + 34, "HP " + string(_card.hp));
            draw_set_color(COL_TEXT);
            draw_set_color(COL_MUTED);
            draw_text_ext(card_rect.x + 10, card_rect.y + 59, card_abilities_text(_card), 16, card_rect.w - 20);
        }
    }
    if (is_undefined(_card) && !_legal) draw_set_alpha(0.48);
    draw_set_color(outline);
    draw_roundrect(card_rect.x, card_rect.y, card_rect.x + card_rect.w, card_rect.y + card_rect.h, true);
    draw_set_alpha(1);
    if (_legal) {
        var legal_pulse = 0.58 + 0.42 * abs(sin(current_time / 220));
        draw_set_alpha(legal_pulse);
        draw_set_color(COL_LEGAL);
        draw_roundrect(card_rect.x + 2, card_rect.y + 2,
            card_rect.x + card_rect.w - 2, card_rect.y + card_rect.h - 2, true);
        draw_set_alpha(1);
        // A label keeps target legality understandable without relying on green alone.
        vv_ui_set_font(UI_FONT_SMALL);
        draw_set_alpha(0.88);
        draw_set_color(COL_BG);
        draw_rectangle(card_rect.x + 6, card_rect.y + 6,
            card_rect.x + 72, card_rect.y + 28, false);
        draw_center("TARGET", card_rect.x + 39, card_rect.y + 17, COL_TEXT);
        draw_set_alpha(1);
        vv_ui_set_font(UI_FONT_BODY);
    } else if (_selected && !is_undefined(_card)) {
        vv_ui_set_font(UI_FONT_SMALL);
        draw_set_alpha(0.88);
        draw_set_color(COL_BG);
        draw_rectangle(card_rect.x + 6, card_rect.y + 6,
            card_rect.x + 84, card_rect.y + 28, false);
        draw_center("SELECTED", card_rect.x + 45, card_rect.y + 17, COL_TEXT);
        draw_set_alpha(1);
        vv_ui_set_font(UI_FONT_BODY);
    }
}

function draw_enemy_reveal(_card, _rect) {
    var reveal_fill = _card.card_type == "strike"
        ? make_color_rgb(105, 48, 42)
        : make_color_rgb(68, 48, 105);
    var reveal_edge = _card.card_type == "strike" ? COL_DANGER : COL_GOLD;
    draw_panel(_rect, reveal_fill, reveal_edge);
    var reveal_sprite = get_art_sprite(_card.art_file);
    if (reveal_sprite >= 0) {
        draw_art_contained(reveal_sprite, _rect, 4);
    } else {
        draw_center(_card.card_type == "strike" ? "LEADER STRIKE" : "TWIST",
            _rect.x + _rect.w / 2, _rect.y + 28, reveal_edge);
        draw_center(string_upper(_card.name), _rect.x + _rect.w / 2,
            _rect.y + 68, COL_TEXT);
        draw_set_halign(fa_center);
        draw_set_valign(fa_top);
        draw_set_color(COL_TEXT);
        draw_text_ext(_rect.x + _rect.w / 2, _rect.y + 108,
            _card.effect, 18, _rect.w - 28);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    }
    draw_set_color(reveal_edge);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, true);
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
