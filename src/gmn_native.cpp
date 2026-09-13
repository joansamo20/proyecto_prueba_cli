#include "gmn_native.hpp"

#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/file_dialog.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/v_box_container.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#ifdef _WIN32
static HMODULE g_gmn_module = nullptr;

BOOL APIENTRY DllMain(HMODULE h_module, DWORD reason, LPVOID) {
	if (reason == DLL_PROCESS_ATTACH) {
		g_gmn_module = h_module;
	}
	return TRUE;
}
#endif

namespace godot {

#ifdef _WIN32
HHOOK GMNNativeBridge::mouse_hook = nullptr;
GMNNativeBridge *GMNNativeBridge::active_instance = nullptr;
#endif

GMNNativeBridge::GMNNativeBridge() = default;

GMNNativeBridge::~GMNNativeBridge() {
	remove_hook();
}

void GMNNativeBridge::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_report"), &GMNNativeBridge::get_report);
	ClassDB::bind_method(D_METHOD("get_diagnostic"), &GMNNativeBridge::get_diagnostic);
	ClassDB::bind_method(D_METHOD("is_complete"), &GMNNativeBridge::is_complete);
	ClassDB::bind_method(D_METHOD("is_ready"), &GMNNativeBridge::is_ready);
}

void GMNNativeBridge::_ready() {
	log_event("session_started", "experiment=GMN-NATIVE-001");
	install_hook();
	set_process(true);
}

void GMNNativeBridge::_exit_tree() {
	remove_hook();
	log_event("session_finished", "bridge_exit_tree");
}

void GMNNativeBridge::_process(double) {
#ifdef _WIN32
	const int pending = pending_buttons.exchange(0);
	if (pending & 1) {
		handle_button(1);
	}
	if (pending & 2) {
		handle_button(2);
	}
#endif
}

void GMNNativeBridge::install_hook() {
#ifdef _WIN32
	if (mouse_hook != nullptr) {
		remove_hook();
	}
	active_instance = this;
	mouse_hook = SetWindowsHookExW(WH_MOUSE_LL, mouse_hook_proc, g_gmn_module, 0);
	if (mouse_hook == nullptr) {
		fail("layer0_hook_install", "SetWindowsHookExW(WH_MOUSE_LL) failed; win32_error=" + String::num_int64(GetLastError()));
		return;
	}
	ready = true;
	log_event("startup_ready", "hook=WH_MOUSE_LL;mapping=XBUTTON1_BACK,XBUTTON2_FORWARD");
	UtilityFunctions::print("GMN-NATIVE-001 READY | XBUTTON1=BACK | XBUTTON2=FORWARD");
#else
	fail("layer0_platform", "GMN-NATIVE-001 is Windows x64 only");
#endif
}

void GMNNativeBridge::remove_hook() {
#ifdef _WIN32
	if (mouse_hook != nullptr) {
		UnhookWindowsHookEx(mouse_hook);
		mouse_hook = nullptr;
	}
	if (active_instance == this) {
		active_instance = nullptr;
	}
#endif
}

#ifdef _WIN32
LRESULT CALLBACK GMNNativeBridge::mouse_hook_proc(int n_code, WPARAM w_param, LPARAM l_param) {
	if (n_code == HC_ACTION && active_instance != nullptr && w_param == WM_XBUTTONDOWN) {
		const MSLLHOOKSTRUCT *info = reinterpret_cast<const MSLLHOOKSTRUCT *>(l_param);
		if (info != nullptr) {
			DWORD foreground_pid = 0;
			HWND foreground = GetForegroundWindow();
			if (foreground != nullptr) {
				GetWindowThreadProcessId(foreground, &foreground_pid);
			}
			if (foreground_pid == GetCurrentProcessId()) {
				const WORD xbutton = HIWORD(info->mouseData);
				if (xbutton == XBUTTON1) {
					active_instance->pending_buttons.fetch_or(1);
				} else if (xbutton == XBUTTON2) {
					active_instance->pending_buttons.fetch_or(2);
				}
			}
		}
	}
	return CallNextHookEx(mouse_hook, n_code, w_param, l_param);
}
#endif

FileDialog *GMNNativeBridge::find_visible_editor_file_dialog(Node *node) const {
	if (node == nullptr) {
		return nullptr;
	}

	if (node->is_class(StringName("EditorFileDialog"))) {
		FileDialog *dialog = Object::cast_to<FileDialog>(node);
		if (dialog != nullptr && dialog->is_visible()) {
			return dialog;
		}
	}

	const int child_count = node->get_child_count(true);
	for (int i = 0; i < child_count; i++) {
		Node *child = node->get_child(i, true);
		FileDialog *found = find_visible_editor_file_dialog(child);
		if (found != nullptr) {
			return found;
		}
	}
	return nullptr;
}

bool GMNNativeBridge::find_navigation_buttons(FileDialog *dialog, Button *&back, Button *&forward) const {
	back = nullptr;
	forward = nullptr;
	if (dialog == nullptr) {
		return false;
	}

	VBoxContainer *vbox = dialog->get_vbox();
	if (vbox == nullptr || vbox->get_child_count(true) < 1) {
		return false;
	}

	Node *toolbar = vbox->get_child(0, true);
	if (toolbar == nullptr) {
		return false;
	}

	const int child_count = toolbar->get_child_count(true);
	for (int i = 0; i < child_count; i++) {
		Button *button = Object::cast_to<Button>(toolbar->get_child(i, true));
		if (button == nullptr) {
			continue;
		}
		if (back == nullptr) {
			back = button;
		} else if (forward == nullptr) {
			forward = button;
			break;
		}
	}

	return back != nullptr && forward != nullptr;
}

void GMNNativeBridge::handle_button(int button) {
	if (complete) {
		log_event("repeated_interaction", "checkpoint_already_reached");
		return;
	}

	input_received = true;
	if (button == 1) {
		m4_count++;
		log_event("input_received", "button=XBUTTON1;direction=BACK");
	} else {
		m5_count++;
		log_event("input_received", "button=XBUTTON2;direction=FORWARD");
	}

	SceneTree *tree = get_tree();
	if (tree == nullptr || tree->get_root() == nullptr) {
		fail("target_found", "SceneTree/root unavailable");
		return;
	}

	FileDialog *dialog = find_visible_editor_file_dialog(tree->get_root());
	if (dialog == nullptr) {
		target_found = false;
		log_event("target_found", "false;reason=no_visible_EditorFileDialog");
		return;
	}

	Button *back_button = nullptr;
	Button *forward_button = nullptr;
	if (!find_navigation_buttons(dialog, back_button, forward_button)) {
		target_found = false;
		fail("target_found", "visible EditorFileDialog found but Back/Forward buttons were not resolved");
		return;
	}

	target_found = true;
	log_event("target_found", "true;class=EditorFileDialog");

	Button *target = button == 1 ? back_button : forward_button;
	const String direction = button == 1 ? "BACK" : "FORWARD";
	last_before_dir = dialog->get_current_dir();

	action_invoked = true;
	log_event("action_invoked", "direction=" + direction + ";before=" + last_before_dir);
	target->emit_signal(StringName("pressed"));

	last_after_dir = dialog->get_current_dir();
	const bool changed = last_before_dir != last_after_dir;
	effect_observed = changed;
	log_event("effect_observed", "direction=" + direction + ";changed=" + String(changed ? "true" : "false") + ";after=" + last_after_dir);

	if (!changed) {
		return;
	}

	if (button == 1) {
		m4_success = true;
	} else {
		m5_success = true;
	}

	if (m4_success && m5_success) {
		complete = true;
		last_checkpoint = "GMN-NATIVE-001_EVIDENCE_SUFFICIENT";
		log_event("checkpoint_reached", "one_valid_back_plus_one_valid_forward");
		UtilityFunctions::print("GMN-NATIVE-001 LISTO | EVIDENCIA SUFICIENTE | reporte listo para copiar");
	}
}

void GMNNativeBridge::log_event(const String &kind, const String &detail) {
	const String line = String::num_int64(events.size() + 1).pad_zeros(4) + " | " + kind + " | " + detail;
	events.append(line);
}

void GMNNativeBridge::fail(const String &phase, const String &message) {
	last_error = "phase=" + phase + ";error=" + message;
	log_event("error", last_error);
	UtilityFunctions::push_error("GMN FAILED | " + last_error);
}

String GMNNativeBridge::timeline_text() const {
	String out;
	for (int i = 0; i < events.size(); i++) {
		out += events[i];
		out += "\n";
	}
	return out;
}

String GMNNativeBridge::get_report() const {
	String out;
	out += "REPORT_SCHEMA | AP_LOOP_V2_REPORT_1\n";
	out += "PROJECT_ID | GODOT_MOUSE_NAV_WIN\n";
	out += "APP_VERSION | GMN_NATIVE_0.1.0\n";
	out += "EXPERIMENT_ID | GMN-NATIVE-001\n";
	out += "VARIANT_ID | GDEXT-WIN64-001A\n";
	out += "MODE | EXECUTION\n\n";
	out += "OBJECTIVE\n";
	out += "input_received | " + String(input_received ? "true" : "false") + "\n";
	out += "target_found | " + String(target_found ? "true" : "false") + "\n";
	out += "action_invoked | " + String(action_invoked ? "true" : "false") + "\n";
	out += "effect_observed | " + String(effect_observed ? "true" : "false") + "\n";
	out += "back_valid | " + String(m4_success ? "true" : "false") + "\n";
	out += "forward_valid | " + String(m5_success ? "true" : "false") + "\n\n";
	out += "TIMELINE\n" + timeline_text() + "\n";
	out += "METRICS\n";
	out += "xbutton1_count | " + String::num_int64(m4_count) + "\n";
	out += "xbutton2_count | " + String::num_int64(m5_count) + "\n";
	out += "evidence_sufficient | " + String(complete ? "true" : "false") + "\n\n";
	out += "CHECKPOINTS\nlast_checkpoint | " + last_checkpoint + "\n\n";
	out += "ERRORS\n" + last_error + "\n\n";
	out += "FINAL_STATE\n" + String(complete ? "COMPLETED" : (last_error == "none" ? "INCOMPLETE" : "FAILED")) + "\n\n";
	out += "DIAGNOSTICS\n";
	out += "runtime | Godot GDExtension / Windows x64\n";
	out += "before_dir | " + last_before_dir + "\n";
	out += "after_dir | " + last_after_dir + "\n\n";
	out += "INTERPRETATION_REQUEST\nInterpret only the earliest failed pipeline stage: input_received -> target_found -> action_invoked -> effect_observed.\n";
	return out;
}

String GMNNativeBridge::get_diagnostic() const {
	String out;
	out += "PROJECT_ID | GODOT_MOUSE_NAV_WIN\n";
	out += "APP_VERSION | GMN_NATIVE_0.1.0\n";
	out += "EXPERIMENT_ID | GMN-NATIVE-001\n";
	out += "VARIANT_ID | GDEXT-WIN64-001A\n";
	out += "PHASE | runtime\n";
	out += "RUNTIME | GDExtension Windows x64\n";
	out += "READY | " + String(ready ? "true" : "false") + "\n";
	out += "ERROR | " + last_error + "\n";
	out += "LAST_CHECKPOINT | " + last_checkpoint + "\n";
	out += "INPUT_RECEIVED | " + String(input_received ? "true" : "false") + "\n";
	out += "TARGET_FOUND | " + String(target_found ? "true" : "false") + "\n";
	out += "ACTION_INVOKED | " + String(action_invoked ? "true" : "false") + "\n";
	out += "EFFECT_OBSERVED | " + String(effect_observed ? "true" : "false") + "\n";
	out += "INTERPRETATION_REQUEST | Diagnose the earliest failed pipeline stage only.\n";
	return out;
}

bool GMNNativeBridge::is_complete() const {
	return complete;
}

bool GMNNativeBridge::is_ready() const {
	return ready;
}

} // namespace godot
