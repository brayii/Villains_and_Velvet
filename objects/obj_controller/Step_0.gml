// Automatic progress pauses for the full card gesture, including the first touch.
var card_gesture_active = !is_undefined(card_popup)
    || pointer_card_down;

if (!card_gesture_active && !setup_active && !game_over
&& device_mouse_check_button_pressed(0, mb_left)) {
    var gesture_x = device_mouse_x_to_gui(0);
    var gesture_y = device_mouse_y_to_gui(0);
    card_gesture_active = !is_undefined(ui_card_at_point(gesture_x, gesture_y));
}

if (!card_gesture_active) vv_turn_update();
vv_ui_handle_input();
