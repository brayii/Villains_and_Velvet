/// Controlled first-battle training. Normal setup selections are restored afterward.

enum TutorialStep {
    Intro, T1_StartTurn, T1_HoldHero, T1_InspectOpen, T1_InspectClose,
    T1_Step2Watch, T1_Step2Result, T1_CorgiReveal, T1_CorgiEntryWatch,
    T1_CorgiEntryResult, T1_DragHero1, T1_DragHero2, T1_DragHero3,
    T1_BuildReady, T1_AttackLeader, T1_AttackLeaderResult, T1_DiscardResult,
    T1_EndResult, T2_StartTurn, T2_DrawResult, T2_CorgiAdvanceWatch,
    T2_CorgiAdvanceResult, T2_DirectAssaultRead, T2_DirectAssaultWatch,
    T2_DirectAssaultResult, T2_EventDrawRule, T2_RedPandaEntryWatch,
    T2_RedPandaAttackWatch, T2_RedPandaAttackResult, T2_Rebuild1,
    T2_Rebuild2, T2_Rebuild3, T2_BuildReady, T2_NotEnoughAttack,
    T2_DoneAttacking, T2_ConfirmEnd, T2_BothMinionsRemainResult,
    T2_EndResult, T3_StartTurn, T3_PreEscapeReason, T3_AdvanceWatch,
    T3_Area2Full, T3_PushWatch, T3_EscapeResult, T3_EscapeEffectRead,
    T3_EscapeEffectWatch, T3_EscapeEffectResult, T3_AdvanceResult,
    T3_ReinforcementsRead, T3_ReinforcementsWatch, T3_ReinforcementsResult,
    T3_EventDrawReminder, T3_BunnyEntryWatch, T3_BunnyAttackWatch,
    T3_BunnyAttackResult, T3_Rebuild, T3_BuildReady, T3_AttackBunny,
    T3_AttackBunnyResult, T3_AttackLeader, T3_AttackLeaderResult,
    T3_DiscardWatch, T3_DiscardResult, T3_EndResult, Complete
}

function vv_tutorial_profile() {
    return {
        leader_id:"velvet_queen",
        scenario_id:"the_assault",
        minion_set_id:"velvet_menagerie",
        hero_ids:["goblin", "skeleton", "orc"],
        hero_kinds:["Normal", "Normal", "Ability"]
    };
}

function vv_tutorial_init() {
    tutorial_mode = false;
    tutorial_saved_setup = undefined;
    tutorial_escape_seen = false;
    tutorial_minion_defeated = false;
    tutorial_leader_attacked = false;
    tutorial_final_leader_attacked = false;
    tutorial_complete_prompt = false;
    tutorial_entry_notice_timer = 0;
    tutorial_move_notice_timer = 0;
    tutorial_step = TutorialStep.Intro;
    tutorial_pause = false;
    tutorial_heading = "";
    tutorial_body = "";
    tutorial_message_kind = "";
    tutorial_pending_enemy_card = undefined;
    tutorial_destroyed_cards = [];
    tutorial_enemy_attack_remaining = 0;
    tutorial_heal_before = 0;
    tutorial_heal_after = 0;
    tutorial_last_attack = 0;
    tutorial_pending_action = "";
    tutorial_pending_frames = 0;
    tutorial_pending_escape = undefined;
}

function vv_tutorial_schedule(_step, _body, _action) {
    vv_tutorial_set_state(_step, "watch", "WATCH", _body, false);
    tutorial_pending_action = _action;
    tutorial_pending_frames = max(VV_TUTORIAL_WATCH_FRAMES, room_speed);
    auto_timer = 0;
}

function vv_tutorial_update() {
    if (!tutorial_mode || tutorial_pending_action == "") return;
    if (tutorial_pending_frames > 0) { tutorial_pending_frames--; return; }
    var action = tutorial_pending_action;
    tutorial_pending_action = "";
    if (action == "step2") do_step_2();
    else if (action == "step3") do_step_3();
    else if (action == "enemy_draw") draw_next_enemy_card();
    else if (action == "finish_turn") finish_turn();
    else if (action == "entry") continue_minion_entry();
    else if (action == "escape") {
        var escaping = tutorial_pending_escape;
        tutorial_pending_escape = undefined;
        resolve_minion_escape(escaping);
    }
}

function vv_tutorial_set_state(_step, _kind, _heading, _body, _pause) {
    tutorial_step = _step;
    tutorial_message_kind = _kind;
    tutorial_heading = _heading;
    tutorial_body = _body;
    tutorial_pause = _pause;
}

function vv_tutorial_blocks_automatic_progress() {
    return tutorial_mode && tutorial_pause;
}

function vv_tutorial_blocks_player_input() {
    return tutorial_mode && tutorial_message_kind == "watch";
}

function vv_tutorial_action_allowed() {
    if (!tutorial_mode) return true;
    if (turn_number == 2) {
        if (phase == "step1_ready") return tutorial_step == TutorialStep.T2_StartTurn;
        if (phase == "build") return tutorial_step == TutorialStep.T2_BuildReady;
        if (phase == "attack") return tutorial_step == TutorialStep.T2_DoneAttacking
            || tutorial_step == TutorialStep.T2_ConfirmEnd;
        return true;
    }
    if (turn_number == 3) {
        if (phase == "step1_ready") return tutorial_step == TutorialStep.T3_StartTurn;
        if (phase == "step3_ready") return tutorial_step == TutorialStep.T3_ReinforcementsRead;
        if (phase == "build") return tutorial_step == TutorialStep.T3_BuildReady;
        if (phase == "end_ready") return tutorial_step == TutorialStep.T3_EndResult;
        return true;
    }
    if (turn_number != 1) return true;
    if (phase == "step1_ready") return tutorial_step == TutorialStep.T1_StartTurn;
    if (phase == "step2_ready") return tutorial_step == TutorialStep.T1_InspectClose;
    if (phase == "step3_ready") return tutorial_step == TutorialStep.T1_CorgiReveal;
    if (phase == "build") return tutorial_step == TutorialStep.T1_BuildReady;
    return true;
}

function vv_tutorial_build_drop_allowed(_source_area, _source_index, _target_area, _target_index) {
    if (!tutorial_mode) return true;
    if (turn_number == 2) {
        var expected2 = count_occupied_build();
        return _source_area == "hand" && _target_area == "build"
            && _source_index == expected2 && _target_index == expected2;
    }
    if (turn_number == 3) {
        if (_source_area != "hand" || _target_area != "build") return false;
        return !is_undefined(hand[_source_index]) && hand[_source_index].hero == "goblin"
            && is_undefined(build[_target_index]);
    }
    if (turn_number != 1) return true;
    var expected = count_occupied_build();
    return _source_area == "hand" && _target_area == "build"
        && _source_index == expected && _target_index == expected;
}

function vv_tutorial_requires_drag() {
    if (!tutorial_mode) return false;
    return tutorial_step == TutorialStep.T1_DragHero1 || tutorial_step == TutorialStep.T1_DragHero2
        || tutorial_step == TutorialStep.T1_DragHero3 || tutorial_step == TutorialStep.T2_Rebuild1
        || tutorial_step == TutorialStep.T2_Rebuild2 || tutorial_step == TutorialStep.T2_Rebuild3
        || tutorial_step == TutorialStep.T3_Rebuild;
}

function vv_tutorial_build_attack_equation() {
    var equation = "";
    for (var build_i = 0; build_i < array_length(build); build_i++) {
        if (is_undefined(build[build_i])) continue;
        if (equation != "") equation += " + ";
        equation += string(build[build_i].atk);
    }
    return equation + " = " + string(compute_attack_summary().total) + " BUILD ATTACK";
}

function vv_tutorial_enemy_target_for(_tutorial_turn, _build_snapshot, _attack_remaining, _source) {
    // Training controls only which legal target is chosen. Damage, priority,
    // remaining Attack, and destruction still use the normal combat commands.
    if (_tutorial_turn == 2 && string_pos("Direct Assault", _source) > 0) {
        for (var guard_i = 0; guard_i < array_length(_build_snapshot); guard_i++) {
            if (!is_undefined(_build_snapshot[guard_i])
            && card_has_ability(_build_snapshot[guard_i], ABILITY_GUARD)
            && enemy_target_is_legal_in_build(_build_snapshot, guard_i, _attack_remaining)) return guard_i;
        }
    }
    if (_tutorial_turn == 2 && string_pos("Red Panda", _source) > 0) {
        var lowest_i = -1;
        var lowest_hp = 9999;
        for (var old_i = 0; old_i < array_length(_build_snapshot); old_i++) {
            if (enemy_target_is_legal_in_build(_build_snapshot, old_i, _attack_remaining)
            && _build_snapshot[old_i].hp < lowest_hp) {
                lowest_hp = _build_snapshot[old_i].hp;
                lowest_i = old_i;
            }
        }
        return lowest_i;
    }
    if (_tutorial_turn == 3 && string_pos("Reinforcements", _source) > 0) {
        for (var fortress_i = 0; fortress_i < array_length(_build_snapshot); fortress_i++) {
            if (!is_undefined(_build_snapshot[fortress_i])
            && card_has_ability(_build_snapshot[fortress_i], ABILITY_FORTRESS)
            && enemy_target_is_legal_in_build(_build_snapshot, fortress_i, _attack_remaining)) return fortress_i;
        }
    }
    return -1;
}

function vv_tutorial_enemy_target(_build_snapshot, _attack_remaining, _source) {
    return tutorial_mode
        ? vv_tutorial_enemy_target_for(turn_number, _build_snapshot, _attack_remaining, _source)
        : -1;
}

function vv_tutorial_continue() {
    if (!tutorial_mode || !tutorial_pause) return false;
    switch (tutorial_step) {
        case TutorialStep.Intro:
            vv_tutorial_set_state(TutorialStep.T1_StartTurn, "action", "YOUR ACTION",
                "Tap START TURN to draw\n3 Hero cards.", false);
            return true;
        case TutorialStep.T1_InspectClose:
            vv_tutorial_schedule(TutorialStep.T1_Step2Watch,
                "Step 2 happens automatically.\nArea 1 is empty, so nothing moves.", "step2");
            return true;
        case TutorialStep.T1_Step2Result:
            vv_tutorial_schedule(TutorialStep.T1_CorgiReveal,
                "The Enemy now draws until a Minion appears.", "step3");
            return true;
        case TutorialStep.T1_CorgiEntryResult:
            begin_build();
            vv_tutorial_set_state(TutorialStep.T1_DragHero1, "action", "YOUR ACTION",
                "Drag the glowing Hero into the glowing Build space.", false);
            return true;
        case TutorialStep.T1_AttackLeaderResult:
            vv_tutorial_set_state(TutorialStep.T1_DiscardResult, "watch", "WATCH",
                "Step 6 now discards every card still in your Hand.", false);
            return true;
        case TutorialStep.T1_DiscardResult:
            vv_tutorial_schedule(TutorialStep.T1_EndResult,
                "Step 7 ends the turn automatically.\nYour Build cards stay in play.", "finish_turn");
            return true;
        case TutorialStep.T2_DrawResult:
            vv_tutorial_schedule(TutorialStep.T2_CorgiAdvanceWatch,
                "Step 2 happens automatically.\nCorgi moves from Area 1 to Area 2.", "step2");
            return true;
        case TutorialStep.T2_CorgiAdvanceResult:
            vv_tutorial_schedule(TutorialStep.T2_DirectAssaultRead,
                "The Enemy now draws a card.", "step3");
            return true;
        case TutorialStep.T2_DirectAssaultRead:
            var strike = tutorial_pending_enemy_card;
            tutorial_pending_enemy_card = undefined;
            vv_tutorial_set_state(TutorialStep.T2_DirectAssaultWatch, "watch", "WATCH",
                "The Queen attacks. Guard must be targeted first.", false);
            resolve_leader_strike(strike);
            resume_action = "continue_enemy_draw";
            resume_after_prompts();
            return true;
        case TutorialStep.T2_DirectAssaultResult:
            tutorial_destroyed_cards = [];
            vv_tutorial_set_state(TutorialStep.T2_EventDrawRule, "tip", "TIP",
                "Enemy Event cards resolve, then Enemy Draw continues until a Minion appears.", true);
            return true;
        case TutorialStep.T2_EventDrawRule:
            vv_tutorial_schedule(TutorialStep.T2_RedPandaEntryWatch,
                "Enemy Draw continues until a Minion appears.", "enemy_draw");
            return true;
        case TutorialStep.T2_RedPandaAttackResult:
            begin_build();
            vv_tutorial_set_state(TutorialStep.T2_Rebuild1, "action", "YOUR ACTION",
                "Rebuild with the glowing Guard card.", false);
            return true;
        case TutorialStep.T2_BothMinionsRemainResult:
            vv_tutorial_set_state(TutorialStep.T2_EndResult, "watch", "WATCH",
                "Step 6 discards cards left in Hand before the turn ends.", false);
            return true;
        case TutorialStep.T2_EndResult:
            vv_tutorial_schedule(TutorialStep.T2_EndResult,
                "Step 7 ends the turn automatically.", "finish_turn");
            return true;
        case TutorialStep.T3_PreEscapeReason:
            vv_tutorial_schedule(TutorialStep.T3_AdvanceWatch,
                "Step 2 happens automatically.\nRed Panda advances toward occupied Area 2.", "step2");
            return true;
        case TutorialStep.T3_Area2Full:
            vv_tutorial_set_state(TutorialStep.T3_PushWatch, "watch", "WATCH",
                "Red Panda pushes Corgi out of Area 2 and into the escape portal.\n\nContinue after watching the escape.", true);
            vv_feedback_add_tutorial_push_fx(tutorial_pending_escape, advance_incoming_minion);
            return true;
        case TutorialStep.T3_PushWatch:
            if (!vv_feedback_tutorial_push_ready()) return false;
            vv_tutorial_set_state(TutorialStep.T3_EscapeResult, "result", "RESULT",
                "Corgi escaped because Red Panda pushed it out of Area 2. A Minion never escapes merely by waiting there.", true);
            return true;
        case TutorialStep.T3_EscapeResult:
            vv_tutorial_set_state(TutorialStep.T3_EscapeEffectRead, "read", "READ THIS CARD",
                "Corgi's Escape effect heals the Enemy Leader. Escape effects happen after the Minion is pushed out.", true);
            return true;
        case TutorialStep.T3_EscapeEffectRead:
            vv_tutorial_schedule(TutorialStep.T3_EscapeEffectWatch,
                "Corgi's Escape effect now heals the Enemy Leader.", "escape");
            return true;
        case TutorialStep.T3_EscapeEffectResult:
            vv_tutorial_set_state(TutorialStep.T3_AdvanceResult, "result", "RESULT",
                "Red Panda now occupies Area 2. Area 1 is empty and ready for the next Minion.", true);
            return true;
        case TutorialStep.T3_AdvanceResult:
            vv_tutorial_schedule(TutorialStep.T3_ReinforcementsRead,
                "The Enemy now draws a card.\nThe next Event shows why Area 2 matters.", "step3");
            return true;
        case TutorialStep.T3_ReinforcementsRead:
            if (!is_undefined(tutorial_pending_enemy_card)) {
                var twist = tutorial_pending_enemy_card;
                tutorial_pending_enemy_card = undefined;
                vv_tutorial_set_state(TutorialStep.T3_ReinforcementsWatch, "watch", "WATCH",
                    "Reinforcements makes Red Panda attack from Area 2. It must target Guard or Fortress first.", false);
                resolve_twist(twist);
                resume_action = "continue_enemy_draw";
                resume_after_prompts();
            }
            return true;
        case TutorialStep.T3_ReinforcementsResult:
            vv_tutorial_set_state(TutorialStep.T3_EventDrawReminder, "tip", "TIP",
                "The Event resolved. Enemy Draw continues until a Minion appears.", true);
            return true;
        case TutorialStep.T3_EventDrawReminder:
            vv_tutorial_schedule(TutorialStep.T3_BunnyEntryWatch,
                "Enemy Draw continues until a Minion appears.", "enemy_draw");
            return true;
        case TutorialStep.T3_BunnyAttackResult:
            begin_build();
            vv_tutorial_set_state(TutorialStep.T3_Rebuild, "action", "YOUR ACTION",
                "One Build space is open. Drag the glowing Goblin into it.", false);
            return true;
        case TutorialStep.T3_AttackBunnyResult:
            vv_tutorial_set_state(TutorialStep.T3_AttackLeader, "action", "YOUR ACTION",
                "Bunny is defeated. Use your remaining " + string(attack_left)
                    + " Attack on the Leader.", false);
            return true;
        case TutorialStep.T3_AttackLeaderResult:
            vv_tutorial_set_state(TutorialStep.T3_DiscardWatch, "watch", "WATCH",
                "Step 6 discards the cards still in your Hand.", false);
            return true;
        case TutorialStep.T3_DiscardResult:
            vv_tutorial_schedule(TutorialStep.T3_EndResult,
                "Step 7 ends the turn automatically.\nTraining is nearly complete.", "finish_turn");
            return true;
    }
    return false;
}

function vv_tutorial_pause_event_card(_card) {
    if (!tutorial_mode) return false;
    if (turn_number == 2 && _card.id == "direct_assault") {
        tutorial_pending_enemy_card = _card;
        vv_tutorial_set_state(TutorialStep.T2_DirectAssaultRead, "read", "READ THIS CARD",
            "Leader Strikes come from the Enemy Leader.\n\nDIRECT ASSAULT\n"
                + enemy_leader.name + " attacks for " + string(enemy_leader.attack)
                + ".\n\nContinue to watch it happen.", true);
        return true;
    }
    if (turn_number == 3 && _card.id == "reinforcements") {
        tutorial_pending_enemy_card = _card;
        vv_tutorial_set_state(TutorialStep.T3_ReinforcementsRead, "read", "READ THIS CARD",
            "Twists come from the selected Scenario.\n\nREINFORCEMENTS\nThe Minion in Area 2 attacks.\n\nContinue to watch it happen.", true);
        return true;
    }
    return false;
}

function vv_tutorial_resume_intercept(_action) {
    if (!tutorial_mode) return false;
    if (_action == "continue_enemy_draw" && tutorial_step == TutorialStep.T2_DirectAssaultWatch) {
        resume_action = "";
        var strike_destroyed = array_length(tutorial_destroyed_cards) > 0
            ? tutorial_destroyed_cards[0] : "the Guard card";
        vv_tutorial_set_state(TutorialStep.T2_DirectAssaultResult, "result", "RESULT",
            "Direct Assault defeated " + strike_destroyed + " first. The remaining "
                + string(tutorial_enemy_attack_remaining) + " Attack could not defeat another Hero.", true);
        return true;
    }
    if (_action == "continue_enemy_draw" && tutorial_step == TutorialStep.T3_ReinforcementsWatch) {
        resume_action = "";
        var twist_destroyed = array_length(tutorial_destroyed_cards) > 0
            ? tutorial_destroyed_cards[array_length(tutorial_destroyed_cards) - 1] : "one priority Hero";
        vv_tutorial_set_state(TutorialStep.T3_ReinforcementsResult, "result", "RESULT",
            minions[0].name + " attacked from Area 2 and defeated " + twist_destroyed
                + ". Its full " + string(minions[0].atk) + " Attack was spent on that card.", true);
        return true;
    }
    return false;
}

function vv_tutorial_card_inspected(_opened) {
    if (!tutorial_mode) return;
    if (_opened && tutorial_step == TutorialStep.T1_HoldHero) {
        vv_tutorial_set_state(TutorialStep.T1_InspectOpen, "tip", "READ THIS CARD",
            "The enlarged card shows its Attack, Health, and ability. Tap outside it when you are ready.", false);
    } else if (!_opened && tutorial_step == TutorialStep.T1_InspectOpen) {
        vv_tutorial_set_state(TutorialStep.T1_InspectClose, "result", "READY",
            "You can inspect cards this way during battle. Continue to Step 2.", true);
    }
}

function vv_tutorial_after_player_draw() {
    if (!tutorial_mode) return;
    if (turn_number == 2) {
        auto_timer = 0;
        vv_tutorial_set_state(TutorialStep.T2_DrawResult, "result", "RESULT",
            "You drew two Guards and one Fortress. Enemies must target a Guard or Fortress before any other Hero.", true);
        return;
    }
    if (turn_number == 3) {
        auto_timer = 0;
        vv_tutorial_set_state(TutorialStep.T3_PreEscapeReason, "result", "WHY THIS HAPPENED",
            "Last turn you had " + string(tutorial_last_attack) + " Attack.\n"
                + minions[0].name + " needed " + string(minions[0].hp) + " and "
                + minions[1].name + " needed " + string(minions[1].hp)
                + ".\nNeither could be defeated, so both stayed in play.\nNow both Minion Areas are occupied.", true);
        return;
    }
    if (turn_number != 1) return;
    auto_timer = 0;
    vv_tutorial_set_state(TutorialStep.T1_HoldHero, "action", "YOUR ACTION",
        "Press and hold the glowing Hero card to inspect it.", false);
}

function vv_tutorial_after_advance() {
    if (!tutorial_mode) return;
    if (turn_number == 1) vv_tutorial_set_state(TutorialStep.T1_Step2Result, "result", "RESULT",
        "Area 1 was empty, so no Minion advanced or escaped.", true);
    else if (turn_number == 2) vv_tutorial_set_state(TutorialStep.T2_CorgiAdvanceResult, "result", "RESULT",
        "Corgi moved to Area 2. A Minion in Area 2 escapes only when Area 1 pushes it out.", true);
    else if (turn_number == 3 && tutorial_step == TutorialStep.T3_EscapeEffectWatch) vv_tutorial_set_state(
        TutorialStep.T3_EscapeEffectResult, "result", "RESULT",
        "Corgi healed the Leader from " + string(tutorial_heal_before) + " to "
            + string(tutorial_heal_after) + " Health.", true);
}

function vv_tutorial_after_turn_end() {
    if (!tutorial_mode) return;
    if (turn_number == 2) vv_tutorial_set_state(TutorialStep.T2_StartTurn, "action", "YOUR ACTION",
        "Tap START NEXT TURN to begin Turn 2.", false);
    else if (turn_number == 3) vv_tutorial_set_state(TutorialStep.T3_StartTurn, "action", "YOUR ACTION",
        "Tap START NEXT TURN to begin Turn 3.", false);
    else if (turn_number == 4) {
        vv_tutorial_set_state(TutorialStep.Complete, "result", "TRAINING COMPLETE",
            "You are ready for a real battle.", true);
        tutorial_complete_prompt = true;
    }
}

function vv_tutorial_note_destroyed_build_card(_card) {
    if (tutorial_mode && !is_undefined(_card)) array_push(tutorial_destroyed_cards,
        _card.name + " (" + string(_card.hp) + " Health)");
}

function vv_tutorial_note_enemy_attack_remaining(_amount) {
    if (tutorial_mode) tutorial_enemy_attack_remaining = max(0, _amount);
}

function vv_tutorial_after_attack_confirmation() {
    if (tutorial_mode && turn_number == 2) vv_tutorial_set_state(TutorialStep.T2_ConfirmEnd,
        "action", "YOUR ACTION", string(attack_left)
            + " Attack remains unused. Tap CONFIRM END to give it up.", false);
}

function vv_tutorial_after_hand_discard() {
    if (!tutorial_mode) return;
    auto_timer = 0;
    if (turn_number == 1) vv_tutorial_set_state(TutorialStep.T1_DiscardResult, "result", "RESULT",
        "Step 6 discarded every card left in Hand. Build cards remain in play.", true);
    else if (turn_number == 2) vv_tutorial_set_state(TutorialStep.T2_EndResult, "result", "RESULT",
        "Both Minions survived because " + string(tutorial_last_attack) + " Attack could not defeat "
            + string(minions[0].hp) + " or " + string(minions[1].hp)
            + " Health. Continue to end the turn.", true);
    else if (turn_number == 3) vv_tutorial_set_state(TutorialStep.T3_DiscardResult, "result", "RESULT",
        "Step 6 discarded the remaining Hand cards.", true);
}

function vv_tutorial_after_enemy_phase() {
    if (!tutorial_mode) return;
    if (turn_number == 1) vv_tutorial_set_state(TutorialStep.T1_CorgiEntryResult,
        "result", "RESULT", "Corgi entered Area 1 and attacked. Your Build was empty, so no Hero was lost.", true);
    else if (turn_number == 2) vv_tutorial_set_state(TutorialStep.T2_RedPandaAttackResult, "result", "RESULT",
        minions[1].name + " attacked for " + string(minions[1].atk)
            + " and defeated the two remaining Heroes. Enemy Attack is spent only on full defeats.", true);
    else if (turn_number == 3) vv_tutorial_set_state(TutorialStep.T3_BunnyAttackResult, "result", "RESULT",
        minions[1].name + " entered Area 1. Its " + string(minions[1].atk)
            + " Attack could not defeat Guard or Fortress, so it ended unused.", true);
}

function vv_tutorial_after_build_move() {
    if (!tutorial_mode) return;
    if (turn_number == 1) {
        var filled = count_occupied_build();
        if (filled == 1) vv_tutorial_set_state(TutorialStep.T1_DragHero2, "action", "YOUR ACTION",
            "Good! Heroes in your Build fight together. Their Attack values combine. Now drag the next Hero into the glowing space.", false);
        else if (filled == 2) vv_tutorial_set_state(TutorialStep.T1_DragHero3, "action", "YOUR ACTION", "Drag the final Hero into the glowing Build space.", false);
        else if (filled == 3) vv_tutorial_set_state(TutorialStep.T1_BuildReady, "action", "YOUR ACTION",
            vv_tutorial_build_attack_equation() + "\n\nTap DONE BUILDING.", false);
    } else if (turn_number == 2) {
        var filled2 = count_occupied_build();
        if (filled2 == 1) vv_tutorial_set_state(TutorialStep.T2_Rebuild2, "action", "YOUR ACTION", "Add the second Guard card.", false);
        else if (filled2 == 2) vv_tutorial_set_state(TutorialStep.T2_Rebuild3, "action", "YOUR ACTION", "Add Fortress to complete the protected Build.", false);
        else if (filled2 == 3) vv_tutorial_set_state(TutorialStep.T2_BuildReady, "action", "YOUR ACTION",
            "This Build has " + string(compute_attack_summary().total) + " Attack. Tap DONE BUILDING.", false);
    } else if (turn_number == 3 && count_occupied_build() == 3) {
        vv_tutorial_set_state(TutorialStep.T3_BuildReady, "action", "YOUR ACTION",
            "Your rebuilt team has " + string(compute_attack_summary().total) + " Attack. Tap DONE BUILDING.", false);
    }
}

function vv_tutorial_after_attack_started() {
    if (tutorial_mode && turn_number == 1) vv_tutorial_set_state(TutorialStep.T1_AttackLeader, "action", "YOUR ACTION",
        minions[1].name + " needs " + string(minions[1].hp)
            + " Attack, but first learn to strike the Leader. Tap the glowing Leader.", false);
    else if (tutorial_mode && turn_number == 2) {
        tutorial_last_attack = attack_left;
        vv_tutorial_set_state(TutorialStep.T2_NotEnoughAttack, "action", "YOUR ACTION",
            "You have " + string(attack_left) + " Attack. Tap either Minion to compare it with that Minion's Health.", false);
    }
    else if (tutorial_mode && turn_number == 3) vv_tutorial_set_state(TutorialStep.T3_AttackBunny, "action", "YOUR ACTION",
        "Tap " + minions[1].name + " in Area 1. It costs " + string(minions[1].hp)
            + " Attack to defeat.", false);
}

function vv_tutorial_after_failed_minion_attack() {
    if (tutorial_mode && turn_number == 2) vv_tutorial_set_state(TutorialStep.T2_DoneAttacking, "action", "YOUR ACTION",
        "Your " + string(attack_left) + " Attack was not spent. Tap DONE ATTACKING.", false);
}

function vv_tutorial_after_minion_defeated(_cost) {
    if (tutorial_mode && turn_number == 3) vv_tutorial_set_state(TutorialStep.T3_AttackBunnyResult, "result", "RESULT",
        "Bunny was defeated for its " + string(_cost) + " Health. You have " + string(attack_left) + " Attack left.", true);
}

function vv_tutorial_after_attack_complete() {
    if (tutorial_mode && turn_number == 2) vv_tutorial_set_state(TutorialStep.T2_BothMinionsRemainResult, "result", "RESULT",
        "Corgi and Red Panda survive because neither could be fully defeated.", true);
}

function vv_tutorial_after_leader_attack(_damage) {
    if (!tutorial_mode) return;
    if (turn_number == 1) vv_tutorial_set_state(TutorialStep.T1_AttackLeaderResult, "result", "RESULT",
        "All " + string(_damage) + " Attack damaged the Velvet Queen. Attacking the Leader spends all remaining Attack.", true);
    else if (turn_number == 3) vv_tutorial_set_state(TutorialStep.T3_AttackLeaderResult, "result", "RESULT",
        "The remaining " + string(_damage) + " Attack damaged the Velvet Queen.", true);
}

function vv_tutorial_note_leader_heal(_before, _after) {
    if (!tutorial_mode) return;
    tutorial_heal_before = _before;
    tutorial_heal_after = _after;
}

function vv_tutorial_find_content_index(_registry, _content_id) {
    for (var content_i = 0; content_i < array_length(_registry); content_i++) {
        if (_registry[content_i].id == _content_id) return content_i;
    }
    return -1;
}

function vv_tutorial_begin() {
    var profile = vv_tutorial_profile();
    var leader_index = vv_tutorial_find_content_index(available_leaders, profile.leader_id);
    var scenario_index = vv_tutorial_find_content_index(available_scenarios, profile.scenario_id);
    var minion_set_index = vv_tutorial_find_content_index(available_minion_sets, profile.minion_set_id);
    if (leader_index < 0 || scenario_index < 0 || minion_set_index < 0
    || !validate_hero_selection(available_heroes, profile.hero_ids)) return false;

    tutorial_saved_setup = {
        leader_index:selected_leader_index,
        scenario_index:selected_scenario_index,
        minion_set_index:selected_minion_set_index,
        hero_ids:variable_clone(selected_hero_ids),
        events:variable_clone(enemy_event_selection)
    };
    selected_leader_index = leader_index;
    selected_scenario_index = scenario_index;
    selected_minion_set_index = minion_set_index;
    enemy_leader = available_leaders[leader_index];
    enemy_scenario = available_scenarios[scenario_index];
    enemy_minion_set = available_minion_sets[minion_set_index];
    selected_hero_ids = variable_clone(profile.hero_ids);
    enemy_event_selection = make_default_enemy_event_selection(enemy_leader, enemy_scenario);
    leader_art_sprite = get_art_sprite(enemy_leader.art_file);
    tutorial_mode = true;
    return true;
}

function vv_tutorial_restore_setup() {
    if (is_undefined(tutorial_saved_setup)) return;
    selected_leader_index = tutorial_saved_setup.leader_index;
    selected_scenario_index = tutorial_saved_setup.scenario_index;
    selected_minion_set_index = tutorial_saved_setup.minion_set_index;
    selected_hero_ids = variable_clone(tutorial_saved_setup.hero_ids);
    enemy_leader = available_leaders[selected_leader_index];
    enemy_scenario = available_scenarios[selected_scenario_index];
    enemy_minion_set = available_minion_sets[selected_minion_set_index];
    enemy_event_selection = variable_clone(tutorial_saved_setup.events);
    leader_art_sprite = get_art_sprite(enemy_leader.art_file);
    tutorial_saved_setup = undefined;
}

function vv_tutorial_take_player_card(_deck, _hero_id, _kind) {
    for (var card_i = 0; card_i < array_length(_deck); card_i++) {
        var candidate = _deck[card_i];
        if (candidate.hero == _hero_id && candidate.kind == _kind) {
            var card = _deck[card_i];
            array_delete(_deck, card_i, 1);
            return card;
        }
    }
    return undefined;
}

function vv_tutorial_take_enemy_card(_deck, _id) {
    for (var card_i = 0; card_i < array_length(_deck); card_i++) {
        if (_deck[card_i].id == _id) {
            var card = _deck[card_i];
            array_delete(_deck, card_i, 1);
            return card;
        }
    }
    return undefined;
}

function vv_tutorial_configure_match() {
    var profile = vv_tutorial_profile();
    var opening_hand = [];
    for (var hero_i = 0; hero_i < array_length(profile.hero_ids); hero_i++) {
        var hero_card = vv_tutorial_take_player_card(player_deck,
            profile.hero_ids[hero_i], profile.hero_kinds[hero_i]);
        if (!is_undefined(hero_card)) array_push(opening_hand, hero_card);
    }
    // Stack later tutorial hands before Turn 1's opening hand (the deck pops from the end).
    var later_cards = [
        vv_tutorial_take_player_card(player_deck, "goblin", "Normal"),
        vv_tutorial_take_player_card(player_deck, "skeleton", "Normal"),
        vv_tutorial_take_player_card(player_deck, "orc", "Normal"),
        vv_tutorial_take_player_card(player_deck, "orc", "Special"),
        vv_tutorial_take_player_card(player_deck, "orc", "Ability"),
        vv_tutorial_take_player_card(player_deck, "orc", "Ability")
    ];
    for (var later_i = 0; later_i < array_length(later_cards); later_i++) {
        if (!is_undefined(later_cards[later_i])) array_push(player_deck, later_cards[later_i]);
    }
    for (var opening_i = array_length(opening_hand) - 1; opening_i >= 0; opening_i--) {
        array_push(player_deck, opening_hand[opening_i]);
    }
    // Controlled Enemy draws: Corgi; Direct Assault, Red Panda; Reinforcements, Bunny.
    var tutorial_enemies = [
        vv_tutorial_take_enemy_card(enemy_deck, "bunny"),
        vv_tutorial_take_enemy_card(enemy_deck, "reinforcements"),
        vv_tutorial_take_enemy_card(enemy_deck, "red_panda"),
        vv_tutorial_take_enemy_card(enemy_deck, "direct_assault"),
        vv_tutorial_take_enemy_card(enemy_deck, "corgi")
    ];
    for (var enemy_i = 0; enemy_i < array_length(tutorial_enemies); enemy_i++) {
        if (!is_undefined(tutorial_enemies[enemy_i])) array_push(enemy_deck, tutorial_enemies[enemy_i]);
    }
    minions = [undefined, undefined];
    tutorial_escape_seen = false;
    tutorial_minion_defeated = false;
    tutorial_leader_attacked = false;
    tutorial_final_leader_attacked = false;
    tutorial_complete_prompt = false;
    tutorial_entry_notice_timer = 0;
    tutorial_move_notice_timer = 0;
    tutorial_destroyed_cards = [];
    tutorial_enemy_attack_remaining = 0;
    tutorial_heal_before = leader_hp;
    tutorial_heal_after = leader_hp;
    tutorial_last_attack = 0;
    tutorial_pending_action = "";
    tutorial_pending_frames = 0;
    tutorial_pending_escape = undefined;
    vv_tutorial_set_state(TutorialStep.Intro, "result", "GUIDED TRAINING",
        "This battle teaches the turn\none step at a time.\n\nFollow the highlighted action.\n\nWATCH means the game is showing\nyou something automatically.\n\nNothing will advance while you\nare reading a training message.", true);
}

function vv_tutorial_target_hp() {
    for (var minion_i = 0; minion_i < 2; minion_i++) {
        if (!is_undefined(minions[minion_i])) return minions[minion_i].hp;
    }
    return 0;
}

function vv_tutorial_run_self_checks(_leaders, _scenarios, _minion_sets, _heroes) {
    var profile = vv_tutorial_profile();
    var leader_i = vv_tutorial_find_content_index(_leaders, profile.leader_id);
    var scenario_i = vv_tutorial_find_content_index(_scenarios, profile.scenario_id);
    var set_i = vv_tutorial_find_content_index(_minion_sets, profile.minion_set_id);
    if (leader_i < 0 || scenario_i < 0 || set_i < 0
    || !validate_hero_selection(_heroes, profile.hero_ids)) {
        return content_validation_result(false, "Tutorial content selection check failed.");
    }
    var goblin = find_hero_definition(_heroes, "goblin");
    var skeleton = find_hero_definition(_heroes, "skeleton");
    var orc = find_hero_definition(_heroes, "orc");
    if (is_undefined(goblin) || is_undefined(skeleton) || is_undefined(orc)
    || goblin.normal.atk != 5 || goblin.normal.hp != 3
    || skeleton.normal.atk != 4 || skeleton.normal.hp != 4
    || orc.ability.atk != 2 || orc.ability.hp != 6
    || orc.special.atk != 2 || orc.special.hp != 8) {
        return content_validation_result(false, "Tutorial Hero sequence check failed.");
    }
    var set_cards = _minion_sets[set_i].minion_slots;
    var bunny_ok = false, corgi_ok = false, panda_ok = false;
    for (var slot_i = 0; slot_i < array_length(set_cards); slot_i++) {
        var minion = set_cards[slot_i].card;
        if (minion.id == "bunny") bunny_ok = minion.atk == 4 && minion.hp == 6;
        if (minion.id == "corgi") corgi_ok = minion.atk == 6 && minion.hp == 8;
        if (minion.id == "red_panda") panda_ok = minion.atk == 8 && minion.hp == 10;
    }
    if (!bunny_ok || !corgi_ok || !panda_ok
    || _leaders[leader_i].leader_strikes[0].card.id != "direct_assault"
    || _scenarios[scenario_i].twists[0].card.id != "reinforcements"
    || TutorialStep.Complete <= TutorialStep.T3_EndResult) {
        return content_validation_result(false, "Tutorial Enemy sequence check failed.");
    }
    var opening_build = [goblin.normal, skeleton.normal, orc.ability];
    var after_strike = [goblin.normal, skeleton.normal, undefined];
    var guarded_build = [orc.ability, orc.ability, orc.special];
    var surviving_build = [orc.ability, orc.ability, undefined];
    var final_build = [orc.ability, orc.ability, goblin.normal];
    var opening_attack = evaluate_build(opening_build).guaranteed_attack;
    var guarded_attack = evaluate_build(guarded_build).guaranteed_attack;
    var surviving_attack = evaluate_build(surviving_build).guaranteed_attack;
    var final_attack = evaluate_build(final_build).guaranteed_attack;
    if (vv_tutorial_enemy_target_for(2, opening_build, 8, "Direct Assault") != 2
    || vv_tutorial_enemy_target_for(2, after_strike, 8, "Red Panda") != 0
    || vv_tutorial_enemy_target_for(3, guarded_build, 8, "Reinforcements") != 2
    || enemy_target_is_legal_in_build(guarded_build, 0, 4)
    || enemy_target_is_legal_in_build(guarded_build, 1, 4)
    || enemy_target_is_legal_in_build(guarded_build, 2, 4)
    || opening_attack != 11 || guarded_attack != 6 || surviving_attack != 4
    || final_attack != 9 || guarded_attack >= 8 || guarded_attack >= 10
    || final_attack - 6 != 3 || _leaders[leader_i].starting_hp - opening_attack + 7 != 171) {
        return content_validation_result(false, "Tutorial priority targeting check failed.");
    }
    return content_validation_result(true, "");
}

function vv_tutorial_complete() {
    if (!tutorial_complete_prompt) return false;
    vv_settings_complete_guided_tutorial();
    vv_tutorial_restore_setup();
    tutorial_mode = false;
    tutorial_complete_prompt = false;
    if (!reset_game()) return false;
    setup_active = false;
    return true;
}
