/// Stable card, Leader, deck, and artwork-path definitions for Villains & Velvet.

#macro ART_BACKGROUND "card_art/backgrounds/battlefield.png"

// Permanent core deck structure. Content supplies the cards that fill these slots.
#macro CORE_HERO_COUNT 3
#macro CORE_HERO_NORMAL_COPIES 7
#macro CORE_HERO_ABILITY_COPIES 5
#macro CORE_HERO_SPECIAL_COPIES 3
#macro CORE_PLAYER_DECK_SIZE 45

#macro CORE_MINION_NA_COPIES 7
#macro CORE_MINION_NB_COPIES 3
#macro CORE_MINION_NC_COPIES 2
#macro CORE_MINION_AA_COPIES 5
#macro CORE_MINION_AB_COPIES 3
#macro CORE_MINION_SA_COPIES 2
#macro CORE_MINION_SB_COPIES 2
#macro CORE_MINION_SC_COPIES 1
#macro CORE_MINION_TOTAL 25
#macro CORE_ENEMY_EVENT_SLOTS 8
#macro CORE_ENEMY_DECK_SIZE 33

function core_minion_slot_ids() {
    return ["NA", "NB", "NC", "AA", "AB", "SA", "SB", "SC"];
}

function core_minion_slot_copies(_slot) {
    switch (_slot) {
        case "NA": return CORE_MINION_NA_COPIES;
        case "NB": return CORE_MINION_NB_COPIES;
        case "NC": return CORE_MINION_NC_COPIES;
        case "AA": return CORE_MINION_AA_COPIES;
        case "AB": return CORE_MINION_AB_COPIES;
        case "SA": return CORE_MINION_SA_COPIES;
        case "SB": return CORE_MINION_SB_COPIES;
        case "SC": return CORE_MINION_SC_COPIES;
    }
    return 0;
}

function core_minion_slots_are_valid(_scenario) {
    if (is_undefined(_scenario) || !variable_struct_exists(_scenario, "minion_slots")) return false;
    var expected_slots = core_minion_slot_ids();
    if (array_length(_scenario.minion_slots) != array_length(expected_slots)) return false;
    var seen_slots = [];
    for (var slot_i = 0; slot_i < array_length(_scenario.minion_slots); slot_i++) {
        var definition = _scenario.minion_slots[slot_i];
        if (!is_struct(definition)) return false;
        if (!variable_struct_exists(definition, "slot") || !variable_struct_exists(definition, "card")) return false;
        if (!is_struct(definition.card)) return false;
        if (core_minion_slot_copies(definition.slot) <= 0) return false;
        for (var seen_i = 0; seen_i < array_length(seen_slots); seen_i++) {
            if (seen_slots[seen_i] == definition.slot) return false;
        }
        array_push(seen_slots, definition.slot);
    }
    return true;
}

// Stable gameplay IDs. Display names can change without changing behavior.
#macro ABILITY_OVERPOWER "overpower"
#macro ABILITY_RELENTLESS "relentless"
#macro ABILITY_RALLY "rally"
#macro ABILITY_UNITY "unity"
#macro ABILITY_GUARD "guard"
#macro ABILITY_FORTRESS "fortress"
#macro ABILITY_DISRUPT "disrupt"
#macro ABILITY_CRUSH "crush"
#macro ABILITY_PROTECTOR "protector"
#macro ABILITY_SHATTER "shatter"
#macro ABILITY_DEVASTATE "devastate"

// Stable Enemy Event effect IDs. Display names do not determine behavior.
#macro EFFECT_LEADER_BASIC_ATTACK "leader_basic_attack"
#macro EFFECT_AREA_2_ATTACK "area_2_attack"
#macro EFFECT_HEAL_LEADER "heal_leader"
#macro EFFECT_DESTROY_HAND_CARD "destroy_hand_card"

function ability_entry(_id) {
    return {id:_id, params:{}};
}

function find_card_ability(_card, _ability_id) {
    if (is_undefined(_card) || !variable_struct_exists(_card, "abilities")) return undefined;
    for (var ability_i = 0; ability_i < array_length(_card.abilities); ability_i++) {
        if (_card.abilities[ability_i].id == _ability_id) return _card.abilities[ability_i];
    }
    return undefined;
}

function card_has_ability(_card, _ability_id) {
    return !is_undefined(find_card_ability(_card, _ability_id));
}

function effect_entry(_id, _params) {
    return {id:_id, params:_params};
}

function make_enemy_leader() {
    var leader_attack = 8;
    return {
        id: "velvet_queen",
        name: "The Velvet Queen",
        starting_hp: 175,
        max_hp: 175,
        attack: leader_attack,
        art_file: "card_art/enemies/leader_velvet_queen.png",
        abilities: [],
        special_moves: [],
        leader_strikes: [
            {
                card: card_enemy(
                    "strike",
                    "direct_assault",
                    "Direct Assault",
                    [effect_entry(EFFECT_LEADER_BASIC_ATTACK, {})],
                    "The Enemy Leader attacks for " + string(leader_attack) + ".",
                    "card_art/enemies/leader_strike_direct_assault.png"
                ),
                default_copies: 3,
                max_copies: 3
            }
        ]
    };
}

function card_player(_hero, _name, _kind, _atk, _hp, _abilities, _ability, _effect, _art_file, _theme_color) {
    return {
        hero: _hero,
        kind: _kind,
        name: _name,
        atk: _atk,
        hp: _hp,
        abilities: _abilities,
        ability: _ability,
        effect: _effect,
        art_file: _art_file,
        theme_color: _theme_color
    };
}

function card_minion(_code, _name, _kind, _atk, _hp, _abilities, _ability, _effect, _escape_effects, _art_file) {
    return {
        card_type: "minion",
        code: _code,
        name: _name,
        kind: _kind,
        atk: _atk,
        hp: _hp,
        abilities: _abilities,
        ability: _ability,
        effect: _effect,
        escape_effects: _escape_effects,
        art_file: _art_file
    };
}

function card_enemy(_type, _id, _name, _effects, _effect, _art_file) {
    return {
        card_type: _type,
        id: _id,
        name: _name,
        effects: _effects,
        effect: _effect,
        art_file: _art_file
    };
}

function make_hero_definitions() {
    var goblin_color = make_color_rgb(91, 42, 53);
    var skeleton_color = make_color_rgb(54, 67, 112);
    var orc_color = make_color_rgb(42, 91, 74);
    return [
        {
            id: "A",
            name: "Goblin",
            normal: card_player("A", "Goblin", "Normal", 5, 3, [], "", "", "card_art/heroes/hero_a_normal_goblin.png", goblin_color),
            ability: card_player("A", "Goblin", "Ability", 4, 2, [ability_entry(ABILITY_OVERPOWER)], "Overpower", "After you defeat a Minion, gain +2 Attack.", "card_art/heroes/hero_a_ability_goblin.png", goblin_color),
            special: card_player("A", "Goblin", "Special", 7, 2, [ability_entry(ABILITY_RELENTLESS)], "Relentless", "After you defeat a Minion, gain +3 Attack.", "card_art/heroes/hero_a_special_goblin.png", goblin_color)
        },
        {
            id: "B",
            name: "Skeleton",
            normal: card_player("B", "Skeleton", "Normal", 4, 4, [], "", "", "card_art/heroes/hero_b_normal_skeleton.png", skeleton_color),
            ability: card_player("B", "Skeleton", "Ability", 3, 4, [ability_entry(ABILITY_RALLY)], "Rally", "Your other Build cards gain +1 Attack.", "card_art/heroes/hero_b_ability_skeleton.png", skeleton_color),
            special: card_player("B", "Skeleton", "Special", 4, 4, [ability_entry(ABILITY_UNITY)], "Unity", "Gain +2 Attack for each other Hero type in your Build.", "card_art/heroes/hero_b_special_skeleton.png", skeleton_color)
        },
        {
            id: "C",
            name: "Orc",
            normal: card_player("C", "Orc", "Normal", 3, 5, [], "", "", "card_art/heroes/hero_c_normal_orc.png", orc_color),
            ability: card_player("C", "Orc", "Ability", 2, 6, [ability_entry(ABILITY_GUARD)], "Guard", "Enemies must attack this card first.", "card_art/heroes/hero_c_ability_orc.png", orc_color),
            special: card_player("C", "Orc", "Special", 2, 8, [ability_entry(ABILITY_FORTRESS)], "Fortress", "Enemies must attack this card first.", "card_art/heroes/hero_c_special_orc.png", orc_color)
        }
    ];
}

function find_hero_definition(_definitions, _id) {
    for (var hero_i = 0; hero_i < array_length(_definitions); hero_i++) {
        if (_definitions[hero_i].id == _id) return _definitions[hero_i];
    }
    return undefined;
}

function make_default_hero_selection(_definitions) {
    var selected = [];
    for (var hero_i = 0; hero_i < min(CORE_HERO_COUNT, array_length(_definitions)); hero_i++) {
        array_push(selected, _definitions[hero_i].id);
    }
    return selected;
}

function make_scenario_the_assault() {
    return {
        id: "the_assault",
        name: "The Assault",
        setup_rules: [],
        minion_slots: [
            {slot:"NA", card:card_minion("NA", "Bunny", "Normal", 4, 6, [], "", "Attacks when played.", [effect_entry(EFFECT_HEAL_LEADER, {amount:5})], "card_art/enemies/minion_na_bunny.png")},
            {slot:"NB", card:card_minion("NB", "Corgi", "Normal", 6, 8, [], "", "Attacks when played.", [effect_entry(EFFECT_HEAL_LEADER, {amount:7})], "card_art/enemies/minion_nb_corgi.png")},
            {slot:"NC", card:card_minion("NC", "Red Panda", "Normal", 8, 10, [], "", "Attacks when played.", [effect_entry(EFFECT_HEAL_LEADER, {amount:9})], "card_art/enemies/minion_nc_red_panda.png")},
            {slot:"AA", card:card_minion("AA", "Otter", "Ability", 5, 7, [ability_entry(ABILITY_DISRUPT)], "Disrupt", "Discard a Build card, then attack.", [effect_entry(EFFECT_HEAL_LEADER, {amount:6})], "card_art/enemies/minion_aa_otter.png")},
            {slot:"AB", card:card_minion("AB", "Highland Cow", "Ability", 7, 9, [ability_entry(ABILITY_CRUSH)], "Crush", "Attacks twice when played.", [effect_entry(EFFECT_HEAL_LEADER, {amount:8})], "card_art/enemies/minion_ab_highland_cow.png")},
            {slot:"SA", card:card_minion("SA", "Capybara", "Special", 6, 12, [ability_entry(ABILITY_PROTECTOR)], "Protector", "The Enemy Leader cannot be attacked.", [effect_entry(EFFECT_HEAL_LEADER, {amount:10})], "card_art/enemies/minion_sa_capybara.png")},
            {slot:"SB", card:card_minion("SB", "Raccoon", "Special", 8, 9, [ability_entry(ABILITY_SHATTER)], "Shatter", "Destroy the lowest-HP Build card, then attack.", [effect_entry(EFFECT_DESTROY_HAND_CARD, {count:1})], "card_art/enemies/minion_sb_raccoon.png")},
            {slot:"SC", card:card_minion("SC", "Harp Seal", "Special", 10, 14, [ability_entry(ABILITY_DEVASTATE)], "Devastate", "Attacks twice when played.", [effect_entry(EFFECT_HEAL_LEADER, {amount:12})], "card_art/enemies/minion_sc_harp_seal.png")}
        ],
        twists: [
            {
                card: card_enemy(
                    "twist",
                    "reinforcements",
                    "Reinforcements",
                    [effect_entry(EFFECT_AREA_2_ATTACK, {})],
                    "The Minion in Area 2 attacks.",
                    "card_art/enemies/twist_reinforcements.png"
                ),
                default_copies: 5,
                max_copies: 5
            }
        ]
    };
}

function array_add_copies(_array, _value, _count) {
    // Each physical card is independent so future temporary state cannot leak
    // from one copy to every matching card in the deck.
    for (var copy_i = 0; copy_i < _count; copy_i++) array_push(_array, variable_clone(_value));
}

function array_add_minion_slot_copies(_array, _definition) {
    var copy_count = core_minion_slot_copies(_definition.slot);
    for (var copy_i = 0; copy_i < copy_count; copy_i++) {
        var card = variable_clone(_definition.card);
        card.minion_slot = _definition.slot;
        array_push(_array, card);
    }
}

function array_shuffle_copy(_source) {
    var result = [];
    for (var copy_i = 0; copy_i < array_length(_source); copy_i++) array_push(result, _source[copy_i]);
    for (var shuffle_i = array_length(result) - 1; shuffle_i > 0; shuffle_i--) {
        var swap_i = irandom(shuffle_i);
        var held = result[shuffle_i];
        result[shuffle_i] = result[swap_i];
        result[swap_i] = held;
    }
    return result;
}

function find_enemy_event_definition(_definitions, _id) {
    for (var definition_i = 0; definition_i < array_length(_definitions); definition_i++) {
        if (_definitions[definition_i].card.id == _id) return _definitions[definition_i];
    }
    return undefined;
}

function make_default_enemy_event_selection(_leader, _scenario) {
    var selected_strikes = [];
    for (var strike_i = 0; strike_i < array_length(_leader.leader_strikes); strike_i++) {
        var strike_definition = _leader.leader_strikes[strike_i];
        array_push(selected_strikes, {id:strike_definition.card.id, copies:strike_definition.default_copies});
    }
    var selected_twists = [];
    for (var twist_i = 0; twist_i < array_length(_scenario.twists); twist_i++) {
        var twist_definition = _scenario.twists[twist_i];
        array_push(selected_twists, {id:twist_definition.card.id, copies:twist_definition.default_copies});
    }
    return {leader_strikes:selected_strikes, twists:selected_twists};
}

function add_selected_enemy_events(_deck, _selected, _definitions) {
    for (var selected_i = 0; selected_i < array_length(_selected); selected_i++) {
        var selection = _selected[selected_i];
        var definition = find_enemy_event_definition(_definitions, selection.id);
        if (!is_undefined(definition)) array_add_copies(_deck, definition.card, selection.copies);
    }
}

function make_player_deck(_hero_definitions, _selected_hero_ids) {
    var deck = [];
    for (var selected_i = 0; selected_i < array_length(_selected_hero_ids); selected_i++) {
        var hero = find_hero_definition(_hero_definitions, _selected_hero_ids[selected_i]);
        if (!is_undefined(hero)) {
            array_add_copies(deck, hero.normal, CORE_HERO_NORMAL_COPIES);
            array_add_copies(deck, hero.ability, CORE_HERO_ABILITY_COPIES);
            array_add_copies(deck, hero.special, CORE_HERO_SPECIAL_COPIES);
        }
    }
    return array_shuffle_copy(deck);
}

function make_enemy_deck(_leader, _scenario, _event_selection) {
    var deck = [];
    if (!core_minion_slots_are_valid(_scenario)) {
        show_debug_message("INVALID SCENARIO MINION SLOTS: " + string(_scenario.id));
        return deck;
    }
    for (var minion_i = 0; minion_i < array_length(_scenario.minion_slots); minion_i++) {
        var minion_slot = _scenario.minion_slots[minion_i];
        array_add_minion_slot_copies(deck, minion_slot);
    }
    add_selected_enemy_events(deck, _event_selection.leader_strikes, _leader.leader_strikes);
    add_selected_enemy_events(deck, _event_selection.twists, _scenario.twists);
    return array_shuffle_copy(deck);
}
