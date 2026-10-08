	Sub CenterWindow( widthX, heightY )
		self.ResizeTo widthX, heightY
		self.MoveTo (screen.Width - widthX)/2, (screen.Height - heightY)/2
	End Sub
	'*******************************************************************************************************************************************' 
	Sub progressBarSetup
		pbHeight = 10        		' Progress bar height
		pbWidth= 380         		' Progress bar width
		pbUnloadedColor="white"		' Color of unloaded area
		pbLoadedColor="red"       	' Color of loaded area
		pbBorder="grey"        		' Color of Progress bar border
		pbStartTime = Now			' Time when start
		rProgressbar				' Progress bar
		pbTimerID = window.setInterval("rProgressbar", 200)
	End Sub
	'*******************************************************************************************************************************************' 
	Sub rProgressbar
		pbHTML = ""
		pbSecsPassed = DateDiff("s",pbStartTime,Now)
		pbMinsToGo =  Int((pbWaitTime - pbSecsPassed) / 60)
		pbSecsToGo = Int((pbWaitTime - pbSecsPassed) - (pbMinsToGo * 60))

		If pbSecsToGo < 10 Then
			pbSecsToGo = "0" & pbSecsToGo
		End If

		pbLoadedWidth = (pbSecsPassed / pbWaittime) * pbWidth
		pbUnloadedWidth = pbWidth - pbLoadedWidth

		pbHTML = pbHTML & "<table border=1 bordercolor=" & pbBorder & " cellpadding=0 cellspacing=0 width=" & pbWidth & "><tr>"
		pbHTML = pbHTML & "<th width=" & pbLoadedWidth & " height=" & pbHeight & "align=left bgcolor="  & pbLoadedColor & "></th>"
		pbHTML = pbHTML & "<th width=" & pbUnloadedWidth & " height=" & pbHeight & "align=left bgcolor="  & pbUnLoadedColor & "></th>"
		pbHTML = pbHTML & "</tr></table><br>"
		pbHTML = pbHTML & "<table border=0 cellpadding=0 cellspacing=0 width=" & pbWidth & "><tr>"
		pbHTML = pbHTML & "<td align=center width=" & pbWidth & "% height=" & pbHeight & "><b><font FACE=""arial"" SIZE=""3""> Time remaining: " & pbMinsToGo & ":" & pbSecsToGo & "</font></b></td>"
		pbHTML = pbHTML & "</tr></table>"
		progressbar.InnerHTML = pbHTML

		If DateDiff("s",pbStartTime,Now) >= pbWaitTime Then
			If isHide = false Then
				StopTimer
				RestartNow
			Else
				CenterWindow  550,250
				pbWaitTime = pbWaitTimeTMP
				isHide = false
				progressBarSetup
			End If
		End If
	End Sub
	'*******************************************************************************************************************************************' 
	Sub StopTimer
		window.clearInterval(PBTimerID)
	End Sub
	'*******************************************************************************************************************************************' 
	Sub RestartLater
		window.moveTo -2000,-2000
		isHide = true
	End Sub
	'*******************************************************************************************************************************************' 
	Sub RestartNow
		call InstallSoftware()
	End Sub
	'*******************************************************************************************************************************************' 
	Sub DoAction
		call InstallSoftware()
	End Sub
	'*******************************************************************************************************************************************' 
	Sub SaveTime
		call closeWindow()
		'dodac zapisywanie aktualnego time na potrzeby restartu okna
	End Sub
	'*******************************************************************************************************************************************' 
	Sub rTimer 
		pbSecsPassed = DateDiff("s",pbStartTime,Now) 
		pbMinsToGo =  Int((pbWaitTime - pbSecsPassed) / 60) 
		pbSecsToGo = Int((pbWaitTime - pbSecsPassed) - (pbMinsToGo * 60)) 

		if pbSecsToGo < 10 then 
			pbSecsToGo = "0" & pbSecsToGo  
		end if 
							
		if DateDiff("s",pbStartTime,Now) >= pbWaitTime then 
			StopTimer 
			DoAction 
		end if 
	End Sub 
	'*******************************************************************************************************************************************' 
	Sub langSplitter
		For Each oOption in oSelect.Options 
			oOption.RemoveNode 
		Next
				
		For Each oLangSplit in oLang
			SetOption oLangSplit, oLangSplit
		Next
	End Sub
	'*******************************************************************************************************************************************' 
	Sub SetOption(OptText,OptValue) 
		Set oNewOption = Document.CreateElement("OPTION")
		oNewOption.Text = OptText 
		oNewOption.Value = OptValue 
		oSelect.options.Add(oNewOption) 
	End Sub
	'*******************************************************************************************************************************************' 
	Sub LangSelect
		For Each objOption in lang.Options
			If objOption.Selected Then
				Msgbox objOption.InnerText
				RetCode = objOption.InnerText
			End If
		Next
	End Sub
	'*******************************************************************************************************************************************' 
	Sub Progress
		x = x + 1
		
		document.Title = MyTitle
		document.all.ProgBarText.innerText = Progress_caption
		document.all.ProgBarDone.innerText = String(x, "_")
		document.all.ProgBarToDo.innerText = String(y-x, "_") & "|"
		
		If x = y Then
			document.all.ProgBarToDo.innerText = ""
			x = 0
		End If
	End Sub