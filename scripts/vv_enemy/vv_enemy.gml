/// Enemy targeting, attacks, Minion effects, Enemy Draw, and prompt resolution.

function build_snapshot_has_priority(_build_snapshot) {
    for (var priority_i = 0; priority_i < array_length(_build_snapshot); priority_i++) {
        if (!is_undefined(_build_snapshot[priority_i])
        && card_has_enemy_target_priority(_build_snapshot[priority_i])) return true;
    }
    return false;
}

function build_has_priority() {
    return build_snapshot_has_priority(build);
}

function enemy_target_is_legal_in_build(_build_snapshot, _index, _amount) {
    if (_index < 0 || _index >= array_length(_build_snapshot)
    || is_undefined(_build_snapshot[_index])) return false;
    if (build_snapshot_has_priority(_build_snapshot)
    && !card_has_enemy_target_priority(_build_snapshot[_index])) return false;
    return _amount >= card_enemy_destruction_cost(_build_snapshot[_index]);
}

function enemy_target_is_legal(_index, _amount) {
    return enemy_target_is_legal_in_build(build, _index, _amount);
}

function enemy_has_legal_target(_amount) {
    for (var target_i = 0; target_i < 3; target_i++) {
        if (enemy_target_is_legal(target_i, _amount)) return true;
    }
    return false;
}

function enemy_legal_build_target_count(_amount) {
    var count = 0;
    for (var target_i = 0; target_i < 3; target_i++) {
        if (enemy_target_is_legal(target_i, _amount)) count++;
    }
    return count;
}

function enemy_hand_target_is_legal_in_hand(_hand, _index, _amount) {
    return _index >= 0 && _index < array_length(_hand) && !is_undefined(_hand[_index])
        && _amount >= card_enemy_destruction_cost(_hand[_index]);
}

function enemy_hand_target_is_legal(_index, _amount) {
    return enemy_hand_target_is_legal_in_hand(hand, _index, _amount);
}

function enemy_has_legal_hand_target(_amount) {
    for (var hand_i = 0; hand_i < array_length(hand); hand_i++) {
        if (enemy_hand_target_is_legal(hand_i, _amount)) return true;
    }
    return false;
}

function enemy_legal_hand_target_count(_amount) {
    var count = 0;
    for (var hand_i = 0; hand_i < array_length(hand); hand_i++) {
        if (enemy_hand_target_is_legal(hand_i, _amount)) count++;
    }
    return count;
}

function draw_full_assault_hand() {
    if (!full_assault_hand_needs_refill(hand)) return;
    hand = [undefined, undefined, undefined];
    for (var draw_slot = 0; draw_slot < 3; draw_slot++) {
        recycle_player_deck();
        if (array_length(player_deck) > 0) hand[draw_slot] = array_pop(player_deck);
    }
    log_add("Full Assault draws " + string(count_occupied_hand()) + " new Hand card(s).");
}

function full_assault_hand_needs_refill(_hand) {
    for (var hand_i = 0; hand_i < array_length(_hand); hand_i++) {
        if (!is_undefined(_hand[hand_i])) return false;
    }
    return true;
}

function lowest_build_indices() {
    var result = [];
    var lowest_hp = 9999;
    for (var low_i = 0; low_i < 3; low_i++) if (!is_undefined(build[low_i])) {
        if (build[low_i].hp < lowest_hp) {
            lowest_hp = build[low_i].hp;
            result = [low_i];
        } else if (build[low_i].hp == lowest_hp) array_push(result, low_i);
    }
    return result;
}

function prompt_build_is_legal(_index) {
    if (_index < 0 || _index > 2 || is_undefined(build[_index])) return false;
    if (prompt_mode == "enemy_attack") return enemy_target_is_legal(_index, prompt_value);
    if (prompt_mode == "disrupt" || prompt_mode == "full_assault_disrupt") return true;
    if (prompt_mode == "shatter" || prompt_mode == "full_assault_shatter") {
        var tied = lowest_build_indices();
        for (var tied_i = 0; tied_i < array_length(tied); tied_i++) {
            if (tied[tied_i] == _index) return true;
        }
    }
    return false;
}

function destroy_build_card(_index, _source) {
    if (is_undefined(build[_index])) return;
    vv_tutorial_note_destroyed_build_card(build[_index]);
    log_add(build[_index].name + " destroyed by " + _source + ".");
    array_push(player_discard, build[_index]);
    build[_index] = undefined;
}

function discard_build_card(_index, _source) {
    if (is_undefined(build[_index])) return;
    log_add(build[_index].name + " discarded by " + _source + ".");
    array_push(player_discard, build[_index]);
    build[_index] = undefined;
}

function destroy_hand_card(_index, _source) {
    if (_index < 0 || _index >= array_length(hand) || is_undefined(hand[_index])) return;
    log_add(hand[_index].name + " destroyed by " + _source + ".");
    array_push(player_discard, hand[_index]);
    hand[_index] = undefined;
}

function retire_minion(_index, _reason) {
    if (is_undefined(minions[_index])) return;
    log_add(minions[_index].name + " " + _reason + ".");
    array_push(enemy_used, minions[_index]);
    minions[_index] = undefined;
}

function queue_enemy_attack(_amount, _source, _can_hit_hand = false) {
    if (_amount > 0) array_push(queued_attacks,
        {amount:_amount, source:_source, can_hit_hand:_can_hit_hand});
}

function start_queued_attack() {
    while (array_length(queued_attacks) > 0) {
        var next_attack = queued_attacks[0];
        queued_attacks = array_remove_index(queued_attacks, 0);
        current_enemy_attack_can_hit_hand = next_attack.can_hit_hand;
        if (!build_has_cards() && current_enemy_attack_can_hit_hand
        && count_occupied_hand() <= 0) draw_full_assault_hand();
        var observation_zone = !build_has_cards() && current_enemy_attack_can_hit_hand
            ? "hand" : "build";
        var observation_candidates = observation_zone == "hand"
            ? enemy_legal_hand_target_count(next_attack.amount)
            : enemy_legal_build_target_count(next_attack.amount);
        enemy_ai_record_attack_observation(observation_zone, observation_candidates);
        if (!build_has_cards()) {
            if (current_enemy_attack_can_hit_hand) {
                if (enemy_has_legal_hand_target(next_attack.amount)) {
                    enemy_attack_notice = "";
                    enemy_attack_prompt_id++;
                    prompt_mode = "enemy_attack_hand";
                    prompt_value = next_attack.amount;
                    prompt_source = next_attack.source;
                    log_add(next_attack.source + " attacks the Hand for "
                        + string(next_attack.amount) + ". Choose a highlighted target.");
                    return true;
                }
                enemy_attack_notice = count_occupied_hand() <= 0
                    ? "No cards remain to attack.\nThe Attack ends."
                    : "No Hand card can be defeated.\nThe unused Attack ends.";
                log_add(next_attack.source + " cannot defeat a Hand card. The Attack ends.");
                continue;
            }
            enemy_attack_notice = "The Build Area is empty.\nThe Attack ends.";
            log_add(next_attack.source + " attacks for " + string(next_attack.amount) + ", but the Build Area is empty.");
            continue;
        }
        if (!enemy_has_legal_target(next_attack.amount)) {
            if (build_has_priority()) {
                enemy_attack_notice = "Guard/Fortress blocks the Attack.\nIt is not strong enough to defeat it.";
                log_add(next_attack.source + " cannot defeat Guard or Fortress. The Attack ends.");
            } else {
                enemy_attack_notice = "No Build card can be defeated.\nThe unused Attack ends.";
                log_add(next_attack.source + " cannot defeat any Build card. The Attack ends.");
            }
            continue;
        }
        enemy_attack_notice = "";
        enemy_ai_baseline_begin_attack(copy_build_snapshot(build), next_attack.amount);
        enemy_attack_prompt_id++;
        prompt_mode = "enemy_attack";
        prompt_value = next_attack.amount;
        prompt_source = next_attack.source;
        log_add(next_attack.source + " attacks for " + string(next_attack.amount) + ". Choose a highlighted target.");
        return true;
    }
    return false;
}

function begin_full_assault(_source) {
    full_assault_source = _source;
    full_assault_minions = full_assault_capture_minions(minions);
    full_assault_index = -1;
    log_add("Full Assault begins. The Queen and every Minion in play will attack.");
    queue_enemy_attack(enemy_leader.attack, _source + ": " + enemy_leader.name, true);
    resume_action = "continue_full_assault";
}

function full_assault_capture_minions(_minion_areas) {
    var captured = [];
    for (var minion_i = 0; minion_i < array_length(_minion_areas); minion_i++) {
        if (!is_undefined(_minion_areas[minion_i])) array_push(captured, _minion_areas[minion_i]);
    }
    return captured;
}

function full_assault_minion_attack_count(_minion) {
    return card_has_ability(_minion, ABILITY_CRUSH)
        || card_has_ability(_minion, ABILITY_DEVASTATE) ? 2 : 1;
}

function queue_full_assault_minion_attacks(_minion, _source) {
    var attack_count = full_assault_minion_attack_count(_minion);
    for (var attack_i = 0; attack_i < attack_count; attack_i++) {
        var attack_source = _source + ": " + _minion.name;
        if (attack_count > 1) attack_source += " (" + string(attack_i + 1)
            + " of " + string(attack_count) + ")";
        queue_enemy_attack(_minion.atk, attack_source, true);
    }
}

function run_full_assault_self_checks(_scenarios, _minion_sets) {
    var wrath = undefined;
    for (var scenario_i = 0; scenario_i < array_length(_scenarios); scenario_i++) {
        if (_scenarios[scenario_i].id == "the_queens_wrath") wrath = _scenarios[scenario_i];
    }
    if (is_undefined(wrath) || array_length(wrath.twists) != 1
    || array_length(wrath.twists[0].card.effects) != 1
    || wrath.twists[0].card.effects[0].id != EFFECT_FULL_ASSAULT) {
        return content_validation_result(false, "Full Assault Scenario definition check failed.");
    }
    if (array_length(_minion_sets) <= 0) {
        return content_validation_result(false, "Full Assault checks require a Minion Set.");
    }
    var cards = [];
    var minion_slots = _minion_sets[0].minion_slots;
    for (var slot_i = 0; slot_i < array_length(minion_slots); slot_i++) {
        array_push(cards, minion_slots[slot_i].card);
    }
    var crush_found = false;
    var devastate_found = false;
    var disrupt_found = false;
    var shatter_found = false;
    for (var card_i = 0; card_i < array_length(cards); card_i++) {
        var card = cards[card_i];
        if (card_has_ability(card, ABILITY_CRUSH)) {
            crush_found = full_assault_minion_attack_count(card) == 2;
        } else if (card_has_ability(card, ABILITY_DEVASTATE)) {
            devastate_found = full_assault_minion_attack_count(card) == 2;
        } else if (card_has_ability(card, ABILITY_DISRUPT)) disrupt_found = true;
        else if (card_has_ability(card, ABILITY_SHATTER)) shatter_found = true;
    }
    var captured = full_assault_capture_minions([cards[0], undefined, cards[1]]);
    var hand_test = [cards[0], cards[1], undefined];
    if (!crush_found || !devastate_found || !disrupt_found || !shatter_found
    || array_length(captured) != 2 || captured[0] != cards[0] || captured[1] != cards[1]
    || !enemy_hand_target_is_legal_in_hand(hand_test, 0, cards[0].hp)
    || enemy_hand_target_is_legal_in_hand(hand_test, 1, cards[1].hp - 1)
    || enemy_hand_target_is_legal_in_hand(hand_test, 2, 99)
    || full_assault_hand_needs_refill(hand_test)
    || !full_assault_hand_needs_refill([undefined, undefined, undefined])
    || enemy_ai_choose_hand_target_in_hand(hand_test, 99) != 0
    || enemy_ai_choose_hand_target_in_hand([cards[0], cards[0], undefined], 99) != 0) {
        return content_validation_result(false, "Full Assault behavior check failed.");
    }
    return content_validation_result(true, "");
}

function continue_full_assault() {
    full_assault_index++;
    if (full_assault_index >= array_length(full_assault_minions)) {
        log_add("Full Assault ends. Cards left in the Hand are kept.");
        full_assault_minions = [];
        full_assault_index = -1;
        resume_action = "continue_enemy_draw";
        resume_after_prompts();
        return;
    }

    var minion = full_assault_minions[full_assault_index];
    full_assault_current_minion = minion;
    resume_action = "continue_full_assault";
    if (card_has_ability(minion, ABILITY_DISRUPT) && build_has_cards()) {
        prompt_mode = "full_assault_disrupt";
        prompt_source = full_assault_source + ": " + minion.name + " — Disrupt";
        log_add(prompt_source + ". Choose a highlighted Build card to discard.");
        return;
    }
    if (card_has_ability(minion, ABILITY_SHATTER) && build_has_cards()) {
        var tied = lowest_build_indices();
        if (array_length(tied) == 1) {
            destroy_build_card(tied[0], full_assault_source + ": " + minion.name + " — Shatter");
        } else if (array_length(tied) > 1) {
            prompt_mode = "full_assault_shatter";
            prompt_source = full_assault_source + ": " + minion.name + " — Shatter";
            log_add(prompt_source + ". Choose a highlighted lowest-HP Build card.");
            return;
        }
    }
    queue_full_assault_minion_attacks(minion, full_assault_source);
    resume_after_prompts();
}

function command_end_enemy_attack_if_blocked() {
    if (prompt_mode != "enemy_attack" || enemy_has_legal_target(prompt_value)) return false;
    if (!build_has_cards()) {
        enemy_attack_notice = "The Build Area is clear.\nThe unused Attack ends.";
    } else if (build_has_priority()) {
        enemy_attack_notice = "Guard/Fortress blocks the rest.\nThe unused Attack ends.";
    } else {
        enemy_attack_notice = "No other card can be defeated.\nThe unused Attack ends.";
    }
    log_add(string(prompt_value) + " Attack remains, but no legal card can be defeated. The Attack ends.");
    prompt_mode = "";
    prompt_value = 0;
    prompt_source = "";
    enemy_ai_baseline_end_attack();
    resume_after_prompts();
    validate_state("Enemy Attack ends without a target");
    return true;
}

function command_end_enemy_hand_attack_if_blocked() {
    if (prompt_mode != "enemy_attack_hand"
    || enemy_has_legal_hand_target(prompt_value)) return false;
    enemy_attack_notice = count_occupied_hand() <= 0
        ? "No cards remain to attack.\nThe unused Attack ends."
        : "No Hand card can be defeated.\nThe unused Attack ends.";
    log_add(string(prompt_value)
        + " Attack remains, but no legal Hand card can be defeated. The Attack ends.");
    prompt_mode = "";
    prompt_value = 0;
    prompt_source = "";
    enemy_ai_baseline_end_attack();
    resume_after_prompts();
    validate_state("Enemy Hand Attack ends without a target");
    return true;
}

function heal_leader(_amount) {
    var heal_before = leader_hp;
    var healing_room = enemy_leader.max_hp - leader_hp;
    var healed = min(_amount, healing_room);
    var overflow = _amount - healed;
    leader_hp += healed;
    vv_tutorial_note_leader_heal(heal_before, leader_hp);
    log_add("Leader heals " + string(healed) + " HP (" + string(leader_hp) + "/" + string(enemy_leader.max_hp) + ").");
    if (overflow > 0) {
        log_add(string(overflow) + " excess healing becomes Overflow Attack.");
        queue_enemy_attack(overflow, "Overflow");
    }
}

function resolve_escape_effect(_effect, _minion) {
    switch (_effect.id) {
        case EFFECT_HEAL_LEADER:
            heal_leader(_effect.params.amount);
            return false;
        case EFFECT_DESTROY_HAND_CARD:
            escape_cards_remaining = max(0, floor(variable_struct_exists(_effect.params, "count")
                ? _effect.params.count : 1));
            escape_prompt_source = _minion.name + " — Escape";
            return continue_escape_hand_destruction();
    }
    show_debug_message("UNKNOWN ESCAPE EFFECT: " + string(_effect.id));
    return false;
}

function continue_escape_hand_destruction() {
    if (escape_cards_remaining <= 0) return false;
    if (count_occupied_hand() <= 0) {
        log_add(escape_prompt_source + " cannot destroy the remaining "
            + string(escape_cards_remaining) + " Hand card(s) because the Hand is empty.");
        escape_cards_remaining = 0;
        return false;
    }
    prompt_mode = "destroy_hand";
    prompt_source = escape_prompt_source;
    log_add(prompt_source + ": choose a highlighted Hand card to destroy ("
        + string(escape_cards_remaining) + " remaining).");
    return true;
}

function continue_minion_escape() {
    if (is_undefined(escape_minion)) return false;
    while (escape_effect_index < array_length(escape_minion.escape_effects)) {
        var effect = escape_minion.escape_effects[escape_effect_index];
        escape_effect_index++;
        if (resolve_escape_effect(effect, escape_minion)) return true;
    }
    escape_minion = undefined;
    escape_effect_index = 0;
    escape_cards_remaining = 0;
    escape_prompt_source = "";
    resume_after_prompts();
    return true;
}

function resolve_minion_escape(_minion) {
    escape_minion = _minion;
    escape_effect_index = 0;
    escape_cards_remaining = 0;
    escape_prompt_source = "";
    continue_minion_escape();
}

function minion_advance_plan(_area_2, _area_1) {
    var has_area_2 = !is_undefined(_area_2);
    var has_area_1 = !is_undefined(_area_1);
    return {
        escaping: has_area_2 && has_area_1 ? _area_2 : undefined,
        incoming: has_area_1 ? _area_1 : undefined,
        area_2_after: has_area_1 ? _area_1 : _area_2,
        area_1_after: undefined
    };
}

function run_minion_advance_self_checks() {
    var area_2_card = {id:"area_2_test"};
    var area_1_card = {id:"area_1_test"};
    var pushed = minion_advance_plan(area_2_card, area_1_card);
    var moved = minion_advance_plan(undefined, area_1_card);
    var stayed = minion_advance_plan(area_2_card, undefined);
    if (pushed.escaping != area_2_card || pushed.area_2_after != area_1_card
    || !is_undefined(pushed.area_1_after)
    || !is_undefined(moved.escaping) || moved.area_2_after != area_1_card
    || stayed.area_2_after != area_2_card || !is_undefined(stayed.incoming)) {
        return content_validation_result(false, "Minion Advance/Escape movement check failed.");
    }
    return content_validation_result(true, "");
}

function begin_advance_phase() {
    step_number = 2;
    resume_action = "finish_advance";
    log_add("Step 2 — Advance/Escape.");
    var advance_plan = minion_advance_plan(minions[0], minions[1]);
    advance_incoming_minion = advance_plan.incoming;
    advance_escape_pending = !is_undefined(advance_plan.escaping);
    // A Minion escapes only when the Minion in Area 1 pushes it out.
    if (advance_escape_pending) {
        log_add(advance_incoming_minion.name + " pushes " + advance_plan.escaping.name + " out of Area 2.");
        log_add(advance_plan.escaping.name + " begins its Escape effect.");
        if (tutorial_mode && turn_number == 3) {
            tutorial_pending_escape = advance_plan.escaping;
            vv_tutorial_set_state(TutorialStep.T3_Area2Full, "result", "AREA 2 IS FULL",
                "Red Panda cannot enter Area 2 while Corgi is there. Continue to watch the push.", true);
            return;
        }
        resolve_minion_escape(advance_plan.escaping);
        return;
    } else if (!is_undefined(minions[0])) {
        log_add(minions[0].name + " remains in Area 2 because Area 1 is empty.");
    }
    resume_after_prompts();
}

function continue_minion_entry() {
    if (is_undefined(entry_minion)) return false;
    while (entry_ability_index < array_length(entry_minion.abilities)) {
        var ability = entry_minion.abilities[entry_ability_index];
        entry_ability_index++;
        var ability_source = entry_minion.name + " — " + ability.name;
        switch (ability.id) {
            case ABILITY_DISRUPT:
                if (build_has_cards()) {
                    prompt_mode = "disrupt";
                    prompt_value = 0;
                    prompt_source = ability_source;
                    log_add(entry_minion.name + " uses " + ability.name + ". Choose a highlighted Build card to discard.");
                    return true;
                }
                log_add(entry_minion.name + " uses " + ability.name + ", but the Build Area is empty.");
                break;
            case ABILITY_CRUSH:
            case ABILITY_DEVASTATE:
                entry_has_attack_pattern = true;
                queue_enemy_attack(entry_minion.atk, ability_source + " (1 of 2)");
                queue_enemy_attack(entry_minion.atk, ability_source + " (2 of 2)");
                break;
            case ABILITY_SHATTER:
                var tied = lowest_build_indices();
                if (array_length(tied) == 1) destroy_build_card(tied[0], ability_source);
                else if (array_length(tied) > 1) {
                    prompt_mode = "shatter";
                    prompt_value = 0;
                    prompt_source = ability_source;
                    log_add(entry_minion.name + " uses " + ability.name + ". Choose a highlighted card tied for lowest Health.");
                    return true;
                } else log_add(entry_minion.name + " uses " + ability.name + ", but the Build Area is empty.");
                break;
            case ABILITY_PROTECTOR:
                log_add(entry_minion.name + " is protecting the Enemy Leader.");
                break;
            default:
                show_debug_message("UNKNOWN MINION ENTRY ABILITY: " + string(ability.id));
                break;
        }
    }
    if (!entry_has_attack_pattern) queue_enemy_attack(entry_minion.atk, entry_minion.name + " — Attack");
    entry_minion = undefined;
    entry_ability_index = 0;
    entry_has_attack_pattern = false;
    resume_after_prompts();
    return true;
}

function resolve_minion_entry(_minion) {
    log_add(_minion.name + " enters Minion Area 1.");
    resume_action = "finish_enemy";
    entry_minion = _minion;
    entry_ability_index = 0;
    entry_has_attack_pattern = false;
    if (tutorial_mode && turn_number <= 3) {
        vv_tutorial_schedule(turn_number == 1 ? TutorialStep.T1_CorgiEntryWatch
            : (turn_number == 2 ? TutorialStep.T2_RedPandaEntryWatch : TutorialStep.T3_BunnyEntryWatch),
            _minion.name + " enters Area 1. It now makes its normal attack.", "entry");
        return;
    }
    continue_minion_entry();
}

function resolve_leader_strike(_card) {
    var draw_source = "Enemy Draw #" + string(revealed_enemy_draw_number) + " — " + _card.name;
    log_add(draw_source + ".");
    var resolved = true;
    for (var effect_i = 0; effect_i < array_length(_card.effects); effect_i++) {
        var effect = _card.effects[effect_i];
        switch (effect.id) {
            case EFFECT_LEADER_BASIC_ATTACK:
                queue_enemy_attack(enemy_leader.attack, draw_source);
                break;
            default:
                resolved = false;
                show_debug_message("UNKNOWN LEADER STRIKE EFFECT: " + string(effect.id));
                break;
        }
    }
    if (!resolved) log_add(_card.name + " has an unknown Leader Strike effect that does nothing.");
    return resolved;
}

function resolve_twist(_card) {
    var draw_source = "Enemy Draw #" + string(revealed_enemy_draw_number) + " — " + _card.name;
    log_add(draw_source + ".");
    var resolved = true;
    for (var effect_i = 0; effect_i < array_length(_card.effects); effect_i++) {
        var effect = _card.effects[effect_i];
        switch (effect.id) {
            case EFFECT_AREA_2_ATTACK:
                if (!is_undefined(minions[0])) {
                    queue_enemy_attack(minions[0].atk, draw_source + ": " + minions[0].name);
                } else {
                    log_add("Area 2 is empty; " + _card.name + " has no effect.");
                }
                break;
            case EFFECT_FULL_ASSAULT:
                begin_full_assault(draw_source);
                break;
            default:
                resolved = false;
                show_debug_message("UNKNOWN TWIST EFFECT: " + string(effect.id));
                break;
        }
    }
    if (!resolved) log_add(_card.name + " has an unknown Twist effect that does nothing.");
    return resolved;
}

function draw_next_enemy_card() {
    step_number = 3;
    phase = "start_resolving";
    revealed_enemy_card = undefined;
    revealed_enemy_draw_number = 0;
    enemy_attack_notice = "";
    if (array_length(enemy_deck) == 0) {
        enemy_exhausted = true;
        enemy_ai_reward_begin_player_response();
        step_number = 4;
        phase = "step4_ready";
        auto_timer = 45;
        log_add("The Enemy Deck is empty. This is your final chance to build and attack.");
        validate_state("Enemy Deck exhausted");
        return;
    }
    enemy_draw_number++;
    var enemy_card = array_pop(enemy_deck);
    if (array_length(enemy_deck) == 0) enemy_exhausted = true;
    if (enemy_card.card_type == "strike") {
        revealed_enemy_card = enemy_card;
        revealed_enemy_draw_number = enemy_draw_number;
        array_push(enemy_used, enemy_card);
        if (vv_tutorial_pause_event_card(enemy_card)) return;
        resolve_leader_strike(enemy_card);
        resume_action = "continue_enemy_draw";
        resume_after_prompts();
    } else if (enemy_card.card_type == "twist") {
        revealed_enemy_card = enemy_card;
        revealed_enemy_draw_number = enemy_draw_number;
        array_push(enemy_used, enemy_card);
        if (vv_tutorial_pause_event_card(enemy_card)) return;
        resolve_twist(enemy_card);
        if (resume_action != "continue_full_assault") resume_action = "continue_enemy_draw";
        resume_after_prompts();
    } else {
        log_add("Enemy Draw #" + string(enemy_draw_number) + " — " + enemy_card.name + ".");
        minions[1] = enemy_card;
        if (tutorial_mode) tutorial_entry_notice_timer = 100;
        resolve_minion_entry(enemy_card);
    }
}

function command_prompt_hand(_index) {
    if (prompt_mode == "enemy_attack_hand") {
        if (!enemy_hand_target_is_legal(_index, prompt_value)) return false;
        prompt_value -= card_enemy_destruction_cost(hand[_index]);
        destroy_hand_card(_index, "enemy Attack");
        if (prompt_value > 0 && count_occupied_hand() <= 0) draw_full_assault_hand();
        if (prompt_value > 0 && enemy_has_legal_hand_target(prompt_value)) {
            log_add(string(prompt_value) + " Attack remains. Choose another highlighted Hand card.");
            return true;
        }
        if (prompt_value > 0) {
            enemy_attack_notice = count_occupied_hand() <= 0
                ? "No cards remain to attack.\nThe unused Attack ends."
                : "No other Hand card can be defeated.\nThe unused Attack ends.";
        }
        prompt_mode = "";
        prompt_value = 0;
        prompt_source = "";
        enemy_ai_baseline_end_attack();
        resume_after_prompts();
        validate_state("Full Assault attacks Hand");
        return true;
    }
    if (prompt_mode != "destroy_hand" || _index < 0 || _index >= array_length(hand)
    || is_undefined(hand[_index])) return false;
    var source = prompt_source;
    destroy_hand_card(_index, source);
    escape_cards_remaining = max(0, escape_cards_remaining - 1);
    prompt_mode = "";
    prompt_source = "";
    if (!continue_escape_hand_destruction()) continue_minion_escape();
    validate_state("Escape destroys Hand card");
    return true;
}

function command_prompt_build(_index) {
    if (!prompt_build_is_legal(_index)) {
        log_add("That card cannot be targeted. Choose a highlighted card.");
        return false;
    }
    if (prompt_mode == "enemy_attack") {
        enemy_ai_baseline_record_destroyed_card(copy_build_snapshot(build), _index);
        prompt_value -= card_enemy_destruction_cost(build[_index]);
        vv_tutorial_note_enemy_attack_remaining(prompt_value);
        destroy_build_card(_index, "enemy Attack");
        if (prompt_value > 0 && enemy_has_legal_target(prompt_value)) {
            log_add(string(prompt_value) + " Attack remains. Choose another highlighted target.");
            return true;
        }
        if (prompt_value > 0 && !build_has_cards() && current_enemy_attack_can_hit_hand) {
            if (count_occupied_hand() <= 0) draw_full_assault_hand();
            if (enemy_has_legal_hand_target(prompt_value)) {
                prompt_mode = "enemy_attack_hand";
                log_add(string(prompt_value) + " Attack remains and moves to the Hand.");
                return true;
            }
        }
        if (prompt_value > 0) return command_end_enemy_attack_if_blocked();
        prompt_mode = "";
        prompt_value = 0;
        prompt_source = "";
        enemy_ai_baseline_end_attack();
        resume_after_prompts();
        validate_state("Enemy Attack");
        return true;
    }
    if (prompt_mode == "disrupt") {
        var disrupt_source = prompt_source;
        discard_build_card(_index, disrupt_source);
        prompt_mode = "";
        prompt_value = 0;
        prompt_source = "";
        continue_minion_entry();
        validate_state("Disrupt resolves");
        return true;
    }
    if (prompt_mode == "shatter") {
        var shatter_source = prompt_source;
        destroy_build_card(_index, shatter_source);
        prompt_mode = "";
        prompt_value = 0;
        prompt_source = "";
        continue_minion_entry();
        validate_state("Shatter resolves");
        return true;
    }
    if (prompt_mode == "full_assault_disrupt" || prompt_mode == "full_assault_shatter") {
        var full_source = prompt_source;
        var was_disrupt = prompt_mode == "full_assault_disrupt";
        if (was_disrupt) discard_build_card(_index, full_source);
        else {
            var full_tied = lowest_build_indices();
            if (!array_has_value(full_tied, _index)) return false;
            destroy_build_card(_index, full_source);
        }
        prompt_mode = "";
        prompt_value = 0;
        prompt_source = "";
        queue_full_assault_minion_attacks(full_assault_current_minion, full_assault_source);
        resume_after_prompts();
        validate_state("Full Assault ability resolves");
        return true;
    }
    return false;
}

function find_leader_protector() {
    for (var minion_i = 0; minion_i < 2; minion_i++) {
        if (!is_undefined(minions[minion_i]) && card_has_ability(minions[minion_i], ABILITY_PROTECTOR)) return minions[minion_i];
    }
    return undefined;
}

function leader_is_protected() {
    return !is_undefined(find_leader_protector());
}
