/// Deterministic Enemy AI scoring. This module ranks Build slots but does not resolve attacks.

#macro ENEMY_AI_CONDITIONAL_WEIGHT 0.5
#macro ENEMY_AI_HEALTH_WEIGHT 1.0
#macro ENEMY_AI_TARGET_DELAY_FRAMES 45
#macro ENEMY_AI_RESULT_DELAY_FRAMES 30

function enemy_ai_baseline_init() {
    gameplay_seed = -1;
    enemy_ai_baseline_totals = {
        matches: 0,
        enemy_wins: 0,
        leader_hp_remaining: 0,
        leader_damage: 0,
        turns: 0,
        enemy_attacks: 0,
        guaranteed_attack_removed: 0,
        conditional_attack_removed: 0,
        cards_destroyed: 0,
        greedy_regret: 0,
        oracle_checks: 0
    };
    enemy_ai_baseline_match_active = false;
    enemy_ai_baseline_attack_active = false;
}

function enemy_ai_baseline_begin_match() {
    enemy_ai_baseline_match_active = gameplay_seed >= 0;
    enemy_ai_baseline_attack_active = false;
    enemy_ai_baseline_match = {
        seeded: gameplay_seed >= 0,
        started_in_auto: enemy_auto_play,
        mode_changed: false,
        leader_damage: 0,
        enemy_attacks: 0,
        guaranteed_attack_removed: 0,
        conditional_attack_removed: 0,
        cards_destroyed: 0,
        greedy_regret: 0,
        oracle_checks: 0
    };
}

function enemy_ai_baseline_note_mode_change() {
    if (enemy_ai_baseline_match_active) enemy_ai_baseline_match.mode_changed = true;
    if (!enemy_auto_play) enemy_ai_baseline_end_attack();
}

function enemy_ai_baseline_begin_attack(_build_snapshot, _attack_amount) {
    enemy_ai_baseline_attack_active = false;
    if (!enemy_ai_baseline_match_active || !enemy_auto_play) return;
    var comparison = enemy_ai_oracle_compare(_build_snapshot, _attack_amount);
    enemy_ai_baseline_attack_active = true;
    enemy_ai_baseline_match.enemy_attacks++;
    enemy_ai_baseline_match.greedy_regret += comparison.greedy_regret;
    enemy_ai_baseline_match.oracle_checks++;
}

function enemy_ai_baseline_record_destroyed_card(_build_snapshot, _slot) {
    if (!enemy_ai_baseline_attack_active || _slot < 0
    || _slot >= array_length(_build_snapshot) || is_undefined(_build_snapshot[_slot])) return;
    var before = evaluate_build(_build_snapshot);
    var after = evaluate_build(copy_build_without_slot(_build_snapshot, _slot));
    enemy_ai_baseline_match.guaranteed_attack_removed +=
        before.guaranteed_attack - after.guaranteed_attack;
    enemy_ai_baseline_match.conditional_attack_removed +=
        before.conditional_attack - after.conditional_attack;
    enemy_ai_baseline_match.cards_destroyed++;
}

function enemy_ai_baseline_end_attack() {
    enemy_ai_baseline_attack_active = false;
}

function enemy_ai_baseline_record_leader_damage(_amount) {
    if (enemy_ai_baseline_match_active && _amount > 0) {
        enemy_ai_baseline_match.leader_damage += _amount;
    }
}

function enemy_ai_baseline_finish_match(_enemy_won) {
    if (!enemy_ai_baseline_match_active) return;
    enemy_ai_baseline_end_attack();
    enemy_ai_baseline_match_active = false;
    if (!enemy_ai_baseline_match.started_in_auto || enemy_ai_baseline_match.mode_changed) {
        show_debug_message("ENEMY AI BASELINE | mixed/manual match excluded");
        return;
    }
    var totals = enemy_ai_baseline_totals;
    totals.matches++;
    if (_enemy_won) totals.enemy_wins++;
    totals.leader_hp_remaining += leader_hp;
    totals.leader_damage += enemy_ai_baseline_match.leader_damage;
    totals.turns += turn_number;
    totals.enemy_attacks += enemy_ai_baseline_match.enemy_attacks;
    totals.guaranteed_attack_removed += enemy_ai_baseline_match.guaranteed_attack_removed;
    totals.conditional_attack_removed += enemy_ai_baseline_match.conditional_attack_removed;
    totals.cards_destroyed += enemy_ai_baseline_match.cards_destroyed;
    totals.greedy_regret += enemy_ai_baseline_match.greedy_regret;
    totals.oracle_checks += enemy_ai_baseline_match.oracle_checks;

    var win_rate = totals.matches > 0 ? totals.enemy_wins / totals.matches : 0;
    var damage_per_turn = totals.turns > 0 ? totals.leader_damage / totals.turns : 0;
    var cards_per_attack = totals.enemy_attacks > 0
        ? totals.cards_destroyed / totals.enemy_attacks : 0;
    var average_regret = totals.oracle_checks > 0
        ? totals.greedy_regret / totals.oracle_checks : 0;
    show_debug_message("ENEMY AI BASELINE | seed=" + string(gameplay_seed)
        + " | matches=" + string(totals.matches)
        + " | enemy_win_rate=" + string(win_rate)
        + " | leader_hp=" + string(leader_hp)
        + " | leader_damage_per_turn=" + string(damage_per_turn)
        + " | guaranteed_attack_removed=" + string(totals.guaranteed_attack_removed)
        + " | conditional_attack_removed=" + string(totals.conditional_attack_removed)
        + " | cards_per_attack=" + string(cards_per_attack)
        + " | average_greedy_regret=" + string(average_regret));
}

function enemy_ai_start_seeded_playtest(_seed) {
    if (!is_real(_seed)) return false;
    gameplay_seed = floor(_seed);
    random_set_seed(gameplay_seed);
    if (!reset_game()) return false;
    setup_active = false;
    return true;
}

function enemy_ai_stop_seeded_playtest() {
    gameplay_seed = -1;
    enemy_ai_baseline_match_active = false;
    enemy_ai_baseline_end_attack();
    randomize();
}

function enemy_ai_score_candidate(_evaluation_before, _build_snapshot, _slot,
_conditional_weight, _health_weight) {
    var candidate_snapshot = copy_build_without_slot(_build_snapshot, _slot);
    var evaluation_after = evaluate_build(candidate_snapshot);
    var guaranteed_threat = _evaluation_before.guaranteed_attack
        - evaluation_after.guaranteed_attack;
    var conditional_threat = _evaluation_before.conditional_attack
        - evaluation_after.conditional_attack;
    var target_health = _build_snapshot[_slot].hp;
    return {
        slot: _slot,
        guaranteed_threat: guaranteed_threat,
        conditional_threat: conditional_threat,
        health: target_health,
        score: guaranteed_threat
            + _conditional_weight * conditional_threat
            - _health_weight * target_health
    };
}

function enemy_ai_candidate_ranks_before(_left, _right) {
    if (_left.score != _right.score) return _left.score > _right.score;
    if (_left.guaranteed_threat != _right.guaranteed_threat) {
        return _left.guaranteed_threat > _right.guaranteed_threat;
    }
    if (_left.health != _right.health) return _left.health < _right.health;
    return _left.slot < _right.slot;
}

function enemy_ai_rank_build(_build_snapshot) {
    var evaluation_before = evaluate_build(_build_snapshot);
    var ranked = [];
    for (var slot_i = 0; slot_i < array_length(_build_snapshot); slot_i++) {
        if (is_undefined(_build_snapshot[slot_i])) continue;
        var candidate = enemy_ai_score_candidate(evaluation_before, _build_snapshot, slot_i,
            ENEMY_AI_CONDITIONAL_WEIGHT, ENEMY_AI_HEALTH_WEIGHT);
        var inserted = false;
        for (var rank_i = 0; rank_i < array_length(ranked); rank_i++) {
            if (enemy_ai_candidate_ranks_before(candidate, ranked[rank_i])) {
                array_insert(ranked, rank_i, candidate);
                inserted = true;
                break;
            }
        }
        if (!inserted) array_push(ranked, candidate);
    }
    return ranked;
}

function enemy_ai_choose_target(_current_state) {
    if (!is_struct(_current_state)
    || !variable_struct_exists(_current_state, "build_snapshot")
    || !is_array(_current_state.build_snapshot)
    || !variable_struct_exists(_current_state, "attack_remaining")
    || !is_real(_current_state.attack_remaining)
    || _current_state.attack_remaining < 0) return -1;

    var ranked = enemy_ai_rank_build(_current_state.build_snapshot);
    for (var rank_i = 0; rank_i < array_length(ranked); rank_i++) {
        var slot = ranked[rank_i].slot;
        if (enemy_target_is_legal_in_build(_current_state.build_snapshot, slot,
        _current_state.attack_remaining)) return slot;
    }
    return -1;
}

function enemy_ai_cancel_pending_targeting() {
    enemy_ai_visual_stage = "";
    enemy_ai_visual_timer = 0;
    enemy_ai_selected_slot = -1;
    enemy_ai_pending_card = undefined;
    enemy_ai_pending_prompt_id = -1;
    enemy_ai_pending_attack = 0;
    enemy_ai_pending_source = "";
}

function enemy_ai_pending_target_is_current() {
    return enemy_auto_play && !setup_active && !game_over && !match_menu_active
        && enemy_ai_visual_stage == "targeting"
        && prompt_mode == "enemy_attack"
        && enemy_attack_prompt_id == enemy_ai_pending_prompt_id
        && prompt_value == enemy_ai_pending_attack
        && prompt_source == enemy_ai_pending_source
        && enemy_ai_selected_slot >= 0
        && enemy_ai_selected_slot < array_length(build)
        && !is_undefined(build[enemy_ai_selected_slot])
        && build[enemy_ai_selected_slot] == enemy_ai_pending_card
        && enemy_target_is_legal(enemy_ai_selected_slot, prompt_value);
}

function enemy_ai_schedule_current_target() {
    if (!enemy_auto_play || prompt_mode != "enemy_attack" || setup_active
    || game_over || match_menu_active || enemy_ai_visual_stage != "") return false;

    var current_state = {
        build_snapshot: copy_build_snapshot(build),
        attack_remaining: prompt_value
    };
    var selected_slot = enemy_ai_choose_target(current_state);
    if (selected_slot < 0) return command_end_enemy_attack_if_blocked();
    enemy_ai_visual_stage = "targeting";
    enemy_ai_visual_timer = ENEMY_AI_TARGET_DELAY_FRAMES;
    enemy_ai_selected_slot = selected_slot;
    enemy_ai_pending_card = build[selected_slot];
    enemy_ai_pending_prompt_id = enemy_attack_prompt_id;
    enemy_ai_pending_attack = prompt_value;
    enemy_ai_pending_source = prompt_source;
    return true;
}

function enemy_ai_submit_current_target() {
    if (!enemy_ai_pending_target_is_current()) {
        enemy_ai_cancel_pending_targeting();
        return false;
    }
    var selected_slot = enemy_ai_selected_slot;
    enemy_ai_cancel_pending_targeting();
    var submitted = command_prompt_build(selected_slot);
    enemy_ai_visual_stage = "result";
    enemy_ai_visual_timer = ENEMY_AI_RESULT_DELAY_FRAMES;
    return submitted;
}

function enemy_ai_update_auto_targeting() {
    if (enemy_ai_visual_stage == "targeting") {
        if (!enemy_ai_pending_target_is_current()) {
            enemy_ai_cancel_pending_targeting();
            return true;
        }
        enemy_ai_visual_timer--;
        if (enemy_ai_visual_timer <= 0) enemy_ai_submit_current_target();
        return true;
    }
    if (enemy_ai_visual_stage == "result") {
        if (!enemy_auto_play || setup_active || game_over || match_menu_active) {
            enemy_ai_cancel_pending_targeting();
            return true;
        }
        enemy_ai_visual_timer--;
        if (enemy_ai_visual_timer <= 0) enemy_ai_cancel_pending_targeting();
        return true;
    }
    if (enemy_auto_play && prompt_mode == "enemy_attack") {
        enemy_ai_schedule_current_target();
        return true;
    }
    return false;
}

// Development-only oracle helpers. Production Auto targeting never calls these functions.
function enemy_ai_oracle_sequence_value(_initial_evaluation, _final_snapshot) {
    var final_evaluation = evaluate_build(_final_snapshot);
    var guaranteed_removed = _initial_evaluation.guaranteed_attack
        - final_evaluation.guaranteed_attack;
    var conditional_removed = _initial_evaluation.conditional_attack
        - final_evaluation.conditional_attack;
    return guaranteed_removed + ENEMY_AI_CONDITIONAL_WEIGHT * conditional_removed;
}

function enemy_ai_copy_sequence(_source_sequence) {
    var copied_sequence = [];
    for (var sequence_i = 0; sequence_i < array_length(_source_sequence); sequence_i++) {
        array_push(copied_sequence, _source_sequence[sequence_i]);
    }
    return copied_sequence;
}

function enemy_ai_oracle_sequence_ranks_before(_left, _right) {
    var shared_length = min(array_length(_left), array_length(_right));
    for (var sequence_i = 0; sequence_i < shared_length; sequence_i++) {
        if (_left[sequence_i] != _right[sequence_i]) return _left[sequence_i] < _right[sequence_i];
    }
    return array_length(_left) < array_length(_right);
}

function enemy_ai_oracle_search(_initial_evaluation, _build_snapshot, _attack_remaining, _sequence) {
    var best_result = undefined;
    for (var slot_i = 0; slot_i < array_length(_build_snapshot); slot_i++) {
        if (!enemy_target_is_legal_in_build(_build_snapshot, slot_i, _attack_remaining)) continue;
        var next_attack = _attack_remaining - _build_snapshot[slot_i].hp;
        var next_snapshot = copy_build_without_slot(_build_snapshot, slot_i);
        var next_sequence = enemy_ai_copy_sequence(_sequence);
        array_push(next_sequence, slot_i);
        var candidate = enemy_ai_oracle_search(_initial_evaluation, next_snapshot,
            next_attack, next_sequence);
        if (is_undefined(best_result)
        || candidate.sequence_value > best_result.sequence_value
        || (enemy_ai_scores_are_close(candidate.sequence_value, best_result.sequence_value)
            && enemy_ai_oracle_sequence_ranks_before(candidate.sequence, best_result.sequence))) {
            best_result = candidate;
        }
    }
    if (!is_undefined(best_result)) return best_result;
    return {
        sequence: enemy_ai_copy_sequence(_sequence),
        sequence_value: enemy_ai_oracle_sequence_value(_initial_evaluation, _build_snapshot),
        final_snapshot: copy_build_snapshot(_build_snapshot),
        attack_remaining: _attack_remaining
    };
}

function enemy_ai_oracle_greedy_sequence(_build_snapshot, _attack_remaining) {
    var initial_evaluation = evaluate_build(_build_snapshot);
    var simulated_build = copy_build_snapshot(_build_snapshot);
    var simulated_attack = _attack_remaining;
    var sequence = [];
    while (true) {
        var selected_slot = enemy_ai_choose_target({
            build_snapshot: simulated_build,
            attack_remaining: simulated_attack
        });
        if (selected_slot < 0) break;
        simulated_attack -= simulated_build[selected_slot].hp;
        simulated_build = copy_build_without_slot(simulated_build, selected_slot);
        array_push(sequence, selected_slot);
    }
    return {
        sequence: sequence,
        sequence_value: enemy_ai_oracle_sequence_value(initial_evaluation, simulated_build),
        final_snapshot: simulated_build,
        attack_remaining: simulated_attack
    };
}

function enemy_ai_oracle_compare(_build_snapshot, _attack_remaining) {
    var oracle_snapshot = copy_build_snapshot(_build_snapshot);
    var initial_evaluation = evaluate_build(oracle_snapshot);
    var greedy_result = enemy_ai_oracle_greedy_sequence(oracle_snapshot, _attack_remaining);
    var exhaustive_result = enemy_ai_oracle_search(initial_evaluation, oracle_snapshot,
        _attack_remaining, []);
    return {
        greedy_sequence: greedy_result.sequence,
        best_exhaustive_sequence: exhaustive_result.sequence,
        greedy_sequence_value: greedy_result.sequence_value,
        best_exhaustive_sequence_value: exhaustive_result.sequence_value,
        greedy_regret: exhaustive_result.sequence_value - greedy_result.sequence_value
    };
}

function enemy_ai_scores_are_close(_left, _right) {
    return abs(_left - _right) < 0.0001;
}

function enemy_ai_run_scoring_self_checks(_hero_definitions) {
    var goblin = find_hero_definition(_hero_definitions, "goblin");
    var skeleton = find_hero_definition(_hero_definitions, "skeleton");
    var orc = find_hero_definition(_hero_definitions, "orc");
    if (is_undefined(goblin) || is_undefined(skeleton) || is_undefined(orc)) {
        return content_validation_result(false, "Enemy AI scoring checks require the core Heroes.");
    }

    var ranked = enemy_ai_rank_build([goblin.normal, skeleton.normal, orc.normal]);
    if (array_length(ranked) != 3 || ranked[0].slot != 0 || ranked[1].slot != 1
    || ranked[2].slot != 2 || !enemy_ai_scores_are_close(ranked[0].score, 2)) {
        return content_validation_result(false, "Enemy AI basic scoring check failed.");
    }

    ranked = enemy_ai_rank_build([goblin.ability, skeleton.normal, undefined]);
    if (array_length(ranked) != 2 || ranked[0].slot != 0
    || !enemy_ai_scores_are_close(ranked[0].guaranteed_threat, 4)
    || !enemy_ai_scores_are_close(ranked[0].conditional_threat, 2)
    || !enemy_ai_scores_are_close(ranked[0].score, 3)) {
        return content_validation_result(false, "Enemy AI conditional scoring check failed.");
    }

    ranked = enemy_ai_rank_build([skeleton.ability, goblin.normal, orc.normal]);
    if (array_length(ranked) != 3 || ranked[0].slot != 1
    || ranked[1].slot != 0 || ranked[2].slot != 2) {
        return content_validation_result(false, "Enemy AI Build-synergy scoring check failed.");
    }

    ranked = enemy_ai_rank_build([goblin.normal, goblin.normal, undefined]);
    if (array_length(ranked) != 2 || ranked[0].slot != 0 || ranked[1].slot != 1) {
        return content_validation_result(false, "Enemy AI stable-slot tie-break check failed.");
    }

    var lower_health = card_player("test_a", "Test A", "Ability", 4, 3,
        [ability_entry(ABILITY_OVERPOWER, "Test", "", {amount:2})], "", "", 0);
    var higher_health = card_player("test_b", "Test B", "Ability", 4, 4,
        [ability_entry(ABILITY_OVERPOWER, "Test", "", {amount:4})], "", "", 0);
    ranked = enemy_ai_rank_build([higher_health, lower_health, undefined]);
    if (array_length(ranked) != 2 || ranked[0].slot != 1
    || !enemy_ai_scores_are_close(ranked[0].score, ranked[1].score)
    || !enemy_ai_scores_are_close(ranked[0].guaranteed_threat, ranked[1].guaranteed_threat)) {
        return content_validation_result(false, "Enemy AI Health tie-break check failed.");
    }

    return content_validation_result(true, "");
}

function enemy_ai_run_selection_self_checks(_hero_definitions) {
    var goblin = find_hero_definition(_hero_definitions, "goblin");
    var skeleton = find_hero_definition(_hero_definitions, "skeleton");
    var orc = find_hero_definition(_hero_definitions, "orc");
    if (is_undefined(goblin) || is_undefined(skeleton) || is_undefined(orc)) {
        return content_validation_result(false, "Enemy AI selection checks require the core Heroes.");
    }

    var state = {
        build_snapshot: [goblin.normal, skeleton.normal, orc.normal],
        attack_remaining: 10
    };
    if (enemy_ai_choose_target(state) != 0) {
        return content_validation_result(false, "Enemy AI preferred-target selection check failed.");
    }

    state.attack_remaining = 2;
    if (enemy_ai_choose_target(state) != -1) {
        return content_validation_result(false, "Enemy AI no-destroyable-target check failed.");
    }

    state.build_snapshot = [goblin.normal, skeleton.normal, orc.ability];
    state.attack_remaining = 10;
    if (enemy_ai_choose_target(state) != 2) {
        return content_validation_result(false, "Enemy AI Guard-priority selection check failed.");
    }

    state.build_snapshot = [goblin.normal, skeleton.normal, orc.special];
    state.attack_remaining = 7;
    if (enemy_ai_choose_target(state) != -1) {
        return content_validation_result(false, "Enemy AI undestroyable-priority check failed.");
    }

    var expensive_threat = card_player("test_threat", "Test Threat", "Normal", 20, 10,
        [], "", "", 0);
    state.build_snapshot = [expensive_threat, goblin.normal, undefined];
    state.attack_remaining = 5;
    if (enemy_ai_choose_target(state) != 1) {
        return content_validation_result(false, "Enemy AI valid-ranked-fallback check failed.");
    }

    state.build_snapshot = [undefined, undefined, undefined];
    if (enemy_ai_choose_target(state) != -1 || enemy_ai_choose_target(undefined) != -1) {
        return content_validation_result(false, "Enemy AI empty-state selection check failed.");
    }

    return content_validation_result(true, "");
}

function enemy_ai_run_oracle_self_checks(_hero_definitions) {
    var goblin = find_hero_definition(_hero_definitions, "goblin");
    var skeleton = find_hero_definition(_hero_definitions, "skeleton");
    var orc = find_hero_definition(_hero_definitions, "orc");
    if (is_undefined(goblin) || is_undefined(skeleton) || is_undefined(orc)) {
        return content_validation_result(false, "Enemy AI oracle checks require the core Heroes.");
    }

    var original_snapshot = [goblin.normal, skeleton.normal, orc.normal];
    var result = enemy_ai_oracle_compare(original_snapshot, 12);
    if (!enemy_ai_scores_are_close(result.greedy_sequence_value,
    result.best_exhaustive_sequence_value) || !enemy_ai_scores_are_close(result.greedy_regret, 0)
    || is_undefined(original_snapshot[0]) || is_undefined(original_snapshot[1])
    || is_undefined(original_snapshot[2])) {
        return content_validation_result(false, "Enemy AI oracle baseline/snapshot check failed.");
    }

    var greedy_card = card_player("oracle_a", "Oracle A", "Normal", 8, 4, [], "", "", 0);
    var pair_card_b = card_player("oracle_b", "Oracle B", "Normal", 6, 3, [], "", "", 0);
    var pair_card_c = card_player("oracle_c", "Oracle C", "Normal", 6, 3, [], "", "", 0);
    result = enemy_ai_oracle_compare([greedy_card, pair_card_b, pair_card_c], 6);
    if (array_length(result.greedy_sequence) != 1 || result.greedy_sequence[0] != 0
    || array_length(result.best_exhaustive_sequence) != 2
    || result.best_exhaustive_sequence[0] != 1 || result.best_exhaustive_sequence[1] != 2
    || !enemy_ai_scores_are_close(result.greedy_sequence_value, 8)
    || !enemy_ai_scores_are_close(result.best_exhaustive_sequence_value, 12)
    || !enemy_ai_scores_are_close(result.greedy_regret, 4)) {
        return content_validation_result(false, "Enemy AI oracle regret check failed.");
    }

    result = enemy_ai_oracle_compare([goblin.normal, skeleton.normal, orc.ability], 9);
    if (array_length(result.best_exhaustive_sequence) < 1
    || result.best_exhaustive_sequence[0] != 2) {
        return content_validation_result(false, "Enemy AI oracle priority check failed.");
    }

    result = enemy_ai_oracle_compare([goblin.ability, undefined, undefined], 2);
    if (!enemy_ai_scores_are_close(result.greedy_sequence_value, 5)
    || !enemy_ai_scores_are_close(result.best_exhaustive_sequence_value, 5)) {
        return content_validation_result(false, "Enemy AI oracle conditional-value check failed.");
    }

    result = enemy_ai_oracle_compare([undefined, undefined, undefined], 10);
    if (array_length(result.greedy_sequence) != 0
    || array_length(result.best_exhaustive_sequence) != 0
    || !enemy_ai_scores_are_close(result.greedy_regret, 0)) {
        return content_validation_result(false, "Enemy AI oracle empty-Build check failed.");
    }

    return content_validation_result(true, "");
}

function enemy_ai_run_release_self_checks() {
    if (!enemy_ai_scores_are_close(ENEMY_AI_CONDITIONAL_WEIGHT, 0.5)
    || !enemy_ai_scores_are_close(ENEMY_AI_HEALTH_WEIGHT, 1.0)
    || ENEMY_AI_TARGET_DELAY_FRAMES <= 0 || ENEMY_AI_RESULT_DELAY_FRAMES <= 0) {
        return content_validation_result(false, "Enemy AI deterministic release constants are invalid.");
    }
    var manual_settings = vv_settings_decode("{\"settings_version\":1,\"enemy_targeting_mode\":\"manual\"}");
    var auto_settings = vv_settings_decode("{\"settings_version\":1,\"enemy_targeting_mode\":\"auto\"}");
    var corrupt_settings = vv_settings_decode("not valid json");
    if (!manual_settings.valid || manual_settings.enemy_auto_play
    || !auto_settings.valid || !auto_settings.enemy_auto_play
    || corrupt_settings.valid || corrupt_settings.enemy_auto_play) {
        return content_validation_result(false, "Enemy AI settings recovery release check failed.");
    }

    var previous_seed = random_get_seed();
    random_set_seed(18427);
    var first_shuffle = array_shuffle_copy([0, 1, 2, 3, 4, 5, 6, 7]);
    random_set_seed(18427);
    var second_shuffle = array_shuffle_copy([0, 1, 2, 3, 4, 5, 6, 7]);
    random_set_seed(previous_seed);
    for (var shuffle_i = 0; shuffle_i < array_length(first_shuffle); shuffle_i++) {
        if (first_shuffle[shuffle_i] != second_shuffle[shuffle_i]) {
            return content_validation_result(false, "Enemy AI seeded-playtest release check failed.");
        }
    }
    return content_validation_result(true, "");
}
