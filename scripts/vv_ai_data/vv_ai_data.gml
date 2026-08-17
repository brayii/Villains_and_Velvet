/// Versioned Enemy AI learning data. Player settings and live match state are never stored here.

function vv_ai_data_defaults() {
    return {
        ai_data_version: 1,
        W_H: 1.0,
        conditional_exposures: 0,
        conditional_activations: 0,
        reward_ema: 0,
        auto_turn_count: 0,
        meaningful_ai_choice_count: 0,
        games_won_auto: 0,
        games_lost_auto: 0
    };
}

function vv_ai_data_is_finite_number(_value) {
    return is_real(_value) && !is_nan(_value) && !is_infinity(_value);
}

function vv_ai_data_is_counter(_value) {
    return vv_ai_data_is_finite_number(_value) && _value >= 0 && floor(_value) == _value;
}

function vv_ai_data_decode(_text) {
    var defaults = vv_ai_data_defaults();
    var result = {
        valid: false,
        data: defaults
    };

    try {
        var loaded = json_parse(_text);
        if (!is_struct(loaded)
        || !variable_struct_exists(loaded, "ai_data_version")
        || loaded.ai_data_version != defaults.ai_data_version) {
            return result;
        }

        var repaired = false;
        var data = vv_ai_data_defaults();

        if (variable_struct_exists(loaded, "W_H") && vv_ai_data_is_finite_number(loaded.W_H)) {
            data.W_H = clamp(loaded.W_H, 0.25, 3.0);
            if (data.W_H != loaded.W_H) repaired = true;
        } else repaired = true;

        if (variable_struct_exists(loaded, "conditional_exposures")
        && vv_ai_data_is_counter(loaded.conditional_exposures)) {
            data.conditional_exposures = loaded.conditional_exposures;
        } else repaired = true;

        if (variable_struct_exists(loaded, "conditional_activations")
        && vv_ai_data_is_counter(loaded.conditional_activations)
        && loaded.conditional_activations <= data.conditional_exposures) {
            data.conditional_activations = loaded.conditional_activations;
        } else repaired = true;

        if (variable_struct_exists(loaded, "reward_ema")
        && vv_ai_data_is_finite_number(loaded.reward_ema)) {
            data.reward_ema = loaded.reward_ema;
        } else repaired = true;

        var counter_names = [
            "auto_turn_count",
            "meaningful_ai_choice_count",
            "games_won_auto",
            "games_lost_auto"
        ];
        for (var i = 0; i < array_length(counter_names); i++) {
            var field = counter_names[i];
            if (variable_struct_exists(loaded, field)) {
                var value = variable_struct_get(loaded, field);
                if (vv_ai_data_is_counter(value)) {
                    variable_struct_set(data, field, value);
                } else repaired = true;
            } else repaired = true;
        }

        result.valid = !repaired;
        result.data = data;
        return result;
    } catch (_error) {
        return result;
    }
}

function vv_ai_data_apply(_data) {
    ai_health_weight = _data.W_H;
    ai_conditional_exposures = _data.conditional_exposures;
    ai_conditional_activations = _data.conditional_activations;
    ai_reward_ema = _data.reward_ema;
    ai_auto_turn_count = _data.auto_turn_count;
    ai_meaningful_choice_count = _data.meaningful_ai_choice_count;
    ai_games_won_auto = _data.games_won_auto;
    ai_games_lost_auto = _data.games_lost_auto;
}

function vv_ai_data_current() {
    return {
        ai_data_version: ai_data_version,
        W_H: ai_health_weight,
        conditional_exposures: ai_conditional_exposures,
        conditional_activations: ai_conditional_activations,
        reward_ema: ai_reward_ema,
        auto_turn_count: ai_auto_turn_count,
        meaningful_ai_choice_count: ai_meaningful_choice_count,
        games_won_auto: ai_games_won_auto,
        games_lost_auto: ai_games_lost_auto
    };
}

function vv_ai_data_init() {
    ai_data_filename = "villains_and_velvet_ai_data.json";
    ai_data_version = 1;
    ai_data_dirty = true;
    vv_ai_data_apply(vv_ai_data_defaults());
    vv_ai_data_load();
    vv_ai_data_save_if_dirty();
}

function vv_ai_data_load() {
    vv_ai_data_apply(vv_ai_data_defaults());
    ai_data_dirty = true;
    if (!file_exists(ai_data_filename)) return false;

    var data_text = "";
    try {
        var data_file = file_text_open_read(ai_data_filename);
        while (!file_text_eof(data_file)) {
            data_text += file_text_read_string(data_file);
            file_text_readln(data_file);
        }
        file_text_close(data_file);
    } catch (_error) {
        return false;
    }

    var decoded = vv_ai_data_decode(data_text);
    vv_ai_data_apply(decoded.data);
    ai_data_dirty = !decoded.valid;
    return decoded.valid;
}

function vv_ai_data_save_if_dirty() {
    if (!ai_data_dirty) return true;
    try {
        var data_file = file_text_open_write(ai_data_filename);
        file_text_write_string(data_file, json_stringify(vv_ai_data_current()));
        file_text_close(data_file);
        ai_data_dirty = false;
        return true;
    } catch (_error) {
        ai_data_dirty = true;
        return false;
    }
}

/// Developer/test entry point. Call only after the test UI has confirmed the reset.
function vv_ai_data_reset_enemy_learning(_confirmed) {
    if (_confirmed != true) return false;
    vv_ai_data_apply(vv_ai_data_defaults());
    ai_data_dirty = true;
    return vv_ai_data_save_if_dirty();
}

function vv_ai_data_run_self_checks() {
    var valid_data = vv_ai_data_defaults();
    valid_data.W_H = 2.25;
    valid_data.conditional_exposures = 9;
    valid_data.conditional_activations = 4;
    valid_data.reward_ema = -1.5;
    valid_data.auto_turn_count = 7;
    var decoded = vv_ai_data_decode(json_stringify(valid_data));
    if (!decoded.valid || decoded.data.W_H != 2.25
    || decoded.data.conditional_activations != 4 || decoded.data.auto_turn_count != 7) {
        return {valid:false, message:"AI data valid-load check failed"};
    }

    var partial = vv_ai_data_defaults();
    partial.W_H = 2.5;
    partial.conditional_exposures = 3;
    partial.conditional_activations = 4;
    partial.games_won_auto = 6;
    decoded = vv_ai_data_decode(json_stringify(partial));
    if (decoded.valid || decoded.data.W_H != 2.5
    || decoded.data.conditional_exposures != 3
    || decoded.data.conditional_activations != 0
    || decoded.data.games_won_auto != 6) {
        return {valid:false, message:"AI data field-repair check failed"};
    }

    decoded = vv_ai_data_decode("{broken");
    if (decoded.valid || decoded.data.W_H != 1.0 || decoded.data.auto_turn_count != 0) {
        return {valid:false, message:"AI data corruption recovery check failed"};
    }

    var old_version = vv_ai_data_defaults();
    old_version.ai_data_version = 0;
    old_version.W_H = 3.0;
    decoded = vv_ai_data_decode(json_stringify(old_version));
    if (decoded.valid || decoded.data.W_H != 1.0) {
        return {valid:false, message:"AI data version recovery check failed"};
    }

    return {valid:true, message:""};
}
