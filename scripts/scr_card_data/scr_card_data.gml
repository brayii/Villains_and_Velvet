/// Card definitions for Villains & Velvet.

#macro ART_BACKGROUND "card_art/backgrounds/battlefield.png"
#macro ART_ENEMY_LEADER "card_art/enemies/leader_velvet_queen.png"

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

function card_player(_hero, _kind, _atk, _hp, _ability, _effect) {
    return {
        hero: _hero,
        kind: _kind,
        name: player_character_name(_hero),
        atk: _atk,
        hp: _hp,
        ability: _ability,
        effect: _effect,
        art_file: player_card_art(_hero, _kind)
    };
}

function card_minion(_name, _kind, _atk, _hp, _ability, _effect, _escape, _escape_value) {
    return {
        card_type: "minion",
        code: _name,
        name: minion_character_name(_name),
        kind: _kind,
        atk: _atk,
        hp: _hp,
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

function array_add_copies(_array, _value, _count) {
    for (var copy_i = 0; copy_i < _count; copy_i++) array_push(_array, _value);
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

function array_remove_index(_source, _index) {
    var result = [];
    for (var source_i = 0; source_i < array_length(_source); source_i++) {
        if (source_i != _index) array_push(result, _source[source_i]);
    }
    return result;
}

function make_player_deck() {
    var deck = [];
    array_add_copies(deck, card_player("A", "Normal", 5, 3, "", ""), 7);
    array_add_copies(deck, card_player("A", "Ability", 4, 2, "Overpower", "After you defeat a Minion, gain +2 Attack."), 5);
    array_add_copies(deck, card_player("A", "Special", 7, 2, "Relentless", "After you defeat a Minion, gain +3 Attack."), 3);
    array_add_copies(deck, card_player("B", "Normal", 4, 4, "", ""), 7);
    array_add_copies(deck, card_player("B", "Ability", 3, 4, "Rally", "Your other Build cards gain +1 Attack."), 5);
    array_add_copies(deck, card_player("B", "Special", 4, 4, "Unity", "Gain +2 Attack for each other Hero type in your Build."), 3);
    array_add_copies(deck, card_player("C", "Normal", 3, 5, "", ""), 7);
    array_add_copies(deck, card_player("C", "Ability", 2, 6, "Guard", "Enemies must attack this card first."), 5);
    array_add_copies(deck, card_player("C", "Special", 2, 8, "Fortress", "Enemies must attack this card first."), 3);
    return array_shuffle_copy(deck);
}

function make_enemy_deck() {
    var deck = [];
    array_add_copies(deck, card_minion("NA", "Normal", 4, 6, "", "Attacks when played.", "heal", 5), 7);
    array_add_copies(deck, card_minion("NB", "Normal", 6, 8, "", "Attacks when played.", "heal", 7), 3);
    array_add_copies(deck, card_minion("NC", "Normal", 8, 10, "", "Attacks when played.", "heal", 9), 2);
    array_add_copies(deck, card_minion("AA", "Ability", 5, 7, "Disrupt", "Discard a Build card, then attack.", "heal", 6), 5);
    array_add_copies(deck, card_minion("AB", "Ability", 7, 9, "Crush", "Attacks twice when played.", "heal", 8), 3);
    array_add_copies(deck, card_minion("SA", "Special", 6, 12, "Protector", "The Enemy Leader cannot be attacked.", "heal", 10), 2);
    array_add_copies(deck, card_minion("SB", "Special", 8, 9, "Shatter", "Destroy the lowest-HP Build card, then attack.", "destroy_hand", 1), 2);
    array_add_copies(deck, card_minion("SC", "Special", 10, 14, "Devastate", "Attacks twice when played.", "heal", 12), 1);
    array_add_copies(deck, card_enemy("strike", "Direct Assault", "The Enemy Leader attacks for 8."), 3);
    array_add_copies(deck, card_enemy("twist", "Reinforcements", "The Minion in Area 2 attacks."), 5);
    return array_shuffle_copy(deck);
}

function point_in_rect(_px, _py, _rect) {
    return _px >= _rect.x && _px <= _rect.x + _rect.w
        && _py >= _rect.y && _py <= _rect.y + _rect.h;
}
