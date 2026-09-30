/// Versioned player preferences. Match state and future AI learning data are kept separate.

function vv_text_file_read(_filename) {
    var text_file = -1;
    var text = "";
    try {
        if (!file_exists(_filename)) return {success:false, text:""};
        text_file = file_text_open_read(_filename);
        while (!file_text_eof(text_file)) {
            text += file_text_read_string(text_file);
            file_text_readln(text_file);
        }
        file_text_close(text_file);
        return {success:true, text:text};
    } catch (_error) {
        if (text_file >= 0) file_text_close(text_file);
        return {success:false, text:""};
    }
}

/// Writes a complete temporary file before replacing the live file. The prior
/// valid file remains as a backup so an interrupted replacement can recover.
function vv_atomic_text_write(_filename, _text) {
    var temp_filename = _filename + ".tmp";
    var backup_filename = _filename + ".bak";
    var text_file = -1;
    try {
        if (file_exists(temp_filename)) file_delete(temp_filename);
        text_file = file_text_open_write(temp_filename);
        file_text_write_string(text_file, _text);
        file_text_close(text_file);
        text_file = -1;
        if (!file_exists(temp_filename)) return false;

        if (file_exists(backup_filename)) file_delete(backup_filename);
        if (file_exists(_filename)) {
            file_rename(_filename, backup_filename);
            if (file_exists(_filename) || !file_exists(backup_filename)) {
                file_delete(temp_filename);
                return false;
            }
        }
        file_rename(temp_filename, _filename);
        if (file_exists(_filename)) return true;

        if (file_exists(backup_filename)) file_rename(backup_filename, _filename);
        return false;
    } catch (_error) {
        if (text_file >= 0) file_text_close(text_file);
        if (file_exists(temp_filename)) file_delete(temp_filename);
        if (!file_exists(_filename) && file_exists(backup_filename)) {
            file_rename(backup_filename, _filename);
        }
        return false;
    }
}

function vv_settings_defaults() {
    return {
        settings_version: 10,
        enemy_targeting_mode: "auto",
        audio_enabled: true,
        guided_tutorial_complete: false,
        hint_turn_steps: false,
        hint_enemy_event: false,
        hint_build: false,
        hint_drag: false,
        hint_inspect: false,
        hint_attack: false,
        hero_victories: 0
    };
}

function vv_settings_bool_field_is_valid(_data, _name) {
    return !variable_struct_exists(_data, _name)
        || is_bool(variable_struct_get(_data, _name));
}

function vv_settings_decode(_text) {
    var defaults = vv_settings_defaults();
    try {
        var loaded = json_parse(_text);
        if (!is_struct(loaded)
        || !variable_struct_exists(loaded, "settings_version")
        || !is_real(loaded.settings_version)
        || loaded.settings_version != floor(loaded.settings_version)
        || loaded.settings_version < 1 || loaded.settings_version > defaults.settings_version
        || !variable_struct_exists(loaded, "enemy_targeting_mode")
        || !is_string(loaded.enemy_targeting_mode)
        || !vv_settings_bool_field_is_valid(loaded, "audio_enabled")
        || !vv_settings_bool_field_is_valid(loaded, "guided_tutorial_complete")
        || !vv_settings_bool_field_is_valid(loaded, "hint_turn_steps")
        || !vv_settings_bool_field_is_valid(loaded, "hint_enemy_event")
        || !vv_settings_bool_field_is_valid(loaded, "hint_build")
        || !vv_settings_bool_field_is_valid(loaded, "hint_drag")
        || !vv_settings_bool_field_is_valid(loaded, "hint_inspect")
        || !vv_settings_bool_field_is_valid(loaded, "hint_attack")
        || (variable_struct_exists(loaded, "hero_victories")
            && (!is_real(loaded.hero_victories) || loaded.hero_victories < 0
                || loaded.hero_victories != floor(loaded.hero_victories)))) {
            return {valid:false, enemy_auto_play:true};
        }
        var mode = string_lower(loaded.enemy_targeting_mode);
        if (mode != "manual" && mode != "auto") {
            return {valid:false, enemy_auto_play:true};
        }
        var version = loaded.settings_version;
        return {
            valid:true,
            upgraded:version != defaults.settings_version,
            enemy_auto_play:mode == "auto",
            audio_enabled:version >= 3 && variable_struct_exists(loaded, "audio_enabled") ? loaded.audio_enabled : true,
            guided_tutorial_complete:version >= 9
                && variable_struct_exists(loaded, "guided_tutorial_complete")
                ? loaded.guided_tutorial_complete : false,
            hint_turn_steps:version >= 4 && variable_struct_exists(loaded, "hint_turn_steps") ? loaded.hint_turn_steps : false,
            hint_enemy_event:version >= 2 && variable_struct_exists(loaded, "hint_enemy_event") ? loaded.hint_enemy_event : false,
            hint_build:version >= 4 && variable_struct_exists(loaded, "hint_build") ? loaded.hint_build : false,
            hint_drag:version >= 2 && variable_struct_exists(loaded, "hint_drag") ? loaded.hint_drag : false,
            hint_inspect:version >= 2 && variable_struct_exists(loaded, "hint_inspect") ? loaded.hint_inspect : false,
            hint_attack:version >= 4 && variable_struct_exists(loaded, "hint_attack") ? loaded.hint_attack : false,
            hero_victories:version >= 10 && variable_struct_exists(loaded, "hero_victories")
                ? loaded.hero_victories : 0
        };
    } catch (_error) {
        return {valid:false, enemy_auto_play:true};
    }
}

function vv_settings_init() {
    settings_filename = "villains_and_velvet_settings.json";
    settings_version = 10;
    settings_dirty = true;
    enemy_auto_play = true;
    audio_enabled = true;
    guided_tutorial_complete = false;
    hint_turn_steps = false;
    hint_enemy_event = false;
    hint_build = false;
    hint_drag = false;
    hint_inspect = false;
    hint_attack = false;
    hero_victories = 0;
    hero_unlock_notice = "";
    vv_settings_load();
    vv_settings_save_if_dirty();
    vv_feedback_apply_audio_enabled();
}

function vv_settings_load() {
    enemy_auto_play = true;
    audio_enabled = true;
    guided_tutorial_complete = false;
    hint_turn_steps = false;
    hint_enemy_event = false;
    hint_build = false;
    hint_drag = false;
    hint_inspect = false;
    hint_attack = false;
    hero_victories = 0;
    settings_dirty = true;
    var loaded = vv_text_file_read(settings_filename);
    var decoded = loaded.success
        ? vv_settings_decode(loaded.text) : {valid:false, enemy_auto_play:true};
    var recovered_from_backup = false;
    if (!decoded.valid) {
        var backup = vv_text_file_read(settings_filename + ".bak");
        if (backup.success) {
            decoded = vv_settings_decode(backup.text);
            recovered_from_backup = decoded.valid;
        }
    }
    if (!decoded.valid) {
        var temporary = vv_text_file_read(settings_filename + ".tmp");
        if (temporary.success) {
            decoded = vv_settings_decode(temporary.text);
            recovered_from_backup = decoded.valid;
        }
    }
    enemy_auto_play = decoded.enemy_auto_play;
    if (decoded.valid) {
        audio_enabled = decoded.audio_enabled;
        guided_tutorial_complete = decoded.guided_tutorial_complete;
        hint_turn_steps = decoded.hint_turn_steps;
        hint_enemy_event = decoded.hint_enemy_event;
        hint_build = decoded.hint_build;
        hint_drag = decoded.hint_drag;
        hint_inspect = decoded.hint_inspect;
        hint_attack = decoded.hint_attack;
        hero_victories = decoded.hero_victories;
    }
    settings_dirty = recovered_from_backup || !decoded.valid
        || (decoded.valid && decoded.upgraded);
    return decoded.valid;
}

function vv_settings_save_if_dirty() {
    if (!settings_dirty) return true;
    var settings_data = {
        settings_version: settings_version,
        enemy_targeting_mode: enemy_auto_play ? "auto" : "manual",
        audio_enabled: audio_enabled,
        guided_tutorial_complete: guided_tutorial_complete,
        hint_turn_steps: hint_turn_steps,
        hint_enemy_event: hint_enemy_event,
        hint_build: hint_build,
        hint_drag: hint_drag,
        hint_inspect: hint_inspect,
        hint_attack: hint_attack,
        hero_victories: hero_victories
    };
    try {
        if (!vv_atomic_text_write(settings_filename, json_stringify(settings_data))) {
            settings_dirty = true;
            return false;
        }
        settings_dirty = false;
        return true;
    } catch (_error) {
        settings_dirty = true;
        return false;
    }
}

function vv_settings_mark_hint(_hint) {
    var changed = false;
    if (_hint == "turn_steps" && !hint_turn_steps) { hint_turn_steps = true; changed = true; }
    else if (_hint == "enemy_event" && !hint_enemy_event) { hint_enemy_event = true; changed = true; }
    else if (_hint == "build" && !hint_build) { hint_build = true; changed = true; }
    else if (_hint == "drag" && !hint_drag) { hint_drag = true; changed = true; }
    else if (_hint == "inspect" && !hint_inspect) { hint_inspect = true; changed = true; }
    else if (_hint == "attack" && !hint_attack) { hint_attack = true; changed = true; }
    if (changed) {
        settings_dirty = true;
        vv_settings_save_if_dirty();
    }
    return changed;
}

function vv_settings_complete_guided_tutorial() {
    if (guided_tutorial_complete) return false;
    guided_tutorial_complete = true;
    settings_dirty = true;
    vv_settings_save_if_dirty();
    return true;
}

function vv_progress_hero_unlocked(_hero) {
    return !variable_struct_exists(_hero, "unlock_wins")
        || hero_victories >= _hero.unlock_wins;
}

function vv_progress_next_unlock(_heroes) {
    var next_hero = undefined;
    for (var hero_i = 0; hero_i < array_length(_heroes); hero_i++) {
        var hero = _heroes[hero_i];
        if (vv_progress_hero_unlocked(hero)) continue;
        if (is_undefined(next_hero) || hero.unlock_wins < next_hero.unlock_wins) next_hero = hero;
    }
    return next_hero;
}

function vv_progress_record_victory(_heroes) {
    var previous_wins = hero_victories;
    hero_victories++;
    settings_dirty = true;
    vv_settings_save_if_dirty();
    for (var hero_i = 0; hero_i < array_length(_heroes); hero_i++) {
        var hero = _heroes[hero_i];
        if (hero.unlock_wins > previous_wins && hero.unlock_wins <= hero_victories) {
            return hero.name;
        }
    }
    return "";
}

function vv_progress_run_self_checks(_heroes) {
    var migrated = vv_settings_decode("{\"settings_version\":9,\"enemy_targeting_mode\":\"auto\"}");
    var invalid = vv_settings_decode("{\"settings_version\":10,\"enemy_targeting_mode\":\"auto\",\"hero_victories\":1.5}");
    if (!migrated.valid || migrated.hero_victories != 0 || invalid.valid) {
        return {valid:false, message:"Hero progression save migration check failed."};
    }
    var vampire = find_hero_definition(_heroes, "vampire");
    var witch = find_hero_definition(_heroes, "witch");
    var troll = find_hero_definition(_heroes, "troll");
    var original_victories = hero_victories;
    hero_victories = 0;
    var zero_valid = !vv_progress_hero_unlocked(vampire)
        && !vv_progress_hero_unlocked(witch) && !vv_progress_hero_unlocked(troll);
    hero_victories = 1;
    var one_valid = vv_progress_hero_unlocked(vampire)
        && !vv_progress_hero_unlocked(witch) && !vv_progress_hero_unlocked(troll);
    hero_victories = 3;
    var three_valid = vv_progress_hero_unlocked(vampire)
        && vv_progress_hero_unlocked(witch) && vv_progress_hero_unlocked(troll);
    hero_victories = original_victories;
    if (!zero_valid || !one_valid || !three_valid) {
        return {valid:false, message:"Hero progression unlock threshold check failed."};
    }
    return {valid:true, message:""};
}

function vv_settings_set_enemy_auto(_enabled) {
    var next_value = _enabled == true;
    if (enemy_auto_play == next_value) return false;
    enemy_auto_play = next_value;
    enemy_ai_baseline_note_mode_change();
    if (!enemy_auto_play) enemy_ai_cancel_pending_targeting();
    settings_dirty = true;
    vv_settings_save_if_dirty();
    return true;
}

function vv_settings_toggle_enemy_auto() {
    return vv_settings_set_enemy_auto(!enemy_auto_play);
}

function vv_settings_set_audio_enabled(_enabled) {
    var next_value = _enabled == true;
    if (audio_enabled == next_value) return false;
    audio_enabled = next_value;
    settings_dirty = true;
    vv_feedback_apply_audio_enabled();
    vv_settings_save_if_dirty();
    return true;
}

function vv_settings_toggle_audio() {
    return vv_settings_set_audio_enabled(!audio_enabled);
}
