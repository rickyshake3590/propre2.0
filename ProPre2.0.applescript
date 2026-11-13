-- ProPre2.0 desktop app. Built into ~/Desktop/ProPre2.0.app by make_desktop_app.command.
-- Open the app to start ProPre2.0. Choose Quit (Cmd+Q) to stop it.
-- If the Mac sleeps or shuts down, the watcher stops ProPre2.0 and closes this app.

property projectFolder : "__PROJECT__"

on run
	-- Start in the background so the app can stay open and wait for Quit
	do shell script "nohup /bin/bash " & quoted form of (projectFolder & "/start_propre.command") & " >/dev/null 2>&1 </dev/null &"
end run

on idle
	-- Keeps the app open (it stays in the Dock) until Quit is chosen
	return 60
end idle

on quit
	do shell script "/bin/bash " & quoted form of (projectFolder & "/stop_propre.command") & " >/dev/null 2>&1"
	continue quit
end quit
