/// Game-state initialization, counts, validation, and debug logging.

function array_remove_index(_source, _index) {
    var result = [];
    for (var source_i = 0; source_i < array_length(_source); source_i++) {
        if (source_i != _index) array_push(result, _source[source_i]);
    }
    return result;
}

function log_add(_text) {
    array_push(log_lines, _text);
    while (array_length(log_lines) > 6) log_lines = array_remove_index(log_lines, 0);
}

function count_occupied_build() {
    var count = 0;
    for (var count_i = 0; count_i < 3; count_i++) {
        if (!is_undefined(build[count_i])) count++;
    }
    return count;
}

function count_occupied_hand() {
    var count = 0;
    for (var count_i = 0; count_i < array_length(hand); count_i++) {
        if (!is_undefined(hand[count_i])) count++;
    }
    return count;
}

function build_has_cards() {
    return count_occupied_build() > 0;
}

function array_has_value(_values, _value) {
    for (var value_i = 0; value_i < array_length(_values); value_i++) {
        if (_values[value_i] == _value) return true;
    }
    return false;
}

function count_player_cards(_cards, _hero, _kind) {
    var count = 0;
    for (var card_i = 0; card_i < array_length(_cards); card_i++) {
        var card = _cards[card_i];
        if (card.hero == _hero && card.kind == _kind) count++;
    }
    return count;
}

function validate_player_composition(_cards) {
    if (array_length(_cards) != CORE_PLAYER_DECK_SIZE) return false;
    var hero_ids = [];
    for (var card_i = 0; card_i < array_length(_cards); card_i++) {
        var discovered_hero = _cards[card_i].hero;
        if (!array_has_value(hero_ids, discovered_hero)) array_push(hero_ids, discovered_hero);
    }
    if (array_length(hero_ids) != CORE_HERO_COUNT) return false;
    for (var hero_i = 0; hero_i < array_length(hero_ids); hero_i++) {
        var selected_hero = hero_ids[hero_i];
        if (count_player_cards(_cards, selected_hero, "Normal") != CORE_HERO_NORMAL_COPIES) return false;
        if (count_player_cards(_cards, selected_hero, "Ability") != CORE_HERO_ABILITY_COPIES) return false;
        if (count_player_cards(_cards, selected_hero, "Special") != CORE_HERO_SPECIAL_COPIES) return false;
    }
    return true;
}

function count_enemy_cards(_cards, _card_type, _slot) {
    var count = 0;
    for (var card_i = 0; card_i < array_length(_cards); card_i++) {
        var card = _cards[card_i];
        if (card.card_type == _card_type) {
            if (_card_type != "minion" || _slot == ""
            || (variable_struct_exists(card, "minion_slot") && card.minion_slot == _slot)) count++;
        }
    }
    return count;
}

function validate_enemy_composition(_cards, _minion_set) {
    if (array_length(_cards) != CORE_ENEMY_DECK_SIZE) return false;
    if (!core_minion_slots_are_valid(_minion_set)) return false;
    var core_slots = core_minion_slot_ids();
    for (var minion_i = 0; minion_i < array_length(core_slots); minion_i++) {
        var slot = core_slots[minion_i];
        if (count_enemy_cards(_cards, "minion", slot) != core_minion_slot_copies(slot)) return false;
    }
    var minion_count = count_enemy_cards(_cards, "minion", "");
    var event_count = count_enemy_cards(_cards, "strike", "") + count_enemy_cards(_cards, "twist", "");
    return minion_count == CORE_MINION_TOTAL && event_count == CORE_ENEMY_EVENT_SLOTS;
}

function enemy_event_selection_total(_selection) {
    var total = 0;
    for (var strike_i = 0; strike_i < array_length(_selection.leader_strikes); strike_i++) {
        total += _selection.leader_strikes[strike_i].copies;
    }
    for (var twist_i = 0; twist_i < array_length(_selection.twists); twist_i++) {
        total += _selection.twists[twist_i].copies;
    }
    return total;
}

function validate_enemy_event_group(_selected, _definitions) {
    if (array_length(_selected) != array_length(_definitions)) return false;
    var selected_ids = [];
    for (var selected_i = 0; selected_i < array_length(_selected); selected_i++) {
        var selection = _selected[selected_i];
        var definition = find_enemy_event_definition(_definitions, selection.id);
        if (is_undefined(definition)) return false;
        if (array_has_value(selected_ids, selection.id)) return false;
        if (selection.copies < 0 || selection.copies != floor(selection.copies)) return false;
        if (selection.copies > definition.max_copies) return false;
        array_push(selected_ids, selection.id);
    }
    for (var definition_i = 0; definition_i < array_length(_definitions); definition_i++) {
        var required_id = _definitions[definition_i].card.id;
        if (!array_has_value(selected_ids, required_id)) return false;
    }
    return true;
}

function find_enemy_event_selection_index(_selected, _id) {
    for (var selection_i = 0; selection_i < array_length(_selected); selection_i++) {
        if (_selected[selection_i].id == _id) return selection_i;
    }
    return -1;
}

function validate_enemy_event_selection(_leader, _scenario, _selection) {
    var total = enemy_event_selection_total(_selection);
    var heading = "Enemy Events: " + string(total) + " / " + string(CORE_ENEMY_EVENT_SLOTS);
    var valid_groups = validate_enemy_event_group(_selection.leader_strikes, _leader.leader_strikes)
        && validate_enemy_event_group(_selection.twists, _scenario.twists);
    if (total > CORE_ENEMY_EVENT_SLOTS) {
        return {valid:false, total:total, message:heading + "\n\nRemove "
            + string(total - CORE_ENEMY_EVENT_SLOTS) + " cards before starting."};
    }
    if (total < CORE_ENEMY_EVENT_SLOTS) {
        return {valid:false, total:total, message:heading + "\n\nAdd "
            + string(CORE_ENEMY_EVENT_SLOTS - total) + " cards before starting."};
    }
    if (!valid_groups) {
        return {valid:false, total:total, message:heading + "\n\nThe selection contains an unavailable card or exceeds its copy limit."};
    }
    return {valid:true, total:total, message:heading + "\n\nReady."};
}

function validate_hero_selection(_definitions, _selected_ids) {
    if (array_length(_selected_ids) != CORE_HERO_COUNT) return false;
    var unique_ids = [];
    for (var selected_i = 0; selected_i < array_length(_selected_ids); selected_i++) {
        var hero_id = _selected_ids[selected_i];
        if (is_undefined(find_hero_definition(_definitions, hero_id))) return false;
        if (array_has_value(unique_ids, hero_id)) return false;
        array_push(unique_ids, hero_id);
    }
    return array_length(unique_ids) == CORE_HERO_COUNT;
}

function content_validation_result(_valid, _message) {
    return {valid:_valid, message:_message};
}

function validate_registry_ids(_definitions, _label, _minimum) {
    if (!is_array(_definitions) || array_length(_definitions) < _minimum) {
        return content_validation_result(false, _label + " registry needs at least " + string(_minimum) + " definition(s).");
    }
    var ids = [];
    for (var definition_i = 0; definition_i < array_length(_definitions); definition_i++) {
        var definition = _definitions[definition_i];
        if (!is_struct(definition) || !variable_struct_exists(definition, "id")
        || !is_string(definition.id) || definition.id == "") {
            return content_validation_result(false, _label + " definition " + string(definition_i + 1) + " needs a stable ID.");
        }
        if (string_lower(definition.id) != definition.id) {
            return content_validation_result(false, _label + " ID '" + definition.id + "' must be lowercase.");
        }
        if (array_has_value(ids, definition.id)) {
            return content_validation_result(false, _label + " ID '" + definition.id + "' is duplicated.");
        }
        array_push(ids, definition.id);
    }
    return content_validation_result(true, "");
}

function validate_enemy_event_definitions(_definitions, _card_type, _owner_label) {
    if (!is_array(_definitions)) return content_validation_result(false, _owner_label + " events must be an array.");
    var ids = [];
    for (var event_i = 0; event_i < array_length(_definitions); event_i++) {
        var definition = _definitions[event_i];
        if (!is_struct(definition) || !variable_struct_exists(definition, "card")
        || !is_struct(definition.card) || !variable_struct_exists(definition.card, "id")
        || !is_string(definition.card.id) || definition.card.id == ""
        || !variable_struct_exists(definition.card, "name")
        || !variable_struct_exists(definition.card, "effects") || !is_array(definition.card.effects)
        || !variable_struct_exists(definition.card, "card_type") || definition.card.card_type != _card_type
        || !variable_struct_exists(definition, "default_copies")
        || !variable_struct_exists(definition, "max_copies")) {
            return content_validation_result(false, _owner_label + " event " + string(event_i + 1) + " is missing required fields.");
        }
        if (string_lower(definition.card.id) != definition.card.id || array_has_value(ids, definition.card.id)) {
            return content_validation_result(false, _owner_label + " event ID '" + definition.card.id + "' must be unique and lowercase.");
        }
        if (definition.default_copies < 0 || definition.default_copies != floor(definition.default_copies)
        || definition.max_copies < definition.default_copies || definition.max_copies != floor(definition.max_copies)) {
            return content_validation_result(false, _owner_label + " event '" + definition.card.id + "' has invalid copy limits.");
        }
        array_push(ids, definition.card.id);
    }
    return content_validation_result(true, "");
}

function validate_content_registries(_leaders, _scenarios, _minion_sets, _heroes) {
    var result = validate_registry_ids(_leaders, "Leader", 1);
    if (!result.valid) return result;
    result = validate_registry_ids(_scenarios, "Scenario", 1);
    if (!result.valid) return result;
    result = validate_registry_ids(_minion_sets, "Minion Set", 1);
    if (!result.valid) return result;
    result = validate_registry_ids(_heroes, "Hero", CORE_HERO_COUNT);
    if (!result.valid) return result;

    for (var leader_i = 0; leader_i < array_length(_leaders); leader_i++) {
        var leader = _leaders[leader_i];
        if (!variable_struct_exists(leader, "name") || !variable_struct_exists(leader, "starting_hp")
        || !variable_struct_exists(leader, "max_hp") || !variable_struct_exists(leader, "attack")
        || !variable_struct_exists(leader, "art_file") || !variable_struct_exists(leader, "abilities")
        || !is_array(leader.abilities) || !variable_struct_exists(leader, "special_moves")
        || !is_array(leader.special_moves) || !variable_struct_exists(leader, "leader_strikes")) {
            return content_validation_result(false, "Leader '" + leader.id + "' is missing required fields.");
        }
        result = validate_enemy_event_definitions(leader.leader_strikes, "strike", "Leader '" + leader.id + "'");
        if (!result.valid) return result;
    }
    for (var scenario_i = 0; scenario_i < array_length(_scenarios); scenario_i++) {
        var scenario = _scenarios[scenario_i];
        if (!variable_struct_exists(scenario, "name") || !variable_struct_exists(scenario, "setup_rules")
        || !is_array(scenario.setup_rules) || !variable_struct_exists(scenario, "twists")) {
            return content_validation_result(false, "Scenario '" + scenario.id + "' is missing required fields.");
        }
        result = validate_enemy_event_definitions(scenario.twists, "twist", "Scenario '" + scenario.id + "'");
        if (!result.valid) return result;
    }
    for (var minion_set_i = 0; minion_set_i < array_length(_minion_sets); minion_set_i++) {
        var minion_set = _minion_sets[minion_set_i];
        if (!variable_struct_exists(minion_set, "name") || !core_minion_slots_are_valid(minion_set)) {
            return content_validation_result(false, "Minion Set '" + minion_set.id + "' must define every unique core slot and Minion ID.");
        }
        for (var minion_i = 0; minion_i < array_length(minion_set.minion_slots); minion_i++) {
            var minion = minion_set.minion_slots[minion_i].card;
            if (!is_string(minion.id) || string_lower(minion.id) != minion.id
            || !variable_struct_exists(minion, "name")
            || !variable_struct_exists(minion, "abilities") || !is_array(minion.abilities)
            || !variable_struct_exists(minion, "escape_effects") || !is_array(minion.escape_effects)) {
                return content_validation_result(false, "Minion definition '" + string(minion.id) + "' is incomplete or not lowercase.");
            }
        }
    }
    for (var hero_i = 0; hero_i < array_length(_heroes); hero_i++) {
        var hero = _heroes[hero_i];
        if (!variable_struct_exists(hero, "name") || !variable_struct_exists(hero, "normal")
        || !variable_struct_exists(hero, "ability") || !variable_struct_exists(hero, "special")) {
            return content_validation_result(false, "Hero '" + hero.id + "' is missing card templates.");
        }
        var templates = [hero.normal, hero.ability, hero.special];
        var kinds = ["Normal", "Ability", "Special"];
        for (var template_i = 0; template_i < 3; template_i++) {
            var template = templates[template_i];
            if (!is_struct(template) || !variable_struct_exists(template, "hero") || template.hero != hero.id
            || !variable_struct_exists(template, "kind") || template.kind != kinds[template_i]
            || !variable_struct_exists(template, "abilities") || !is_array(template.abilities)) {
                return content_validation_result(false, "Hero '" + hero.id + "' has an invalid " + kinds[template_i] + " template.");
            }
        }
    }
    return content_validation_result(true, "Content registries ready.");
}

function refresh_setup_validation() {
    if (!content_registry_validation.valid) {
        enemy_event_validation = {valid:false, total:0, message:content_registry_validation.message};
        setup_validation = {valid:false, message:content_registry_validation.message};
        return setup_validation;
    }
    enemy_event_validation = validate_enemy_event_selection(enemy_leader, enemy_scenario, enemy_event_selection);
    var heroes_valid = validate_hero_selection(available_heroes, selected_hero_ids);
    var content_valid = !is_undefined(enemy_leader) && !is_undefined(enemy_scenario)
        && !is_undefined(enemy_minion_set);
    var minion_slots_valid = content_valid && core_minion_slots_are_valid(enemy_minion_set);
    var valid = content_valid && minion_slots_valid && heroes_valid && enemy_event_validation.valid;
    var message = enemy_event_validation.message;
    if (!content_valid) message = "Choose a Leader, Scenario, and Minion Set before starting.";
    else if (!minion_slots_valid) message = "The Minion Set must define every core Minion slot exactly once.";
    else if (!heroes_valid) message = "Choose exactly " + string(CORE_HERO_COUNT) + " different Heroes.";
    setup_validation = {valid:valid, message:message};
    return setup_validation;
}

function command_adjust_enemy_event(_category, _index, _change) {
    var selected = _category == "strike" ? enemy_event_selection.leader_strikes : enemy_event_selection.twists;
    var definitions = _category == "strike" ? enemy_leader.leader_strikes : enemy_scenario.twists;
    if (_index < 0 || _index >= array_length(selected)) return false;
    var selection = selected[_index];
    var definition = find_enemy_event_definition(definitions, selection.id);
    if (is_undefined(definition)) return false;
    var next_count = selection.copies + _change;
    if (next_count < 0 || next_count > definition.max_copies) return false;
    selection.copies = next_count;
    selected[_index] = selection;
    if (_category == "strike") enemy_event_selection.leader_strikes = selected;
    else enemy_event_selection.twists = selected;
    setup_event_defaults_restored = false;
    refresh_setup_validation();
    return true;
}

function wrap_content_index(_index, _count) {
    if (_count <= 0) return -1;
    return ((_index mod _count) + _count) mod _count;
}

function command_select_leader(_change) {
    var next_index = wrap_content_index(selected_leader_index + _change, array_length(available_leaders));
    if (next_index < 0 || next_index == selected_leader_index) return false;
    selected_leader_index = next_index;
    enemy_leader = available_leaders[selected_leader_index];
    enemy_event_selection = make_default_enemy_event_selection(enemy_leader, enemy_scenario);
    leader_art_sprite = get_art_sprite(enemy_leader.art_file);
    setup_strike_page = 0;
    setup_event_defaults_restored = false;
    refresh_setup_validation();
    return true;
}

function command_select_scenario(_change) {
    var next_index = wrap_content_index(selected_scenario_index + _change, array_length(available_scenarios));
    if (next_index < 0 || next_index == selected_scenario_index) return false;
    selected_scenario_index = next_index;
    enemy_scenario = available_scenarios[selected_scenario_index];
    enemy_event_selection = make_default_enemy_event_selection(enemy_leader, enemy_scenario);
    setup_twist_page = 0;
    setup_event_defaults_restored = false;
    refresh_setup_validation();
    return true;
}

function command_select_minion_set(_change) {
    var next_index = wrap_content_index(selected_minion_set_index + _change, array_length(available_minion_sets));
    if (next_index < 0 || next_index == selected_minion_set_index) return false;
    selected_minion_set_index = next_index;
    enemy_minion_set = available_minion_sets[selected_minion_set_index];
    refresh_setup_validation();
    return true;
}

function command_restore_enemy_event_defaults() {
    enemy_event_selection = make_default_enemy_event_selection(enemy_leader, enemy_scenario);
    setup_strike_page = 0;
    setup_twist_page = 0;
    setup_event_defaults_restored = true;
    refresh_setup_validation();
    return true;
}

function command_cycle_hero_slot(_slot, _change) {
    if (_slot < 0 || _slot >= CORE_HERO_COUNT || array_length(available_heroes) <= CORE_HERO_COUNT) return false;
    var current = find_hero_definition(available_heroes, selected_hero_ids[_slot]);
    if (is_undefined(current)) return false;
    var current_index = 0;
    for (var hero_i = 0; hero_i < array_length(available_heroes); hero_i++) {
        if (available_heroes[hero_i].id == current.id) current_index = hero_i;
    }
    for (var offset = 1; offset <= array_length(available_heroes); offset++) {
        var candidate_index = wrap_content_index(current_index + offset * _change, array_length(available_heroes));
        var candidate_id = available_heroes[candidate_index].id;
        if (!array_has_value(selected_hero_ids, candidate_id)) {
            selected_hero_ids[_slot] = candidate_id;
            refresh_setup_validation();
            return true;
        }
    }
    return false;
}

function command_start_game_from_setup() {
    refresh_setup_validation();
    if (!setup_validation.valid) return false;
    if (!reset_game()) return false;
    setup_active = false;
    return true;
}

function command_open_setup() {
    vv_ui_reset_match_interaction();
    setup_active = true;
    phase = "setup";
    refresh_setup_validation();
}

function collect_player_cards() {
    var cards = [];
    for (var deck_i = 0; deck_i < array_length(player_deck); deck_i++) array_push(cards, player_deck[deck_i]);
    for (var discard_i = 0; discard_i < array_length(player_discard); discard_i++) array_push(cards, player_discard[discard_i]);
    for (var hand_i = 0; hand_i < array_length(hand); hand_i++) {
        if (!is_undefined(hand[hand_i])) array_push(cards, hand[hand_i]);
    }
    for (var build_i = 0; build_i < array_length(build); build_i++) {
        if (!is_undefined(build[build_i])) array_push(cards, build[build_i]);
    }
    return cards;
}

function collect_enemy_cards() {
    var cards = [];
    for (var deck_i = 0; deck_i < array_length(enemy_deck); deck_i++) array_push(cards, enemy_deck[deck_i]);
    for (var used_i = 0; used_i < array_length(enemy_used); used_i++) array_push(cards, enemy_used[used_i]);
    for (var minion_i = 0; minion_i < array_length(minions); minion_i++) {
        if (!is_undefined(minions[minion_i])) array_push(cards, minions[minion_i]);
    }
    return cards;
}

function validate_state(_context) {
    var player_cards = collect_player_cards();
    var enemy_cards = collect_enemy_cards();
    var player_total = array_length(player_cards);
    var enemy_total = array_length(enemy_cards);
    var valid_player_composition = validate_player_composition(player_cards);
    var valid_enemy_composition = validate_enemy_composition(enemy_cards, enemy_minion_set);
    var valid_spaces = array_length(hand) == 3 && array_length(build) == 3 && array_length(minions) == 2;
    var valid = valid_player_composition && valid_enemy_composition
        && leader_hp >= 0 && leader_hp <= enemy_leader.max_hp
        && attack_left >= 0 && valid_spaces;
    if (!valid) {
        var state_message = _context + ": Player " + string(player_total)
            + "/" + string(CORE_PLAYER_DECK_SIZE)
            + ", Enemy " + string(enemy_total) + "/" + string(CORE_ENEMY_DECK_SIZE)
            + ", composition " + string(valid_player_composition)
            + "/" + string(valid_enemy_composition)
            + ", spaces " + string(array_length(hand)) + "/"
            + string(array_length(build)) + "/" + string(array_length(minions));
        log_add("STATE WARNING: " + state_message);
        show_debug_message("STATE WARNING: " + state_message);
    }
    return valid;
}

function reset_game() {
    if (!core_minion_slots_are_valid(enemy_minion_set)) {
        show_debug_message("The Minion Set does not define the required core Minion slots.");
        return false;
    }
    enemy_event_validation = validate_enemy_event_selection(enemy_leader, enemy_scenario, enemy_event_selection);
    if (!enemy_event_validation.valid) {
        show_debug_message(enemy_event_validation.message);
        return false;
    }
    leader_hp = enemy_leader.starting_hp;
    player_deck = make_player_deck(available_heroes, selected_hero_ids);
    player_discard = [];
    enemy_deck = make_enemy_deck(enemy_leader, enemy_scenario, enemy_minion_set, enemy_event_selection);
    enemy_used = [];
    hand = [undefined, undefined, undefined];
    build = [undefined, undefined, undefined];
    minions = [undefined, undefined]; // 0 = Area 2, 1 = Area 1
    revealed_enemy_card = undefined;
    selected_hand = -1;
    selected_build = -1;
    attack_left = 0;
    kill_bonus = 0;
    turn_number = 1;
    step_number = 1;
    phase = "step1_ready";
    prompt_mode = "";
    prompt_value = 0;
    prompt_source = "";
    enemy_attack_notice = "";
    resume_action = "";
    queued_attacks = [];
    entry_minion = undefined;
    entry_ability_index = 0;
    entry_has_attack_pattern = false;
    escape_minion = undefined;
    escape_effect_index = 0;
    escape_cards_remaining = 0;
    escape_prompt_source = "";
    action_cooldown = 0;
    auto_timer = 0;
    game_over = false;
    victory = false;
    enemy_exhausted = false;
    vv_ui_reset_match_interaction();
    log_lines = [];
    log_add("The battle begins with both Minion Areas empty.");
    log_add("Tap START TURN when you are ready.");
    validate_state("Reset");
    return true;
}
