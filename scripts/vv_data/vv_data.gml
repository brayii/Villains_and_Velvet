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

// Stable gameplay IDs. Display names can change without changing behavior.
#macro ABILITY_NONE "none"
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
                card: card_enemy("strike", "Direct Assault", "The Enemy Leader attacks for " + string(leader_attack) + "."),
                default_copies: 3
            }
        ]
    };
}

function player_character_name(_hero) {
    if (_hero == "B") return "Skeleton";
    if (_hero == "C") return "Orc";
    return "Goblin";
}

function minion_character_name(_name) {
    switch (_name) {
        case "NA": return "Bunny";
        case "NB": return "Corgi";
        case "NC": return "Red Panda";
        case "AA": return "Otter";
        case "AB": return "Highland Cow";
        case "SA": return "Capybara";
        case "SB": return "Raccoon";
        case "SC": return "Harp Seal";
    }
    return _name;
}

function player_card_art(_hero, _kind) {
    var character = string_lower(player_character_name(_hero));
    return "card_art/heroes/hero_" + string_lower(_hero) + "_" + string_lower(_kind) + "_" + character + ".png";
}

function minion_card_art(_name) {
    switch (_name) {
        case "NA": return "card_art/enemies/minion_na_bunny.png";
        case "NB": return "card_art/enemies/minion_nb_corgi.png";
        case "NC": return "card_art/enemies/minion_nc_red_panda.png";
        case "AA": return "card_art/enemies/minion_aa_otter.png";
        case "AB": return "card_art/enemies/minion_ab_highland_cow.png";
        case "SA": return "card_art/enemies/minion_sa_capybara.png";
        case "SB": return "card_art/enemies/minion_sb_raccoon.png";
        case "SC": return "card_art/enemies/minion_sc_harp_seal.png";
    }
    return "";
}

function enemy_event_art(_type) {
    return _type == "strike"
        ? "card_art/enemies/leader_strike_direct_assault.png"
        : "card_art/enemies/twist_reinforcements.png";
}

function card_player(_hero, _kind, _atk, _hp, _ability_id, _ability, _effect) {
    return {
        hero: _hero,
        kind: _kind,
        name: player_character_name(_hero),
        atk: _atk,
        hp: _hp,
        ability_id: _ability_id,
        ability: _ability,
        effect: _effect,
        art_file: player_card_art(_hero, _kind)
    };
}

function card_minion(_name, _kind, _atk, _hp, _ability_id, _ability, _effect, _escape, _escape_value) {
    return {
        card_type: "minion",
        code: _name,
        name: minion_character_name(_name),
        kind: _kind,
        atk: _atk,
        hp: _hp,
        ability_id: _ability_id,
        ability: _ability,
        effect: _effect,
        escape: _escape,
        escape_value: _escape_value,
        art_file: minion_card_art(_name)
    };
}

function card_enemy(_type, _name, _effect) {
    return {
        card_type: _type,
        name: _name,
        effect: _effect,
        art_file: enemy_event_art(_type)
    };
}

function make_scenario_the_assault() {
    return {
        id: "the_assault",
        name: "The Assault",
        setup_rules: [],
        minions: {
            na: card_minion("NA", "Normal", 4, 6, ABILITY_NONE, "", "Attacks when played.", "heal", 5),
            nb: card_minion("NB", "Normal", 6, 8, ABILITY_NONE, "", "Attacks when played.", "heal", 7),
            nc: card_minion("NC", "Normal", 8, 10, ABILITY_NONE, "", "Attacks when played.", "heal", 9),
            aa: card_minion("AA", "Ability", 5, 7, ABILITY_DISRUPT, "Disrupt", "Discard a Build card, then attack.", "heal", 6),
            ab: card_minion("AB", "Ability", 7, 9, ABILITY_CRUSH, "Crush", "Attacks twice when played.", "heal", 8),
            sa: card_minion("SA", "Special", 6, 12, ABILITY_PROTECTOR, "Protector", "The Enemy Leader cannot be attacked.", "heal", 10),
            sb: card_minion("SB", "Special", 8, 9, ABILITY_SHATTER, "Shatter", "Destroy the lowest-HP Build card, then attack.", "destroy_hand", 1),
            sc: card_minion("SC", "Special", 10, 14, ABILITY_DEVASTATE, "Devastate", "Attacks twice when played.", "heal", 12)
        },
        twists: [
            {
                card: card_enemy("twist", "Reinforcements", "The Minion in Area 2 attacks."),
                default_copies: 5
            }
        ]
    };
}

function array_add_copies(_array, _value, _count) {
    // Each physical card is independent so future temporary state cannot leak
    // from one copy to every matching card in the deck.
    for (var copy_i = 0; copy_i < _count; copy_i++) array_push(_array, variable_clone(_value));
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

function make_player_deck() {
    var deck = [];
    array_add_copies(deck, card_player("A", "Normal", 5, 3, ABILITY_NONE, "", ""), CORE_HERO_NORMAL_COPIES);
    array_add_copies(deck, card_player("A", "Ability", 4, 2, ABILITY_OVERPOWER, "Overpower", "After you defeat a Minion, gain +2 Attack."), CORE_HERO_ABILITY_COPIES);
    array_add_copies(deck, card_player("A", "Special", 7, 2, ABILITY_RELENTLESS, "Relentless", "After you defeat a Minion, gain +3 Attack."), CORE_HERO_SPECIAL_COPIES);
    array_add_copies(deck, card_player("B", "Normal", 4, 4, ABILITY_NONE, "", ""), CORE_HERO_NORMAL_COPIES);
    array_add_copies(deck, card_player("B", "Ability", 3, 4, ABILITY_RALLY, "Rally", "Your other Build cards gain +1 Attack."), CORE_HERO_ABILITY_COPIES);
    array_add_copies(deck, card_player("B", "Special", 4, 4, ABILITY_UNITY, "Unity", "Gain +2 Attack for each other Hero type in your Build."), CORE_HERO_SPECIAL_COPIES);
    array_add_copies(deck, card_player("C", "Normal", 3, 5, ABILITY_NONE, "", ""), CORE_HERO_NORMAL_COPIES);
    array_add_copies(deck, card_player("C", "Ability", 2, 6, ABILITY_GUARD, "Guard", "Enemies must attack this card first."), CORE_HERO_ABILITY_COPIES);
    array_add_copies(deck, card_player("C", "Special", 2, 8, ABILITY_FORTRESS, "Fortress", "Enemies must attack this card first."), CORE_HERO_SPECIAL_COPIES);
    return array_shuffle_copy(deck);
}

function make_enemy_deck(_leader, _scenario) {
    var deck = [];
    array_add_copies(deck, _scenario.minions.na, CORE_MINION_NA_COPIES);
    array_add_copies(deck, _scenario.minions.nb, CORE_MINION_NB_COPIES);
    array_add_copies(deck, _scenario.minions.nc, CORE_MINION_NC_COPIES);
    array_add_copies(deck, _scenario.minions.aa, CORE_MINION_AA_COPIES);
    array_add_copies(deck, _scenario.minions.ab, CORE_MINION_AB_COPIES);
    array_add_copies(deck, _scenario.minions.sa, CORE_MINION_SA_COPIES);
    array_add_copies(deck, _scenario.minions.sb, CORE_MINION_SB_COPIES);
    array_add_copies(deck, _scenario.minions.sc, CORE_MINION_SC_COPIES);
    for (var strike_i = 0; strike_i < array_length(_leader.leader_strikes); strike_i++) {
        var strike_definition = _leader.leader_strikes[strike_i];
        array_add_copies(deck, strike_definition.card, strike_definition.default_copies);
    }
    for (var twist_i = 0; twist_i < array_length(_scenario.twists); twist_i++) {
        var twist_definition = _scenario.twists[twist_i];
        array_add_copies(deck, twist_definition.card, twist_definition.default_copies);
    }
    return array_shuffle_copy(deck);
}
