/// Player Deck recycling, Hand/Build interaction, and Player Attack rules.

function recycle_player_deck() {
    if (array_length(player_deck) == 0 && array_length(player_discard) > 0) {
        player_deck = array_shuffle_copy(player_discard);
        player_discard = [];
        log_add("The discard pile was shuffled back into the Player Deck.");
    }
}

function draw_player_hand() {
    if (count_occupied_hand() > 0) {
        log_add("Cards left in your Hand were discarded.");
        for (var old_hand_i = 0; old_hand_i < array_length(hand); old_hand_i++) {
            if (!is_undefined(hand[old_hand_i])) array_push(player_discard, hand[old_hand_i]);
        }
    }
    hand = [undefined, undefined, undefined];
    for (var draw_slot = 0; draw_slot < 3; draw_slot++) {
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
    if (phase != "build" || _index < 0 || _index >= array_length(hand) || is_undefined(hand[_index])) return false;
    if (selected_build >= 0 && !is_undefined(build[selected_build])) {
        var build_card = build[selected_build];
        var hand_card = hand[_index];
        build[selected_build] = hand_card;
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
    if (phase != "build" || _index < 0 || _index > 2) return false;
    if (selected_hand >= 0 && selected_hand < array_length(hand) && !is_undefined(hand[selected_hand])) {
        var hand_card = hand[selected_hand];
        if (is_undefined(build[_index])) {
            build[_index] = hand_card;
            hand[selected_hand] = undefined;
            log_add("Placed " + hand_card.name + " in Build " + string(_index + 1) + ".");
        } else {
            var build_card = build[_index];
            build[_index] = hand_card;
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
    if (_source_index < 0 || _source_index >= 3 || _target_index < 0 || _target_index >= 3) return false;
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
    else build[_target_index] = source_card;
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
    attack_finish_confirm = false;
    if (attack_left >= minions[_index].hp) {
        attack_left -= minions[_index].hp;
        var defeated_name = minions[_index].name;
        enemy_ai_conditional_learning_note_minion_defeated();
        retire_minion(_index, "is defeated");
        if (tutorial_mode) tutorial_minion_defeated = true;
        if (kill_bonus > 0) {
            attack_left += kill_bonus;
            log_add("Defeating " + defeated_name + " activates your card abilities: +"
                + string(kill_bonus) + " Attack.");
        }
    } else {
        log_add("You need " + string(minions[_index].hp) + " Attack to defeat "
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
    log_add("Enemy Leader takes " + string(damage) + " damage (" + string(leader_hp) + "/" + string(enemy_leader.max_hp) + ").");
    vv_tutorial_after_leader_attack();
    if (leader_hp == 0) {
        enemy_ai_conditional_learning_finish_attack();
        enemy_ai_reward_finish_player_response(-1);
        game_over = true;
        victory = true;
        phase = "game_over";
        enemy_ai_baseline_finish_match(false);
        log_add("Victory! The Enemy Leader has been defeated.");
    }
    if (attack_left <= 0 && !game_over) show_attack_completion("ALL ATTACK USED", "Attack step complete.");
    validate_state("Player attacks Leader");
    if (tutorial_mode && tutorial_escape_seen && tutorial_minion_defeated
    && tutorial_leader_attacked && tutorial_final_leader_attacked) tutorial_complete_prompt = true;
    return true;
}
