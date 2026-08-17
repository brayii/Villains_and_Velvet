/// Deterministic Enemy AI scoring. This module ranks Build slots but does not resolve attacks.

#macro ENEMY_AI_CONDITIONAL_WEIGHT 0.5
#macro ENEMY_AI_HEALTH_WEIGHT 1.0

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
