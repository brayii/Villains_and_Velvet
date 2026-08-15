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

function count_live_minions() {
    var count = 0;
    for (var count_i = 0; count_i < 2; count_i++) {
        if (!is_undefined(minions[count_i])) count++;
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

function refresh_setup_validation() {
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
    action_cooldown = 0;
    auto_timer = 0;
    game_over = false;
    victory = false;
    enemy_exhausted = false;
    log_lines = [];
    log_add("The battle begins with both Minion Areas empty.");
    log_add("Tap START TURN when you are ready.");
    validate_state("Reset");
    return true;
}
