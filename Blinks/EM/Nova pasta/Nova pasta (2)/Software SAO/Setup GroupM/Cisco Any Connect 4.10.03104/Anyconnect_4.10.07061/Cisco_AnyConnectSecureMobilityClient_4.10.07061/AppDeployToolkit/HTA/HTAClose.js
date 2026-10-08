			function closeWithErrorlevel(errorlevel){
                var colProcesses = GetObject('winmgmts:{impersonationLevel=impersonate}!\\\\.\\root\\cimv2').ExecQuery('Select * from Win32_Process Where Name = \'mshta.exe\'');
                var myPath = (''+location.pathname).toLowerCase();
                var enumProcesses = new Enumerator(colProcesses);
                for ( var process = null ; !enumProcesses.atEnd() ; enumProcesses.moveNext() ) {
                    process = enumProcesses.item();
                    if ( (''+process.CommandLine).toLowerCase().indexOf(myPath) > 0 ){
                        process.Terminate(errorlevel);
                    }
                }
            }
			//************************************************************************************************************************************' 
			function InstallSoftware(){
				closeHTA(-10);
			}
			//************************************************************************************************************************************' 
			function Postpone(){
				closeHTA(-11);
			}
			//************************************************************************************************************************************' 
			function closeHTA(value){
                if (typeof value === 'undefined') value = 0; 
                try { closeWithErrorlevel(value) } catch (e) {};
            }
			//************************************************************************************************************************************' 
			function closeWindow(){
				closeHTA(0);
			}
			//************************************************************************************************************************************' 
			function setLang(){
				var x = document.getElementById("lang");
				var i = x.selectedIndex;
					closeHTA(i+1);
			}