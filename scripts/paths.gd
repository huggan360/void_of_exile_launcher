class_name Paths
extends RefCounted
## Where the launcher installs the game and the server build (the "library").
##
## Windows: the folder the installer put the launcher in, one level up from its
## Launcher folder (by default %LOCALAPPDATA%\Programs\Void of Exile, Windows'
## own folder for programs installed per user: updates never need an admin
## prompt), with Game and Server beside Launcher. Elsewhere: the launcher's data
## folder. Settings can move the library (launcher.cfg, [paths] library).

const FILE := "user://launcher.cfg"


static func default_library() -> String:
	if OS.get_name() == "Windows":
		var exe_dir := OS.get_executable_path().get_base_dir()
		if exe_dir.get_file().to_lower() == "launcher":
			return exe_dir.get_base_dir()
		var local := OS.get_environment("LOCALAPPDATA")
		if local != "":
			return local.path_join("Programs").path_join("Void of Exile")
	return OS.get_user_data_dir()


static func library() -> String:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	var chosen := str(cfg.get_value("paths", "library", ""))
	return chosen if chosen != "" else default_library()


static func set_library(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	cfg.set_value("paths", "library", "" if path == default_library() else path)
	cfg.save(FILE)


static func game_dir(root := "") -> String:
	return (root if root != "" else library()).path_join("Game" if OS.get_name() == "Windows" else "game")


static func server_dir(root := "") -> String:
	return (root if root != "" else library()).path_join("Server" if OS.get_name() == "Windows" else "server_build")
