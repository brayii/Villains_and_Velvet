function setup_selector_button_rect(_category) {
    var panel_x = 55;
    if (_category == "scenario") panel_x = 355;
    else if (_category == "minion_set") panel_x = 655;
    return {x:panel_x, y:156, w:250, h:44};
}

function setup_battle_settings_rect() {
    return {x:1040, y:24, w:200, h:46};
}

function setup_sound_button_rect() {
    return {x:900, y:24, w:130, h:46};
}

function setup_hero_button_rect(_slot, _direction) {
    return {x:982, y:145 + _slot * 42, w:223, h:40};
}

function setup_restore_defaults_rect() {
    return {x:970, y:282, w:240, h:44};
}

function setup_event_definitions(_category) {
    return _category == "strike" ? enemy_leader.leader_strikes : enemy_scenario.twists;
}

function setup_event_selections(_category) {
    return _category == "strike" ? enemy_event_selection.leader_strikes : enemy_event_selection.twists;
}

function setup_event_category_rect(_category) {
    var visible_rows = min(4, array_length(setup_event_definitions(_category)));
    var panel_height = max(130, 60 + visible_rows * 48);
    return _category == "strike"
        ? {x:50, y:330, w:560, h:panel_height}
        : {x:670, y:330, w:560, h:panel_height};
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
    return {x:panel.x + (_direction < 0 ? 448 : 504), y:panel.y + 7, w:44, h:40};
}

function setup_event_count_button_rect(_category, _visible_row, _direction) {
    var panel = setup_event_category_rect(_category);
    return {x:panel.x + (_direction < 0 ? 450 : 506), y:panel.y + 46 + _visible_row * 48, w:44, h:44};
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

function draw_setup_counter_button(_rect, _text, _enabled) {
    draw_panel(_rect, _enabled ? COL_ACCENT : COL_PANEL, _enabled ? COL_TEXT : COL_EDGE);
    draw_center(_text, _rect.x + _rect.w / 2, _rect.y + _rect.h / 2,
        _enabled ? COL_BG : COL_MUTED);
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
    draw_text(panel.x + 16, panel.y + 14, _title);
    if (page_count > 1) {
        draw_center(string(page + 1) + " / " + string(page_count), panel.x + 418, panel.y + 26, COL_MUTED);
        draw_setup_counter_button(setup_event_page_button_rect(_category, -1), "<", page > 0);
        draw_setup_counter_button(setup_event_page_button_rect(_category, 1), ">", page < page_count - 1);
    }
    if (array_length(definitions) == 0) {
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_color(COL_MUTED);
        draw_text(panel.x + 16, panel.y + 65, "None available");
        return;
    }
    var first_definition = page * 4;
    var final_definition = min(array_length(definitions), first_definition + 4);
    for (var definition_i = first_definition; definition_i < final_definition; definition_i++) {
        var visible_row = definition_i - first_definition;
        var row_y = panel.y + 48 + visible_row * 48;
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

function setup_event_selection_group_total(_selections) {
    var total = 0;
    for (var selection_i = 0; selection_i < array_length(_selections); selection_i++) {
        total += _selections[selection_i].copies;
    }
    return total;
}

function vv_ui_draw_setup() {
    vv_ui_set_font(UI_FONT_TITLE);
    draw_center_shadow("VILLAINS & VELVET", 640, 40, COL_GOLD);
    vv_ui_set_font(UI_FONT_BODY);
    draw_center_shadow(setup_advanced_events ? "BATTLE SETTINGS" : "CHOOSE YOUR BATTLE",
        640, 70, COL_TEXT);
    var battle_settings = setup_battle_settings_rect();
    var setup_sound = setup_sound_button_rect();
    draw_glass_panel(setup_sound, make_color_rgb(24, 33, 46),
        audio_enabled ? COL_ACCENT : COL_EDGE, 0.72);
    draw_center(audio_enabled ? "SOUND ON" : "SOUND OFF",
        setup_sound.x + setup_sound.w / 2, setup_sound.y + setup_sound.h / 2,
        audio_enabled ? COL_TEXT : COL_MUTED);
    draw_glass_panel(battle_settings, make_color_rgb(24, 33, 46), COL_EDGE, 0.72);
    draw_center(setup_advanced_events ? "BACK TO BATTLE" : "BATTLE SETTINGS",
        battle_settings.x + battle_settings.w / 2,
        battle_settings.y + battle_settings.h / 2, COL_TEXT);

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
        draw_glass_panel(setup_exit_rect, make_color_rgb(24, 33, 46), COL_EDGE, 0.72);
        draw_center("EXIT GAME", setup_exit_rect.x + setup_exit_rect.w / 2,
            setup_exit_rect.y + setup_exit_rect.h / 2, COL_TEXT);
        return;
    }

    if (setup_advanced_events) {
        var setup_panels = [
            {x:35, y:110, w:280, h:165},
            {x:335, y:110, w:280, h:165},
            {x:635, y:110, w:280, h:165},
            {x:935, y:110, w:280, h:165}
        ];
        draw_set_alpha(0.92);
        for (var panel_i = 0; panel_i < 4; panel_i++) draw_panel(setup_panels[panel_i], COL_PANEL, COL_EDGE);
        draw_set_alpha(1);

        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_color(COL_GOLD);
        draw_text(55, 124, "LEADER");
        draw_text(355, 124, "SCENARIO");
        draw_text(655, 124, "MINION SET");
        draw_text(955, 124, "HERO TEAM");
        draw_setup_dropdown(setup_selector_button_rect("leader"), enemy_leader.name);
        draw_setup_dropdown(setup_selector_button_rect("scenario"), enemy_scenario.name);
        draw_setup_dropdown(setup_selector_button_rect("minion_set"), enemy_minion_set.name);

        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_color(COL_MUTED);
        draw_text(55, 204, string(enemy_leader.starting_hp) + " HEALTH   "
            + string(enemy_leader.attack) + " ATTACK");
        draw_text(55, 232, string(setup_event_selection_group_total(enemy_event_selection.leader_strikes))
            + " LEADER STRIKES");
        draw_text(355, 204, string(setup_event_selection_group_total(enemy_event_selection.twists)) + " TWISTS");
        draw_text_ext(355, 230, enemy_scenario.description, 16, 245);
        draw_text(655, 204, string(CORE_MINION_TOTAL) + " MINIONS");

        for (var setup_hero_i = 0; setup_hero_i < array_length(selected_hero_ids); setup_hero_i++) {
            var setup_hero = find_hero_definition(available_heroes, selected_hero_ids[setup_hero_i]);
            draw_set_halign(fa_left);
            draw_set_valign(fa_middle);
            vv_ui_set_font(UI_FONT_SMALL);
            draw_set_color(COL_MUTED);
            draw_text(949, 162 + setup_hero_i * 42, string(setup_hero_i + 1));
            vv_ui_set_font(UI_FONT_BODY);
            if (!is_undefined(setup_hero)) draw_setup_dropdown(setup_hero_button_rect(setup_hero_i, 1), setup_hero.name);
        }

        var strike_event_panel = setup_event_category_rect("strike");
        var twist_event_panel = setup_event_category_rect("twist");
        var event_mix_height = max(strike_event_panel.h, twist_event_panel.h) + 60;
        draw_glass_panel({x:35, y:282, w:1210, h:event_mix_height},
            make_color_rgb(24, 33, 46), COL_EDGE, 0.50);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_color(COL_GOLD);
        draw_text(52, 295, "ENEMY EVENT MIX");
        draw_setup_event_category("strike", "LEADER STRIKES");
        draw_setup_event_category("twist", "TWISTS");
        var restore_rect = setup_restore_defaults_rect();
        draw_panel(restore_rect, setup_event_defaults_restored ? COL_ACCENT : COL_PANEL,
            setup_event_defaults_restored ? COL_TEXT : COL_EDGE);
        draw_center(setup_event_defaults_restored ? "EVENT MIX RESET" : "RESET EVENT MIX",
            restore_rect.x + restore_rect.w / 2, restore_rect.y + restore_rect.h / 2,
            setup_event_defaults_restored ? COL_BG : COL_TEXT);
    } else {
        var hero_summary = "";
        for (var summary_i = 0; summary_i < array_length(selected_hero_ids); summary_i++) {
            var summary_hero = find_hero_definition(available_heroes, selected_hero_ids[summary_i]);
            if (!is_undefined(summary_hero)) {
                if (hero_summary != "") hero_summary += "   |   ";
                hero_summary += summary_hero.name;
            }
        }
        draw_center_shadow(enemy_leader.name + "   |   " + enemy_scenario.name + "   |   " + enemy_minion_set.name,
            640, 126, COL_TEXT);
        draw_center_shadow(hero_summary, 640, 158, COL_MUTED);
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
    draw_center_shadow("ENEMY EVENTS  " + string(enemy_event_validation.total)
        + " / " + string(CORE_ENEMY_EVENT_SLOTS) + "    " + setup_status,
        640, 612, setup_validation.valid ? COL_LEGAL : COL_DANGER);

    draw_panel(setup_start_rect, setup_validation.valid ? COL_ACCENT : COL_PANEL,
        setup_validation.valid ? COL_TEXT : COL_EDGE);
    draw_center(guided_tutorial_complete ? "START GAME" : "START TRAINING",
        setup_start_rect.x + setup_start_rect.w / 2,
        setup_start_rect.y + setup_start_rect.h / 2,
        setup_validation.valid ? COL_BG : COL_MUTED);
    draw_glass_panel(setup_exit_rect, make_color_rgb(24, 33, 46), COL_EDGE, 0.38);
    draw_center("EXIT GAME", setup_exit_rect.x + setup_exit_rect.w / 2,
        setup_exit_rect.y + setup_exit_rect.h / 2, COL_MUTED);
}
