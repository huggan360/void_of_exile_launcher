class_name Accounts
extends RefCounted
## Saved logins (username -> session token). Passwords are never stored.

const FILE := "user://accounts.cfg"

var cfg := ConfigFile.new()


func _init() -> void:
	cfg.load(FILE)


func saved() -> Dictionary:
	return cfg.get_value("accounts", "saved", {})


func current() -> String:
	var name := str(cfg.get_value("accounts", "current", ""))
	return name if saved().has(name) else ""


func token(name := "") -> String:
	return str(saved().get(name if name != "" else current(), ""))


func add(name: String, session: String) -> void:
	var all := saved()
	all[name] = session
	cfg.set_value("accounts", "saved", all)
	cfg.set_value("accounts", "current", name)
	cfg.save(FILE)


func use(name: String) -> void:
	cfg.set_value("accounts", "current", name)
	cfg.save(FILE)


func forget(name: String) -> void:
	var all := saved()
	all.erase(name)
	cfg.set_value("accounts", "saved", all)
	if current() == "" or str(cfg.get_value("accounts", "current", "")) == name:
		cfg.set_value("accounts", "current", all.keys()[0] if not all.is_empty() else "")
	cfg.save(FILE)
