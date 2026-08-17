/// Versioned player preferences. Match state and future AI learning data are kept separate.

function vv_settings_defaults() {
    return {
        settings_version: 1,
        enemy_targeting_mode: "manual"
    };
}

function vv_settings_decode(_text) {
    var defaults = vv_settings_defaults();
    try {
        var loaded = json_parse(_text);
        if (!is_struct(loaded)
        || !variable_struct_exists(loaded, "settings_version")
        || loaded.settings_version != defaults.settings_version
        || !variable_struct_exists(loaded, "enemy_targeting_mode")
        || !is_string(loaded.enemy_targeting_mode)) {
            return {valid:false, enemy_auto_play:false};
        }
        var mode = string_lower(loaded.enemy_targeting_mode);
        if (mode != "manual" && mode != "auto") {
            return {valid:false, enemy_auto_play:false};
        }
        return {valid:true, enemy_auto_play:mode == "auto"};
    } catch (_error) {
        return {valid:false, enemy_auto_play:false};
    }
}

function vv_settings_init() {
    settings_filename = "villains_and_velvet_settings.json";
    settings_version = 1;
    settings_dirty = true;
    enemy_auto_play = false;
    vv_settings_load();
    vv_settings_save_if_dirty();
}

function vv_settings_load() {
    enemy_auto_play = false;
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
    settings_dirty = !decoded.valid;
    return decoded.valid;
}

function vv_settings_save_if_dirty() {
    if (!settings_dirty) return true;
    var settings_data = {
        settings_version: settings_version,
        enemy_targeting_mode: enemy_auto_play ? "auto" : "manual"
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

function vv_settings_set_enemy_auto(_enabled) {
    var next_value = _enabled == true;
    if (enemy_auto_play == next_value) return false;
    enemy_auto_play = next_value;
    settings_dirty = true;
    vv_settings_save_if_dirty();
    return true;
}

function vv_settings_toggle_enemy_auto() {
    return vv_settings_set_enemy_auto(!enemy_auto_play);
}
