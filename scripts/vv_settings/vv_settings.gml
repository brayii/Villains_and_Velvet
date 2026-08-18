/// Versioned player preferences. Match state and future AI learning data are kept separate.

function vv_settings_defaults() {
    return {
        settings_version: 5,
        enemy_targeting_mode: "auto",
        audio_enabled: true,
        guided_tutorial_complete: false,
        hint_turn_steps: false,
        hint_enemy_event: false,
        hint_build: false,
        hint_drag: false,
        hint_inspect: false,
        hint_attack: false
    };
}

function vv_settings_decode(_text) {
    var defaults = vv_settings_defaults();
    try {
        var loaded = json_parse(_text);
        if (!is_struct(loaded)
        || !variable_struct_exists(loaded, "settings_version")
        || loaded.settings_version < 1 || loaded.settings_version > defaults.settings_version
        || !variable_struct_exists(loaded, "enemy_targeting_mode")
        || !is_string(loaded.enemy_targeting_mode)) {
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
            guided_tutorial_complete:version >= 5
                && variable_struct_exists(loaded, "guided_tutorial_complete")
                ? loaded.guided_tutorial_complete : false,
            hint_turn_steps:version >= 4 && variable_struct_exists(loaded, "hint_turn_steps") ? loaded.hint_turn_steps : false,
            hint_enemy_event:version >= 2 && variable_struct_exists(loaded, "hint_enemy_event") ? loaded.hint_enemy_event : false,
            hint_build:version >= 4 && variable_struct_exists(loaded, "hint_build") ? loaded.hint_build : false,
            hint_drag:version >= 2 && variable_struct_exists(loaded, "hint_drag") ? loaded.hint_drag : false,
            hint_inspect:version >= 2 && variable_struct_exists(loaded, "hint_inspect") ? loaded.hint_inspect : false,
            hint_attack:version >= 4 && variable_struct_exists(loaded, "hint_attack") ? loaded.hint_attack : false
        };
    } catch (_error) {
        return {valid:false, enemy_auto_play:true};
    }
}

function vv_settings_init() {
    settings_filename = "villains_and_velvet_settings.json";
    settings_version = 5;
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
    settings_dirty = true;
    if (!file_exists(settings_filename)) return false;

    var settings_text = "";
    try {
        var settings_file = file_text_open_read(settings_filename);
        while (!file_text_eof(settings_file)) {
            settings_text += file_text_read_string(settings_file);
            file_text_readln(settings_file);
        }
        file_text_close(settings_file);
    } catch (_error) {
        return false;
    }

    var decoded = vv_settings_decode(settings_text);
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
    }
    settings_dirty = !decoded.valid || (decoded.valid && decoded.upgraded);
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
        hint_attack: hint_attack
    };
    try {
        var settings_file = file_text_open_write(settings_filename);
        file_text_write_string(settings_file, json_stringify(settings_data));
        file_text_close(settings_file);
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
