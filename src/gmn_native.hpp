#pragma once

#include <atomic>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

namespace godot {

class FileDialog;
class Button;

class GMNNativeBridge : public Node {
	GDCLASS(GMNNativeBridge, Node)

public:
	GMNNativeBridge();
	~GMNNativeBridge() override;

	void _ready() override;
	void _process(double delta) override;
	void _exit_tree() override;

	String get_report() const;
	String get_diagnostic() const;
	bool is_complete() const;
	bool is_ready() const;

protected:
	static void _bind_methods();

private:
#ifdef _WIN32
	static LRESULT CALLBACK mouse_hook_proc(int n_code, WPARAM w_param, LPARAM l_param);
	static HHOOK mouse_hook;
	static GMNNativeBridge *active_instance;
	std::atomic<int> pending_buttons{0};
#endif

	PackedStringArray events;
	bool ready = false;
	bool m4_success = false;
	bool m5_success = false;
	bool complete = false;
	bool input_received = false;
	bool target_found = false;
	bool action_invoked = false;
	bool effect_observed = false;
	int m4_count = 0;
	int m5_count = 0;
	String last_error = "none";
	String last_checkpoint = "PROBE-001_NATIVE_XBUTTON_PASS";
	String last_before_dir;
	String last_after_dir;

	void install_hook();
	void remove_hook();
	void handle_button(int button);
	FileDialog *find_visible_editor_file_dialog(Node *node) const;
	bool find_navigation_buttons(FileDialog *dialog, Button *&back, Button *&forward) const;
	void log_event(const String &kind, const String &detail = "");
	void fail(const String &phase, const String &message);
	String timeline_text() const;
};

} // namespace godot
