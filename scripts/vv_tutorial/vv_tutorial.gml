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
        hero_kinds:["Normal", "Normal", "Ability"],
        minion_slot:"NA"
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

function vv_tutorial_action_allowed() {
    if (!tutorial_mode) return true;
    if (turn_number == 2) {
        if (phase == "step1_ready") return tutorial_step == TutorialStep.T2_StartTurn;
        if (phase == "build") return tutorial_step == TutorialStep.T2_BuildReady;
        if (phase == "attack") return tutorial_step == TutorialStep.T2_DoneAttacking;
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

function vv_tutorial_continue() {
    if (!tutorial_mode || !tutorial_pause) return false;
    switch (tutorial_step) {
        case TutorialStep.Intro:
            vv_tutorial_set_state(TutorialStep.T1_StartTurn, "action", "YOUR ACTION",
                "Tap START TURN to draw\n3 Hero cards.", false);
            return true;
        case TutorialStep.T1_Step2Result:
            vv_tutorial_set_state(TutorialStep.T1_CorgiReveal, "action", "YOUR ACTION",
                "Tap ENEMY DRAW to reveal the first enemy.", false);
            return true;
        case TutorialStep.T1_CorgiEntryResult:
            begin_build();
            vv_tutorial_set_state(TutorialStep.T1_DragHero1, "action", "YOUR ACTION",
                "Drag the glowing Hero into the glowing Build space.", false);
            return true;
        case TutorialStep.T1_AttackLeaderResult:
            vv_tutorial_set_state(TutorialStep.T1_DiscardResult, "result", "RESULT",
                "Unused Hand cards are discarded at the end of the turn.", true);
            return true;
        case TutorialStep.T1_DiscardResult:
            vv_tutorial_set_state(TutorialStep.T1_EndResult, "action", "YOUR ACTION",
                "Tap END TURN. Your Build cards stay in play.", false);
            return true;
        case TutorialStep.T2_DrawResult:
            vv_tutorial_set_state(TutorialStep.T2_CorgiAdvanceWatch, "watch", "WATCH",
                "Corgi moves from Area 1 to Area 2.", false);
            do_step_2();
            return true;
        case TutorialStep.T2_CorgiAdvanceResult:
            vv_tutorial_set_state(TutorialStep.T2_DirectAssaultRead, "read", "READ THIS CARD",
                "Direct Assault makes the Velvet Queen attack for 8.", false);
            do_step_3();
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
            vv_tutorial_set_state(TutorialStep.T2_EventDrawRule, "tip", "TIP",
                "Enemy Event cards resolve, then Enemy Draw continues until a Minion appears.", true);
            return true;
        case TutorialStep.T2_EventDrawRule:
            tutorial_pause = false;
            draw_next_enemy_card();
            return true;
        case TutorialStep.T2_RedPandaAttackResult:
            begin_build();
            vv_tutorial_set_state(TutorialStep.T2_Rebuild1, "action", "YOUR ACTION",
                "Rebuild with the glowing Guard card.", false);
            return true;
        case TutorialStep.T2_BothMinionsRemainResult:
            vv_tutorial_set_state(TutorialStep.T2_EndResult, "action", "YOUR ACTION",
                "Tap END TURN. Both Minions remain in their Areas.", false);
            return true;
        case TutorialStep.T3_PreEscapeReason:
            vv_tutorial_set_state(TutorialStep.T3_AdvanceWatch, "watch", "WATCH",
                "Red Panda advances and pushes Corgi into the escape portal.", false);
            do_step_2();
            return true;
        case TutorialStep.T3_AdvanceResult:
            vv_tutorial_set_state(TutorialStep.T3_ReinforcementsRead, "action", "YOUR ACTION",
                "Tap ENEMY DRAW. The next Event shows why Area 2 matters.", false);
            return true;
        case TutorialStep.T3_ReinforcementsRead:
            if (is_undefined(tutorial_pending_enemy_card)) {
                tutorial_pause = false;
                do_step_3();
            } else {
                var twist = tutorial_pending_enemy_card;
                tutorial_pending_enemy_card = undefined;
                vv_tutorial_set_state(TutorialStep.T3_ReinforcementsWatch, "watch", "WATCH",
                    "Reinforcements makes Red Panda attack from Area 2.", false);
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
            tutorial_pause = false;
            draw_next_enemy_card();
            return true;
        case TutorialStep.T3_BunnyAttackResult:
            begin_build();
            vv_tutorial_set_state(TutorialStep.T3_Rebuild, "action", "YOUR ACTION",
                "One Build space is open. Drag the glowing Goblin into it.", false);
            return true;
        case TutorialStep.T3_AttackBunnyResult:
            vv_tutorial_set_state(TutorialStep.T3_AttackLeader, "action", "YOUR ACTION",
                "Bunny is defeated. Use your remaining 3 Attack on the Leader.", false);
            return true;
        case TutorialStep.T3_AttackLeaderResult:
            vv_tutorial_set_state(TutorialStep.T3_DiscardResult, "result", "RESULT",
                "You advanced Minions, resolved an escape, read an Event, rebuilt, and attacked.", true);
            return true;
        case TutorialStep.T3_DiscardResult:
            vv_tutorial_set_state(TutorialStep.T3_EndResult, "action", "YOUR ACTION",
                "Tap END TURN to finish training.", false);
            return true;
        case TutorialStep.T3_EndResult:
            vv_tutorial_set_state(TutorialStep.Complete, "result", "TRAINING COMPLETE",
                "You are ready for a real battle.", true);
            tutorial_complete_prompt = true;
            return true;
    }
    return false;
}

function vv_tutorial_pause_event_card(_card) {
    if (!tutorial_mode) return false;
    if (turn_number == 2 && _card.id == "direct_assault") {
        tutorial_pending_enemy_card = _card;
        vv_tutorial_set_state(TutorialStep.T2_DirectAssaultRead, "read", "READ THIS CARD",
            "Direct Assault: The Velvet Queen attacks for 8. Tap CONTINUE when you are ready.", true);
        return true;
    }
    if (turn_number == 3 && _card.id == "reinforcements") {
        tutorial_pending_enemy_card = _card;
        vv_tutorial_set_state(TutorialStep.T3_ReinforcementsRead, "read", "READ THIS CARD",
            "Reinforcements: the Minion in Area 2 attacks. Tap CONTINUE when ready.", true);
        return true;
    }
    return false;
}

function vv_tutorial_resume_intercept(_action) {
    if (!tutorial_mode) return false;
    if (_action == "continue_enemy_draw" && tutorial_step == TutorialStep.T2_DirectAssaultWatch) {
        resume_action = "";
        vv_tutorial_set_state(TutorialStep.T2_DirectAssaultResult, "result", "RESULT",
            "The 8-Attack strike defeated Guard first. The remaining Attack could not defeat another Hero.", true);
        return true;
    }
    if (_action == "continue_enemy_draw" && tutorial_step == TutorialStep.T3_ReinforcementsWatch) {
        resume_action = "";
        vv_tutorial_set_state(TutorialStep.T3_ReinforcementsResult, "result", "RESULT",
            "Red Panda attacked for 8 and defeated one priority Hero. Its unused Attack ended.", true);
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
        vv_tutorial_set_state(TutorialStep.T1_InspectClose, "action", "YOUR ACTION",
            "Tap ADVANCE / ESCAPE. Area 1 is empty, so nothing moves.", false);
    }
}

function vv_tutorial_after_player_draw() {
    if (!tutorial_mode) return;
    if (turn_number == 2) {
        auto_timer = 0;
        vv_tutorial_set_state(TutorialStep.T2_DrawResult, "result", "RESULT",
            "You drew two Guard cards and one Fortress. These priority Heroes protect your Build.", true);
        return;
    }
    if (turn_number == 3) {
        auto_timer = 0;
        vv_tutorial_set_state(TutorialStep.T3_PreEscapeReason, "read", "READ THIS CARD",
            "Both Minion Areas are full. Continue to watch what happens when Area 1 advances.", true);
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
    else if (turn_number == 3) vv_tutorial_set_state(TutorialStep.T3_AdvanceResult, "result", "RESULT",
        "Red Panda pushed Corgi out. Corgi escaped and healed the Velvet Queen by 7. The portal appears only during an escape.", true);
}

function vv_tutorial_after_turn_end() {
    if (!tutorial_mode) return;
    if (turn_number == 2) vv_tutorial_set_state(TutorialStep.T2_StartTurn, "action", "YOUR ACTION",
        "Tap START TURN to begin Turn 2.", false);
    else if (turn_number == 3) vv_tutorial_set_state(TutorialStep.T3_StartTurn, "action", "YOUR ACTION",
        "Tap START TURN to begin Turn 3.", false);
}

function vv_tutorial_after_enemy_entry(_minion) {
    if (!tutorial_mode) return;
    if (turn_number == 1 && _minion.id == "corgi") vv_tutorial_set_state(TutorialStep.T1_CorgiEntryResult,
        "result", "RESULT", "Corgi entered Area 1 and attacked. Your Build was empty, so no Hero was lost.", true);
}

function vv_tutorial_after_enemy_phase() {
    if (!tutorial_mode) return;
    if (turn_number == 2) vv_tutorial_set_state(TutorialStep.T2_RedPandaAttackResult, "result", "RESULT",
        "Red Panda attacked for 8 and defeated the two remaining Heroes. Enemy Attack is spent only on full defeats.", true);
    else if (turn_number == 3) vv_tutorial_set_state(TutorialStep.T3_BunnyAttackResult, "result", "RESULT",
        "Bunny entered Area 1. Its 4 Attack could not defeat Guard or Fortress, so it ended unused.", true);
}

function vv_tutorial_after_build_move() {
    if (!tutorial_mode) return;
    if (turn_number == 1) {
        var filled = count_occupied_build();
        if (filled == 1) vv_tutorial_set_state(TutorialStep.T1_DragHero2, "action", "YOUR ACTION", "Drag the next Hero into the glowing Build space.", false);
        else if (filled == 2) vv_tutorial_set_state(TutorialStep.T1_DragHero3, "action", "YOUR ACTION", "Drag the final Hero into the glowing Build space.", false);
        else if (filled == 3) vv_tutorial_set_state(TutorialStep.T1_BuildReady, "action", "YOUR ACTION", "Your Build has 11 Attack. Tap DONE BUILDING.", false);
    } else if (turn_number == 2) {
        var filled2 = count_occupied_build();
        if (filled2 == 1) vv_tutorial_set_state(TutorialStep.T2_Rebuild2, "action", "YOUR ACTION", "Add the second Guard card.", false);
        else if (filled2 == 2) vv_tutorial_set_state(TutorialStep.T2_Rebuild3, "action", "YOUR ACTION", "Add Fortress to complete the protected Build.", false);
        else if (filled2 == 3) vv_tutorial_set_state(TutorialStep.T2_BuildReady, "action", "YOUR ACTION", "This Build has 6 Attack. Tap DONE BUILDING.", false);
    } else if (turn_number == 3 && count_occupied_build() == 3) {
        vv_tutorial_set_state(TutorialStep.T3_BuildReady, "action", "YOUR ACTION",
            "Your rebuilt team has 9 Attack. Tap DONE BUILDING.", false);
    }
}

function vv_tutorial_after_attack_started() {
    if (tutorial_mode && turn_number == 1) vv_tutorial_set_state(TutorialStep.T1_AttackLeader, "action", "YOUR ACTION",
        "Corgi needs 8 Attack, but first learn to strike the Leader. Tap the glowing Leader.", false);
    else if (tutorial_mode && turn_number == 2) vv_tutorial_set_state(TutorialStep.T2_NotEnoughAttack, "action", "YOUR ACTION",
        "You have 6 Attack. Tap either Minion to see why it cannot be defeated.", false);
    else if (tutorial_mode && turn_number == 3) vv_tutorial_set_state(TutorialStep.T3_AttackBunny, "action", "YOUR ACTION",
        "Tap Bunny in Area 1. It costs 6 Attack to defeat.", false);
}

function vv_tutorial_after_failed_minion_attack() {
    if (tutorial_mode && turn_number == 2) vv_tutorial_set_state(TutorialStep.T2_DoneAttacking, "action", "YOUR ACTION",
        "Your 6 Attack was not spent. Tap DONE ATTACKING, then confirm that you want to keep it unused.", false);
}

function vv_tutorial_after_minion_defeated() {
    if (tutorial_mode && turn_number == 3) vv_tutorial_set_state(TutorialStep.T3_AttackBunnyResult, "result", "RESULT",
        "Bunny was defeated for 6 Attack. You have 3 Attack left.", true);
}

function vv_tutorial_after_attack_complete() {
    if (tutorial_mode && turn_number == 2) vv_tutorial_set_state(TutorialStep.T2_BothMinionsRemainResult, "result", "RESULT",
        "Corgi and Red Panda survive because neither could be fully defeated.", true);
}

function vv_tutorial_after_leader_attack() {
    if (!tutorial_mode) return;
    if (turn_number == 1) vv_tutorial_set_state(TutorialStep.T1_AttackLeaderResult, "result", "RESULT",
        "All 11 Attack damaged the Velvet Queen. Attack is spent only when an attack succeeds.", true);
    else if (turn_number == 3) vv_tutorial_set_state(TutorialStep.T3_AttackLeaderResult, "result", "RESULT",
        "The remaining 3 Attack damaged the Velvet Queen.", true);
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

function vv_tutorial_take_minion(_deck, _slot) {
    for (var card_i = 0; card_i < array_length(_deck); card_i++) {
        var candidate = _deck[card_i];
        if (candidate.card_type == "minion" && candidate.minion_slot == _slot) {
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
