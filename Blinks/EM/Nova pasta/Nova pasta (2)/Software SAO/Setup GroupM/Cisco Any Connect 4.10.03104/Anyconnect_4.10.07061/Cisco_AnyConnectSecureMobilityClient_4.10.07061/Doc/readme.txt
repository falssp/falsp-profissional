
+===============================================================================================+
1. General Information 
+===============================================================================================+
 GDC Location:   Poland
 PACKAGER NAME:  Daniel Grudzien
 PACKAGING POOL: n/a
 DATE:           21.06.2023
 TICKETING #:    INC14459930
+===============================================================================================+
2. Application 
+===============================================================================================+
 VENDOR:	Cisco
 APPLICATION:	AnyConnectSecureMobilityClient
 VERSION: 	4.10.07061
 DEPENDENCIES: 	[-] 
 LICENSE: 	[-] 
+===============================================================================================+
3. Package
+===============================================================================================+
 PACKAGE FORMAT: 	Vendor MSI, MST, Script
 PACKAGE NAME: 		Cisco_AnyConnectSecureMobilityClient_4.10.07061_WPP_W10_EN_B1
 OPERATING SYSTEM: 	W10 64bit 
 REBOOT BEFORE:		Install[] Uninstall[] None[x]
 REBOOT AFTER:		Install[] Uninstall[] None[x]
 PACKAGE WRAPPER:  	VBS 

 INSTALL COMMANDLINE:   Deploy-Application_4.exe -DeploymentType Install
 UNINSTALL COMMANDLINE: Deploy-Application_4.exe -DeploymentType Uninstall 

 PRODUCT NAME:	  Cisco AnyConnect Secure Mobility Client
 PRODUCT VERSION: 4.10.07061		
 PRODUCT CODE:	  {11E16B39-0FA6-4DF0-9736-73BB638C9924}		
 UPGRADE CODE:	  {BCCCB25E-C6A6-4340-9018-DA0FB34AF226}

 To check if application was installed: 	
 GUID1: 		 {11E16B39-0FA6-4DF0-9736-73BB638C9924}
 DISPLAYNAME1:		 Cisco AnyConnect Secure Mobility Client
 VERSION1 FROM REGISTRY: 4.10.07061
+===============================================================================================+
4. Packaging Notes:   (Deviations from best practices/standards, package notes for QA testers)
+===============================================================================================+

INFORMATION ABOUT OLDER VERSION IN PRF: Yes[] No[x]



During installation and uninstallation the package kills Cisco AnyConnect Secure Mobility Client processes:
acextwebhelper.exe
acwebhelper.exe
InstallHelper.exe
InstallHelper64.exe
manifesttool.exe
ProxyCon.exe
VACon64.exe
vpnagent.exe
vpncli.exe
vpndownloader.exe
vpnmgmttun.exe
vpnui.exe

INFO:
This package allows to reinstall.

Application can run only on one user at a time.

Configuration file is not included in the package.

This package upgrades the previous versions of the application (The upgrade was tested on versions mentioned in PRF document).  
Cisco_AnyConnectSecureMobilityClient_4.10.05111_WPP_W10_EN_B1_CLIENT_WP01415

+===============================================================================================+
5. Testing Notes:     (Testing notes for QA testers)
+===============================================================================================+
5a. Pre-Installation Requirements:
----------------------------------
1.none

*****************************************************
* PACKAGE INSTALLATION - USING INSTALL COMMANDLINE  *
*****************************************************

5b. Post-Installation Requirements:
----------------------------------
1.none

**********************************************************
* TEST APPLICATION - USING TESTING INSTRUCTIONS FROM PRF *
**********************************************************

5c. Pre-Uninstall Requirements:
--------------------------------
1.none

********************************************************
* PACKAGE UNINSTALLATION - USING UNINSTALL COMMANDLINE *
********************************************************

5d. Post-Uninstall Requirements:
--------------------------------
1.none
