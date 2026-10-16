	Dim pbTimerID, pbHTML, pbWaitTime, pbHeight, pbWidth, pbBorder, pbUnloadedColor, pbLoadedColor, pbStartTime, ScriptDir, pbWaitTimeTMP
	Dim oSelect, a, oLang, inLang, shell, iTimerID, myTitle, x ,y, Progress_caption
	
	Dim Progress_Unit	: Progress_Unit		= 21
	Dim timerTime		: timerTime 		= 0
	Dim RetCode 		: RetCode 			= 0
	Dim isHide 			: isHide 			= false

	Dim WshShell
		Set WshShell = CreateObject ("WScript.Shell")
	Dim objFSO
		Set objFSO = CreateObject("Scripting.FileSystemObject")
	Dim CurrentDirectory
		CurrentDirectory = WshShell.CurrentDirectory