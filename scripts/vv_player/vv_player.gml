/// Player Deck recycling, Hand/Build interaction, and Player Attack rules.

function recycle_player_deck() {
    if (array_length(player_deck) == 0 && array_length(player_discard) > 0) {
        player_deck = array_shuffle_copy(player_discard);
        player_discard = [];
        log_add("The discard pile was shuffled back into the Player Deck.");
    }
}

function hero_card_entered_build(_card) {
    if (!is_undefined(_card) && card_has_ability(_card, ABILITY_TROLL_UNBREAKABLE)) {
        _card.unbreakable_used = false;
    }
}

function player_draw_one_to_hand() {
    recycle_player_deck();
    if (array_length(player_deck) <= 0) return false;
    array_push(hand, array_pop(player_deck));
    return true;
}

function witch_minion_cost_reduction_from_build(_build) {
    var reduction = 0;
    for (var build_i = 0; build_i < array_length(_build); build_i++) {
        if (is_undefined(_build[build_i])) continue;
        reduction = max(reduction, card_ability_param_total(
            _build[build_i], "minion_cost_reduction"));
    }
    return reduction;
}

function witch_minion_cost_reduction() {
    return witch_minion_cost_reduction_from_build(build);
}

function player_minion_attack_cost(_minion) {
    return max(1, _minion.hp - witch_minion_cost_reduction());
}

function hero_set_2_run_self_checks(_heroes) {
    var vampire = find_hero_definition(_heroes, "vampire");
    var witch = find_hero_definition(_heroes, "witch");
    var troll = find_hero_definition(_heroes, "troll");
    if (is_undefined(vampire) || is_undefined(witch) || is_undefined(troll)) {
        return {valid:false, message:"Hero Set 02 definitions are missing."};
    }
    var drain = find_card_ability(vampire.ability, ABILITY_VAMPIRE_DRAIN);
    var feast = find_card_ability(vampire.special, ABILITY_VAMPIRE_FEAST);
    var hex = find_card_ability(witch.ability, ABILITY_WITCH_HEX);
    var curse = find_card_ability(witch.special, ABILITY_WITCH_CURSE);
    if (vampire.normal.atk != 5 || vampire.normal.hp != 3
    || ability_param_value(drain, "amount", 0) != 2
    || ability_param_value(feast, "amount", 0) != 3
    || ability_param_value(hex, "minion_cost_reduction", 0) != 2
    || ability_param_value(curse, "minion_cost_reduction", 0) != 3
    || card_enemy_destruction_cost(troll.ability) != 8
    || !card_has_ability(troll.special, ABILITY_TROLL_UNBREAKABLE)
    || vampire.unlock_wins != 1 || witch.unlock_wins != 2 || troll.unlock_wins != 3) {
        return {valid:false, message:"Hero Set 02 behavior check failed."};
    }
    return {valid:true, message:""};
}

function vampire_lowest_discard_indices() {
    var candidates = [];
    var lowest_hp = 999999;
    for (var discard_i = 0; discard_i < array_length(player_discard); discard_i++) {
        var card = player_discard[discard_i];
        if (is_undefined(card) || !variable_struct_exists(card, "hp")) continue;
        if (card.hp < lowest_hp) { lowest_hp = card.hp; candidates = [discard_i]; }
        else if (card.hp == lowest_hp) array_push(candidates, discard_i);
    }
    return candidates;
}

function vampire_continue_defeat_triggers() {
    while (drain_recovery_queue > 0) {
        drain_recovery_queue--;
        drain_recovery_candidates = vampire_lowest_discard_indices();
        if (array_length(drain_recovery_candidates) == 0) continue;
        if (array_length(drain_recovery_candidates) == 1) {
            var recovered_index = drain_recovery_candidates[0];
            var recovered = player_discard[recovered_index];
            player_discard = array_remove_index(player_discard, recovered_index);
            array_push(hand, recovered);
            log_add("Drain returns " + recovered.name + " to your Hand.");
            continue;
        }
        prompt_mode = "drain_recover";
        prompt_source = "Drain: choose a lowest-Health discard to recover.";
        return true;
    }
    while (feast_draw_queue > 0) {
        feast_draw_queue--;
        if (player_draw_one_to_hand()) log_add("Feast draws 1 card.");
    }
    return false;
}

function command_drain_recover(_choice) {
    if (prompt_mode != "drain_recover" || _choice < 0
    || _choice >= array_length(drain_recovery_candidates)) return false;
    var recovered_index = drain_recovery_candidates[_choice];
    var recovered = player_discard[recovered_index];
    player_discard = array_remove_index(player_discard, recovered_index);
    array_push(hand, recovered);
    log_add("Drain returns " + recovered.name + " to your Hand.");
    prompt_mode = "";
    prompt_source = "";
    drain_recovery_candidates = [];
    vampire_continue_defeat_triggers();
    validate_state("Drain recovery");
    return true;
}

function resolve_hero_minion_defeat_triggers() {
    var drain_count = 0;
    var feast_count = 0;
    for (var build_i = 0; build_i < array_length(build); build_i++) {
        if (is_undefined(build[build_i])) continue;
        if (card_has_ability(build[build_i], ABILITY_VAMPIRE_DRAIN)) drain_count++;
        if (card_has_ability(build[build_i], ABILITY_VAMPIRE_FEAST)) feast_count++;
    }
    if (drain_count > 0) attack_left += drain_count * 2;
    if (feast_count > 0) attack_left += feast_count * 3;
    drain_recovery_queue = drain_count;
    feast_draw_queue = feast_count;
    vampire_continue_defeat_triggers();
}

function draw_player_hand() {
    if (count_occupied_hand() > 0) {
        log_add("Cards left in your Hand were discarded.");
        for (var old_hand_i = 0; old_hand_i < array_length(hand); old_hand_i++) {
            if (!is_undefined(hand[old_hand_i])) array_push(player_discard, hand[old_hand_i]);
        }
    }
    hand = array_create(CORE_HAND_SIZE, undefined);
    for (var draw_slot = 0; draw_slot < CORE_HAND_SIZE; draw_slot++) {
        recycle_player_deck();
        if (array_length(player_deck) > 0) hand[draw_slot] = array_pop(player_deck);
    }
    log_add("Step 1 — Draw: " + string(count_occupied_hand()) + " cards in Hand.");
}

function count_unique_other_heroes(_cards, _source_index) {
    var hero_ids = [];
    var source_hero = _cards[_source_index].hero;
    for (var other_i = 0; other_i < array_length(_cards); other_i++) {
        if (other_i != _source_index && !is_undefined(_cards[other_i])) {
            var other_hero = _cards[other_i].hero;
            if (other_hero != source_hero && !array_has_value(hero_ids, other_hero)) {
                array_push(hero_ids, other_hero);
            }
        }
    }
    return array_length(hero_ids);
}

function copy_build_snapshot(_source_build) {
    var snapshot = [];
    for (var slot_i = 0; slot_i < array_length(_source_build); slot_i++) {
        array_push(snapshot, _source_build[slot_i]);
    }
    return snapshot;
}

function copy_build_without_slot(_build_snapshot, _removed_slot) {
    var candidate_snapshot = copy_build_snapshot(_build_snapshot);
    if (_removed_slot >= 0 && _removed_slot < array_length(candidate_snapshot)) {
        candidate_snapshot[_removed_slot] = undefined;
    }
    return candidate_snapshot;
}

function evaluate_build(_build_snapshot) {
    var guaranteed_attack = 0;
    var rally_power = 0;
    var conditional_attack = 0;
    var generic_guaranteed_others = 0;
    var generic_conditional_others = 0;
    for (var card_i = 0; card_i < array_length(_build_snapshot); card_i++) {
        if (is_undefined(_build_snapshot[card_i])) continue;
        var card = _build_snapshot[card_i];
        guaranteed_attack += card.atk;
        var rally = find_card_ability(card, ABILITY_RALLY);
        var overpower = find_card_ability(card, ABILITY_OVERPOWER);
        var relentless = find_card_ability(card, ABILITY_RELENTLESS);
        rally_power += ability_param_value(rally, "amount", 0);
        conditional_attack += ability_param_value(overpower, "amount", 0);
        conditional_attack += ability_param_value(relentless, "amount", 0);
        guaranteed_attack += card_ability_param_total(card, "guaranteed_attack_self");
        conditional_attack += card_ability_param_total(card, "conditional_attack_self");
        generic_guaranteed_others += card_ability_param_total(card, "guaranteed_attack_others");
        generic_conditional_others += card_ability_param_total(card, "conditional_attack_others");
    }
    for (var card_i = 0; card_i < array_length(_build_snapshot); card_i++) {
        if (is_undefined(_build_snapshot[card_i])) continue;
        var card = _build_snapshot[card_i];
        var own_rally = find_card_ability(card, ABILITY_RALLY);
        guaranteed_attack += max(0, rally_power - ability_param_value(own_rally, "amount", 0));
        var unity = find_card_ability(card, ABILITY_UNITY);
        guaranteed_attack += ability_param_value(unity, "amount_per_hero", 0)
            * count_unique_other_heroes(_build_snapshot, card_i);
        guaranteed_attack += max(0, generic_guaranteed_others
            - card_ability_param_total(card, "guaranteed_attack_others"));
        conditional_attack += max(0, generic_conditional_others
            - card_ability_param_total(card, "conditional_attack_others"));
    }
    return {
        guaranteed_attack: guaranteed_attack,
        conditional_attack: conditional_attack
    };
}

function compute_attack_summary() {
    var evaluation = evaluate_build(copy_build_snapshot(build));
    return {
        total: evaluation.guaranteed_attack,
        kill_bonus: evaluation.conditional_attack
    };
}

function command_select_hand(_index) {
    if (vv_tutorial_requires_drag()) return false;
    if (phase != "build" || _index < 0 || _index >= array_length(hand) || is_undefined(hand[_index])) return false;
    if (selected_build >= 0 && !is_undefined(build[selected_build])) {
        var build_card = build[selected_build];
        var hand_card = hand[_index];
        build[selected_build] = hand_card;
        hero_card_entered_build(hand_card);
        hand[_index] = build_card;
        log_add("Swapped " + build_card.name + " with " + hand_card.name + ".");
        selected_build = -1;
        selected_hand = -1;
        build_changed = true;
        build_finish_confirm = false;
        validate_state("Build-first swap");
        return true;
    }
    selected_hand = selected_hand == _index ? -1 : _index;
    selected_build = -1;
    if (selected_hand >= 0) {
        log_add("Selected " + hand[_index].name + ". Choose a highlighted space in the Build Area.");
    } else {
        log_add("Hand selection cancelled.");
    }
    return true;
}

function command_select_build(_index) {
    if (vv_tutorial_requires_drag()) return false;
    if (phase != "build" || _index < 0 || _index >= CORE_BUILD_SIZE) return false;
    if (selected_hand >= 0 && selected_hand < array_length(hand) && !is_undefined(hand[selected_hand])) {
        var hand_card = hand[selected_hand];
        if (is_undefined(build[_index])) {
            build[_index] = hand_card;
            hero_card_entered_build(hand_card);
            hand[selected_hand] = undefined;
            log_add("Placed " + hand_card.name + " in Build " + string(_index + 1) + ".");
        } else {
            var build_card = build[_index];
            build[_index] = hand_card;
            hero_card_entered_build(hand_card);
            hand[selected_hand] = build_card;
            log_add("Swapped " + build_card.name + " with " + hand_card.name + ".");
        }
        selected_hand = -1;
        selected_build = -1;
        build_changed = true;
        build_finish_confirm = false;
        validate_state("Hand-first Build action");
        return true;
    }
    if (!is_undefined(build[_index])) {
        selected_build = selected_build == _index ? -1 : _index;
        selected_hand = -1;
        return true;
    }
    log_add("Select a Hand card before choosing an empty Build space.");
    return false;
}

function command_drag_card(_source_area, _source_index, _target_area, _target_index) {
    if (phase != "build" || prompt_mode != "") return false;
    if (_source_area != "hand" && _source_area != "build") return false;
    if (_target_area != "hand" && _target_area != "build") return false;
    if (_source_index < 0 || _source_index >= CORE_HAND_SIZE
    || _target_index < 0 || _target_index >= CORE_BUILD_SIZE) return false;
    if (_source_area == _target_area) return false;
    if (!vv_tutorial_build_drop_allowed(_source_area, _source_index, _target_area, _target_index)) return false;

    var source_card = _source_area == "hand" ? hand[_source_index] : build[_source_index];
    if (is_undefined(source_card)) return false;
    var target_card = _target_area == "hand" ? hand[_target_index] : build[_target_index];

    // Build cards return to Hand only by swapping with a card already there.
    if (_source_area == "build" && _target_area == "hand" && is_undefined(target_card)) return false;

    if (_source_area == "hand") hand[_source_index] = target_card;
    else build[_source_index] = target_card;
    if (_target_area == "hand") hand[_target_index] = source_card;
    else { build[_target_index] = source_card; hero_card_entered_build(source_card); }
    selected_hand = -1;
    selected_build = -1;
    build_changed = true;
    build_finish_confirm = false;

    if (is_undefined(target_card)) {
        log_add("Moved " + source_card.name + " to Build " + string(_target_index + 1) + ".");
    } else {
        log_add("Swapped " + source_card.name + " with " + target_card.name + ".");
    }
    validate_state("Card drag and drop");
    vv_tutorial_after_build_move();
    return true;
}

function command_attack_minion(_index) {
    if (phase != "attack" || _index < 0 || _index > 1 || is_undefined(minions[_index])) return false;
    if (tutorial_mode && turn_number == 1) {
        log_add("Training: leave the Minions in place to learn how escaping works.");
        return false;
    }
    if (tutorial_mode && tutorial_minion_defeated) {
        log_add("Training: now use your remaining Attack on the highlighted Leader.");
        return false;
    }
    if (tutorial_mode && turn_number == 3
    && (tutorial_step != TutorialStep.T3_AttackBunny || minions[_index].id != "bunny")) return false;
    attack_finish_confirm = false;
    var minion_cost = player_minion_attack_cost(minions[_index]);
    if (attack_left >= minion_cost) {
        var defeat_cost = minion_cost;
        attack_left -= defeat_cost;
        var defeated_name = minions[_index].name;
        enemy_ai_conditional_learning_note_minion_defeated();
        retire_minion(_index, "is defeated");
        if (tutorial_mode) tutorial_minion_defeated = true;
        vv_tutorial_after_minion_defeated(defeat_cost);
        if (kill_bonus > 0) {
            attack_left += kill_bonus;
            log_add("Defeating " + defeated_name + " activates your card abilities: +"
                + string(kill_bonus) + " Attack.");
        }
        resolve_hero_minion_defeat_triggers();
    } else {
        log_add("You need " + string(minion_cost) + " Attack to defeat "
            + minions[_index].name + ", but you only have " + string(attack_left)
            + ". Your Attack was not spent.");
        vv_tutorial_after_failed_minion_attack();
    }
    validate_state("Player attacks Minion");
    if (attack_left <= 0 && !game_over) show_attack_completion("ALL ATTACK USED", "Attack step complete.");
    return true;
}

function command_attack_leader() {
    if (phase != "attack") return false;
    if (tutorial_mode && turn_number == 2) {
        log_add("Training: preserve both Minions so Area 1 can push Area 2 next turn.");
        return false;
    }
    if (tutorial_mode && turn_number >= 3 && !tutorial_minion_defeated) {
        log_add("Training: defeat a highlighted Minion before attacking the Leader.");
        return false;
    }
    attack_finish_confirm = false;
    var protector = find_leader_protector();
    if (!is_undefined(protector)) {
        var protector_ability = find_card_ability(protector, ABILITY_PROTECTOR);
        log_add(protector.name + "'s " + protector_ability.name + " prevents attacks on the Leader.");
        return false;
    }
    if (attack_left <= 0) {
        log_add("You have no Attack left.");
        return false;
    }
    var damage = attack_left;
    var actual_damage = min(damage, leader_hp);
    leader_hp = max(0, leader_hp - damage);
    if (tutorial_mode) tutorial_leader_attacked = true;
    if (tutorial_mode && turn_number >= 3) tutorial_final_leader_attacked = true;
    enemy_ai_baseline_record_leader_damage(actual_damage);
    attack_left = 0;
    log_add("Enemy Leader takes " + string(actual_damage) + " damage (" + string(leader_hp) + "/" + string(enemy_leader.max_hp) + ").");
    vv_tutorial_after_leader_attack(damage);
    if (leader_hp == 0) {
        enemy_ai_conditional_learning_finish_attack();
        enemy_ai_reward_finish_player_response(-1);
        game_over = true;
        victory = true;
        phase = "game_over";
        if (!tutorial_mode) hero_unlock_notice = vv_progress_record_victory(available_heroes);
        enemy_ai_record_auto_match_result(false);
        enemy_ai_baseline_finish_match(false);
        log_add("Victory! The Enemy Leader has been defeated.");
    }
    if (attack_left <= 0 && !game_over) show_attack_completion("ALL ATTACK USED", "Attack step complete.");
    validate_state("Player attacks Leader");
    return true;
}
