#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$Silent,
    [switch]$RunAppConfigurator,
    [switch]$RunDefaults, [switch]$RunWin11Defaults,
    [switch]$RunSavedSettings,
    [switch]$RemoveApps, 
    [switch]$RemoveAppsCustom,
    [switch]$RemoveGamingApps,
    [switch]$RemoveCommApps,
    [switch]$RemoveDevApps,
    [switch]$RemoveW11Outlook,
    [switch]$ForceRemoveEdge,
    [switch]$DisableDVR,
    [switch]$DisableTelemetry,
    [switch]$DisableBingSearches, [switch]$DisableBing,
    [switch]$DisableDesktopSpotlight,
    [switch]$DisableLockscrTips, [switch]$DisableLockscreenTips,
    [switch]$DisableWindowsSuggestions, [switch]$DisableSuggestions,
    [switch]$ShowHiddenFolders,
    [switch]$ShowKnownFileExt,
    [switch]$HideDupliDrive,
    [switch]$TaskbarAlignLeft,
    [switch]$HideSearchTb, [switch]$ShowSearchIconTb, [switch]$ShowSearchLabelTb, [switch]$ShowSearchBoxTb,
    [switch]$HideTaskview,
    [switch]$DisableCopilot,
    [switch]$DisableRecall,
    [switch]$DisableWidgets,
    [switch]$HideWidgets,
    [switch]$DisableChat,
    [switch]$HideChat,
    [switch]$ClearStart,
    [switch]$ClearStartAllUsers,
    [switch]$RevertContextMenu,
    [switch]$HideHome,
    [switch]$HideGallery,
    [switch]$ExplorerToHome,
    [switch]$ExplorerToThisPC,
    [switch]$ExplorerToDownloads,
    [switch]$ExplorerToOneDrive,
    [switch]$DisableOnedrive, [switch]$HideOnedrive,
    [switch]$Disable3dObjects, [switch]$Hide3dObjects,
    [switch]$DisableMusic, [switch]$HideMusic,
    [switch]$DisableIncludeInLibrary, [switch]$HideIncludeInLibrary,
    [switch]$DisableGiveAccessTo, [switch]$HideGiveAccessTo,
    [switch]$DisableShare, [switch]$HideShare,
    [switch]$SharingWizardOn,
    [switch]$FullPath,
    [switch]$NavPaneShowAllFolders,
    [switch]$AutoSetup,
    [switch]$DesktopIcons,
    [switch]$ShowFrequentList,
    [switch]$StartLayout,
    [switch]$HiberbootEnabled,
	[switch]$HideNewOutlookToggle,
 	[switch]$HighPerformance
)


# Show error if current powershell environment does not have LanguageMode set to FullLanguage 
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Host "Error: Win11Debloat is unable to run on your system, powershell execution is restricted by security policies" -ForegroundColor Red
    Write-Output ""
    Write-Output "Press enter to exit..."
    Read-Host | Out-Null
    Exit
}

# Shows application selection form that allows the user to select what apps they want to remove or keep
function ShowAppSelectionForm {
    [reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
    [reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null

    # Initialise form objects
    $form = New-Object System.Windows.Forms.Form
    $label = New-Object System.Windows.Forms.Label
    $button1 = New-Object System.Windows.Forms.Button
    $button2 = New-Object System.Windows.Forms.Button
    $selectionBox = New-Object System.Windows.Forms.CheckedListBox 
    $loadingLabel = New-Object System.Windows.Forms.Label
    $onlyInstalledCheckBox = New-Object System.Windows.Forms.CheckBox
    $checkUncheckCheckBox = New-Object System.Windows.Forms.CheckBox
    $initialFormWindowState = New-Object System.Windows.Forms.FormWindowState

    $global:selectionBoxIndex = -1

    # saveButton eventHandler
    $handler_saveButton_Click= 
    {
        if ($selectionBox.CheckedItems -contains "Microsoft.WindowsStore" -and -not $Silent) {
            $warningSelection = [System.Windows.Forms.Messagebox]::Show('Are you sure you wish to uninstall the Microsoft Store? This app cannot easily be reinstalled.', 'Are you sure?', 'YesNo', 'Warning')
        
            if ($warningSelection -eq 'No') {
                return
            }
        }

        $global:SelectedApps = $selectionBox.CheckedItems

        # Create file that stores selected apps if it doesn't exist
        if (!(Test-Path "$PSScriptRoot/CustomAppsList")) {
            $null = New-Item "$PSScriptRoot/CustomAppsList"
        } 

        Set-Content -Path "$PSScriptRoot/CustomAppsList" -Value $global:SelectedApps

        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    }

    # cancelButton eventHandler
    $handler_cancelButton_Click= 
    {
        $form.Close()
    }

    $selectionBox_SelectedIndexChanged= 
    {
        $global:selectionBoxIndex = $selectionBox.SelectedIndex
    }

    $selectionBox_MouseDown=
    {
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            if ([System.Windows.Forms.Control]::ModifierKeys -eq [System.Windows.Forms.Keys]::Shift) {
                if ($global:selectionBoxIndex -ne -1) {
                    $topIndex = $global:selectionBoxIndex

                    if ($selectionBox.SelectedIndex -gt $topIndex) {
                        for (($i = ($topIndex)); $i -le $selectionBox.SelectedIndex; $i++){
                            $selectionBox.SetItemChecked($i, $selectionBox.GetItemChecked($topIndex))
                        }
                    }
                    elseif ($topIndex -gt $selectionBox.SelectedIndex) {
                        for (($i = ($selectionBox.SelectedIndex)); $i -le $topIndex; $i++){
                            $selectionBox.SetItemChecked($i, $selectionBox.GetItemChecked($topIndex))
                        }
                    }
                }
            }
            elseif ($global:selectionBoxIndex -ne $selectionBox.SelectedIndex) {
                $selectionBox.SetItemChecked($selectionBox.SelectedIndex, -not $selectionBox.GetItemChecked($selectionBox.SelectedIndex))
            }
        }
    }

    $check_All=
    {
        for (($i = 0); $i -lt $selectionBox.Items.Count; $i++){
            $selectionBox.SetItemChecked($i, $checkUncheckCheckBox.Checked)
        }
    }

    $load_Apps=
    {
        # Correct the initial state of the form to prevent the .Net maximized form issue
        $form.WindowState = $initialFormWindowState

        # Reset state to default before loading appslist again
        $global:selectionBoxIndex = -1
        $checkUncheckCheckBox.Checked = $False

        # Show loading indicator
        $loadingLabel.Visible = $true
        $form.Refresh()

        # Clear selectionBox before adding any new items
        $selectionBox.Items.Clear()

        # Set filePath where Appslist can be found
        $appsFile = "$PSScriptRoot/Appslist.txt"
        $listOfApps = ""

        if ($onlyInstalledCheckBox.Checked -and ($global:wingetInstalled -eq $true)) {
            # Attempt to get a list of installed apps via winget, times out after 10 seconds
            $job = Start-Job { return winget list --accept-source-agreements --disable-interactivity }
            $jobDone = $job | Wait-Job -TimeOut 10

            if (-not $jobDone) {
                # Show error that the script was unable to get list of apps from winget
                [System.Windows.MessageBox]::Show('Unable to load list of installed apps via winget, some apps may not be displayed in the list.', 'Error', 'Ok', 'Error')
            }
            else {
                # Add output of job (list of apps) to $listOfApps
                $listOfApps = Receive-Job -Job $job
            }
        }

        # Go through appslist and add items one by one to the selectionBox
        Foreach ($app in (Get-Content -Path $appsFile | Where-Object { $_ -notmatch '^\s*$' -and $_ -notmatch '^#  .*' -and $_ -notmatch '^# -* #' } )) { 
            $appChecked = $true

            # Remove first # if it exists and set appChecked to false
            if ($app.StartsWith('#')) {
                $app = $app.TrimStart("#")
                $appChecked = $false
            }

            # Remove any comments from the Appname
            if (-not ($app.IndexOf('#') -eq -1)) {
                $app = $app.Substring(0, $app.IndexOf('#'))
            }
            
            # Remove leading and trailing spaces and `*` characters from Appname
            $app = $app.Trim()
            $appString = $app.Trim('*')

            # Make sure appString is not empty
            if ($appString.length -gt 0) {
                if ($onlyInstalledCheckBox.Checked) {
                    # onlyInstalledCheckBox is checked, check if app is installed before adding it to selectionBox
                    if (-not ($listOfApps -like ("*$appString*")) -and -not (Get-AppxPackage -Name $app)) {
                        # App is not installed, continue with next item
                        continue
                    }
                    if (($appString -eq "Microsoft.Edge") -and -not ($listOfApps -like "* Microsoft.Edge *")) {
                        # App is not installed, continue with next item
                        continue
                    }
                }

                # Add the app to the selectionBox and set it's checked status
                $selectionBox.Items.Add($appString, $appChecked) | Out-Null
            }
        }
        
        # Hide loading indicator
        $loadingLabel.Visible = $False

        # Sort selectionBox alphabetically
        $selectionBox.Sorted = $True
    }

    $form.Text = "Win11Debloat Application Selection"
    $form.Name = "appSelectionForm"
    $form.DataBindings.DefaultDataSourceUpdateMode = 0
    $form.ClientSize = New-Object System.Drawing.Size(400,502)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $False

    $button1.TabIndex = 4
    $button1.Name = "saveButton"
    $button1.UseVisualStyleBackColor = $True
    $button1.Text = "Confirm"
    $button1.Location = New-Object System.Drawing.Point(27,472)
    $button1.Size = New-Object System.Drawing.Size(75,23)
    $button1.DataBindings.DefaultDataSourceUpdateMode = 0
    $button1.add_Click($handler_saveButton_Click)

    $form.Controls.Add($button1)

    $button2.TabIndex = 5
    $button2.Name = "cancelButton"
    $button2.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $button2.UseVisualStyleBackColor = $True
    $button2.Text = "Cancel"
    $button2.Location = New-Object System.Drawing.Point(129,472)
    $button2.Size = New-Object System.Drawing.Size(75,23)
    $button2.DataBindings.DefaultDataSourceUpdateMode = 0
    $button2.add_Click($handler_cancelButton_Click)

    $form.Controls.Add($button2)

    $label.Location = New-Object System.Drawing.Point(13,5)
    $label.Size = New-Object System.Drawing.Size(400,14)
    $Label.Font = 'Microsoft Sans Serif,8'
    $label.Text = 'Check apps that you wish to remove, uncheck apps that you wish to keep'

    $form.Controls.Add($label)

    $loadingLabel.Location = New-Object System.Drawing.Point(16,46)
    $loadingLabel.Size = New-Object System.Drawing.Size(300,418)
    $loadingLabel.Text = 'Loading apps...'
    $loadingLabel.BackColor = "White"
    $loadingLabel.Visible = $false

    $form.Controls.Add($loadingLabel)

    $onlyInstalledCheckBox.TabIndex = 6
    $onlyInstalledCheckBox.Location = New-Object System.Drawing.Point(230,474)
    $onlyInstalledCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $onlyInstalledCheckBox.Text = 'Only show installed apps'
    $onlyInstalledCheckBox.add_CheckedChanged($load_Apps)

    $form.Controls.Add($onlyInstalledCheckBox)

    $checkUncheckCheckBox.TabIndex = 7
    $checkUncheckCheckBox.Location = New-Object System.Drawing.Point(16,22)
    $checkUncheckCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $checkUncheckCheckBox.Text = 'Check/Uncheck all'
    $checkUncheckCheckBox.add_CheckedChanged($check_All)

    $form.Controls.Add($checkUncheckCheckBox)

    $selectionBox.FormattingEnabled = $True
    $selectionBox.DataBindings.DefaultDataSourceUpdateMode = 0
    $selectionBox.Name = "selectionBox"
    $selectionBox.Location = New-Object System.Drawing.Point(13,43)
    $selectionBox.Size = New-Object System.Drawing.Size(374,424)
    $selectionBox.TabIndex = 3
    $selectionBox.add_SelectedIndexChanged($selectionBox_SelectedIndexChanged)
    $selectionBox.add_Click($selectionBox_MouseDown)

    $form.Controls.Add($selectionBox)

    # Save the initial state of the form
    $initialFormWindowState = $form.WindowState

    # Load apps into selectionBox
    $form.add_Load($load_Apps)

    # Focus selectionBox when form opens
    $form.Add_Shown({$form.Activate(); $selectionBox.Focus()})

    # Show the Form
    return $form.ShowDialog()
}


# Returns list of apps from the specified file, it trims the app names and removes any comments
function ReadAppslistFromFile {
    param (
        $appsFilePath
    )

    $appsList = @()

    # Get list of apps from file at the path provided, and remove them one by one
    Foreach ($app in (Get-Content -Path $appsFilePath | Where-Object { $_ -notmatch '^#.*' -and $_ -notmatch '^\s*$' } )) { 
        # Remove any comments from the Appname
        if (-not ($app.IndexOf('#') -eq -1)) {
            $app = $app.Substring(0, $app.IndexOf('#'))
        }

        # Remove any spaces before and after the Appname
        $app = $app.Trim()
        
        $appString = $app.Trim('*')
        $appsList += $appString
    }

    return $appsList
}


#--------------------------
function RemoveApps {
    [CmdletBinding()]
    param ([string[]]$AppsList)

    Write-Host "> Configuring $($AppsList.Count) app(s)/package(s) system-wide..." -ForegroundColor Yellow
    $WingetPath = Get-Command winget -ErrorAction SilentlyContinue

    foreach ($AppPattern in $AppsList) {
        # --- Handle special cases first ---
        # ... (Your existing switch block for Copilot and Outlook Toggle goes here) ...

        # --- Universal Removal Logic ---
        Write-Output "--> Removing package: $AppPattern"
        try {
            # Step 1: Remove Provisioned Package via DISM (for FUTURE users)
            $ProvisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$AppPattern*" -or $_.PackageName -like "*$AppPattern*" }
            if ($ProvisionedPackages) {
                Write-Host "  - Removing provisioned package via DISM..."
                foreach ($Package in $ProvisionedPackages) {
                    $DismArgs = "/Online /Remove-ProvisionedAppxPackage /PackageName:$($Package.PackageName)"
                    Start-Process "dism.exe" -ArgumentList $DismArgs -Wait -NoNewWindow | Out-Null
                }
            }

            # Step 2: Remove for EXISTING users
            # For stubborn apps like Xbox, use Winget. For others, use Remove-AppxPackage.
            if ($AppPattern -like "*Microsoft.GamingApp*" -and $WingetPath) {
                Write-Host "  - Removing Xbox for existing users via winget..."
                Start-Process winget -ArgumentList "uninstall --id 9MV0B5HZVK9Z --accept-source-agreements --disable-interactivity --silent" -Wait -NoNewWindow | Out-Null
            } else {
                $Installed = Get-AppxPackage -AllUsers -Name "*$AppPattern*" -ErrorAction SilentlyContinue
                if ($Installed) {
                    Write-Host "  - Removing installed package from user profiles..."
                    $Installed | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Out-Null
                }
            }
        } catch { Write-Warning "  - An error occurred during the removal process for '$AppPattern'." }
    }
}
#------------------------------------------------


# Forcefully removes Microsoft Edge using it's uninstaller
function ForceRemoveEdge {
    # Based on work from loadstring1 & ave9858
    Write-Output "> Forcefully uninstalling Microsoft Edge..."

    $regView = [Microsoft.Win32.RegistryView]::Registry32
    $hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $regView)
    $hklm.CreateSubKey('SOFTWARE\Microsoft\EdgeUpdateDev').SetValue('AllowUninstall', '')

    # Create stub (Creating this somehow allows uninstalling edge)
    $edgeStub = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
    New-Item $edgeStub -ItemType Directory | Out-Null
    New-Item "$edgeStub\MicrosoftEdge.exe" | Out-Null

    # Remove edge
    $uninstallRegKey = $hklm.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge')
    if ($null -ne $uninstallRegKey) {
        Write-Output "Running uninstaller..."
        $uninstallString = $uninstallRegKey.GetValue('UninstallString') + ' --force-uninstall'
        Start-Process cmd.exe "/c $uninstallString" -WindowStyle Hidden -Wait

        Write-Output "Removing leftover files..."

        $edgePaths = @(
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Tombstones\Microsoft Edge.lnk",
            "$env:PUBLIC\Desktop\Microsoft Edge.lnk",
            "$env:USERPROFILE\Desktop\Microsoft Edge.lnk",
            "$edgeStub"
        )

        foreach ($path in $edgePaths){
            if (Test-Path -Path $path) {
                Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "  Removed $path" -ForegroundColor DarkGray
            }
        }

        Write-Output "Cleaning up registry..."

        # Remove ms edge from autostart
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "Microsoft Edge Update" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "Microsoft Edge Update" /f *>$null

        Write-Output "Microsoft Edge was uninstalled"
    }
    else {
        Write-Output ""
        Write-Host "Error: Unable to forcefully uninstall Microsoft Edge, uninstaller could not be found" -ForegroundColor Red
    }
    
    Write-Output ""
}


# Execute provided command and strips progress spinners/bars from console output
function Strip-Progress {
    param(
        [ScriptBlock]$ScriptBlock
    )

    # Regex pattern to match spinner characters and progress bar patterns
    $progressPattern = 'Γû[Æê]|^\s+[-\\|/]\s+$'

    # Corrected regex pattern for size formatting, ensuring proper capture groups are utilized
    $sizePattern = '(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB) /\s+(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB)'

    & $ScriptBlock 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            "ERROR: $($_.Exception.Message)"
        } else {
            $line = $_ -replace $progressPattern, '' -replace $sizePattern, ''
            if (-not ([string]::IsNullOrWhiteSpace($line)) -and -not ($line.StartsWith('  '))) {
                $line
            }
        }
    }
}

# =================================================================================================
# NEW AND IMPROVED RegImport FUNCTION (v2) - Fixes "File in Use" Error for Logged-In User
# This function intelligently applies registry files to all existing and future users.
# =================================================================================================
function RegImport {
    param (
        [string]$Message,
        [string]$RegFilePath
    )

    Write-Output $Message

    $FullRegPath = "$PSScriptRoot\Regfiles\$RegFilePath"
    if (-not (Test-Path $FullRegPath)) {
        Write-Warning "Registry file not found at '$FullRegPath'. Skipping."
        return
    }

    $RegContent = Get-Content -Path $FullRegPath -Raw -ErrorAction SilentlyContinue
    $TempRegFile = "$env:TEMP\temp_reg_import.reg"

    # --- Apply HKLM (System-Wide) Settings ---
    if ($RegContent -match '\[HKEY_LOCAL_MACHINE\\') {
        Write-Verbose "Applying HKLM settings from '$RegFilePath'..."
        reg import $FullRegPath | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "An error occurred while importing HKLM settings from '$RegFilePath'."
        } else {
            Write-Host "  Successfully applied system-wide (HKLM) settings." -ForegroundColor DarkGray
        }
    }

    # --- Apply HKCU (User-Specific) Settings to All Users and Default Profile ---
    if ($RegContent -match '\[HKEY_CURRENT_USER\\') {
        Write-Verbose "Applying HKCU settings from '$RegFilePath' to all users..."

        # 1. Modify the Default User profile (for all future users)
        $DefaultUserPath = $env:SystemDrive + '\Users\Default\NTUSER.DAT'
        if (Test-Path $DefaultUserPath) {
            try {
                Write-Verbose "  - Loading Default User profile hive..."
                reg load "HKU\DefaultUserHive" $DefaultUserPath | Out-Null
                $TempRegContent = $RegContent -replace '\[HKEY_CURRENT_USER', '[HKEY_USERS\DefaultUserHive'
                Set-Content -Path $TempRegFile -Value $TempRegContent -Encoding Ascii -Force
                reg import $TempRegFile | Out-Null
                Write-Host "  Applied settings to Default User Profile (for new users)." -ForegroundColor DarkGray
            } catch {
                Write-Warning "  Could not apply settings to Default User Profile. Error: $($_.Exception.Message)"
            } finally {
                reg unload "HKU\DefaultUserHive" | Out-Null
            }
        } else {
            Write-Warning "  Default User profile hive not found at '$DefaultUserPath'."
        }

        # PERFORMANCE OPTIMIZATION: Get all user SIDs once.
        $UserSIDs = @{}
        try { Get-CimInstance Win32_UserAccount | ForEach-Object { $UserSIDs[$_.Name] = $_.SID } } catch {}

        # 2. Modify all existing user profiles
        Get-ChildItem -Path "$env:SystemDrive\Users" -Directory | ForEach-Object {
            $UserProfile = $_
            $NTUserDataFile = Join-Path -Path $UserProfile.FullName -ChildPath "NTUSER.DAT"

            # Skip special profiles
            if ($UserProfile.Name -in @("Default", "Public", "Default User") -or (-not (Test-Path $NTUserDataFile))) {
                return
            }
            
            $UserSID = $UserSIDs[$UserProfile.Name]
            if (-not $UserSID) { return } # Skip if user has no SID

            # ---- CORE LOGIC FIX ----
            # Check if the user's hive is already loaded (meaning they are logged in)
            if (Test-Path "Registry::HKEY_USERS\$UserSID") {
                # THE FIX: User is logged in, so we modify their already loaded hive directly.
                Write-Host "  Applying settings to logged-in user: $($UserProfile.Name)" -ForegroundColor DarkGray
                try {
                    $TempRegContent = $RegContent -replace '\[HKEY_CURRENT_USER', "[HKEY_USERS\$UserSID"
                    Set-Content -Path $TempRegFile -Value $TempRegContent -Encoding Ascii -Force
                    reg import $TempRegFile | Out-Null
                } catch {
                    Write-Warning "  Could not apply settings to logged-in user $($UserProfile.Name). Error: $($_.Exception.Message)"
                }
            } else {
                # User is NOT logged in, so we can safely load their hive temporarily.
                Write-Host "  Applying settings to logged-off user profile: $($UserProfile.Name)" -ForegroundColor DarkGray
                try {
                    reg load "HKU\TempUserHive" $NTUserDataFile | Out-Null
                    $TempRegContent = $RegContent -replace '\[HKEY_CURRENT_USER', '[HKEY_USERS\TempUserHive'
                    Set-Content -Path $TempRegFile -Value $TempRegContent -Encoding Ascii -Force
                    reg import $TempRegFile | Out-Null
                } catch {
                    Write-Warning "  Could not load or apply settings to user profile $($UserProfile.Name). Error: $($_.Exception.Message)"
                } finally {
                    # CRITICAL: Always unload the hive, even if an error occurred
                    reg unload "HKU\TempUserHive" | Out-Null
                }
            }
        }
        # Clean up the temporary reg file
        Remove-Item -Path $TempRegFile -Force -ErrorAction SilentlyContinue
    }
    Write-Output ""
}

# Restart the Windows Explorer process
function RestartExplorer {
    Write-Output "> Restarting Windows Explorer process to apply all changes... (This may cause some flickering)"

    # Only restart if the powershell process matches the OS architecture
    # Restarting explorer from a 32bit Powershell window will fail on a 64bit OS
    if ([Environment]::Is64BitProcess -eq [Environment]::Is64BitOperatingSystem)
    {
        Stop-Process -processName: Explorer -Force
    }
    else {
        Write-Warning "Unable to restart Windows Explorer process, please manually restart your PC to apply all changes."
    }
}


# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenuForAllUsers {
    param (
        $startMenuTemplate = "$PSScriptRoot/Start/start2.bin"
    )

    Write-Output "> Removing all pinned apps from the start menu for all users..."

    # Check if template bin file exists, return early if it doesn't
    if (-not (Test-Path $startMenuTemplate)) {
        Write-Host "Error: Unable to clear start menu, start2.bin file missing from script folder" -ForegroundColor Red
        Write-Output ""
        return
    }

    # Get path to start menu file for all users
    $userPathString = $env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\*\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
    $usersStartMenuPaths = get-childitem -path $userPathString

    # Go through all users and replace the start menu file
    ForEach ($startMenuPath in $usersStartMenuPaths) {
        ReplaceStartMenu "$($startMenuPath.Fullname)\start2.bin" $startMenuTemplate
    }

    # Also replace the start menu file for the default user profile
    $defaultStartMenuPath = $env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), '\Default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState'

    # Create folder if it doesn't exist
    if (-not(Test-Path $defaultStartMenuPath)) {
        new-item $defaultStartMenuPath -ItemType Directory -Force | Out-Null
        Write-Output "Created LocalState folder for default user profile"
    }

    # Copy template to default profile
    Copy-Item -Path $startMenuTemplate -Destination $defaultStartMenuPath -Force
    Write-Output "Replaced start menu for the default user profile"
    Write-Output ""
}


# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenu {
    param (
        $startMenuBinFile = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin",
        $startMenuTemplate = "$PSScriptRoot/Start/start2.bin"
    )

    $userName = $env:USERNAME

    # Check if template bin file exists, return early if it doesn't
    if (-not (Test-Path $startMenuTemplate)) {
        Write-Host "Error: Unable to clear start menu, start2.bin file missing from script folder" -ForegroundColor Red
        return
    }

    # Check if bin file exists, return early if it doesn't
    if (-not (Test-Path $startMenuBinFile)) {
        Write-Host "Error: Unable to clear start menu for user $userName, start2.bin file could not found" -ForegroundColor Red
        return
    }

    $backupBinFile = $startMenuBinFile + ".bak"

    # Backup current start menu file
    Move-Item -Path $startMenuBinFile -Destination $backupBinFile -Force

    # Copy template file
    Copy-Item -Path $startMenuTemplate -Destination $startMenuBinFile -Force

    Write-Output "Replaced start menu for user $userName"
}


# Add parameter to script and write to file
function AddParameter {
    param (
        $parameterName,
        $message
    )

    # Add key if it doesn't already exist
    if (-not $global:Params.ContainsKey($parameterName)) {
        $global:Params.Add($parameterName, $true)
    }

    # Create or clear file that stores last used settings
    if (!(Test-Path "$PSScriptRoot/SavedSettings")) {
        $null = New-Item "$PSScriptRoot/SavedSettings"
    } 
    elseif ($global:FirstSelection) {
        $null = Clear-Content "$PSScriptRoot/SavedSettings"
    }
    
    $global:FirstSelection = $false

    # Create entry and add it to the file
    $entry = "$parameterName#- $message"
    Add-Content -Path "$PSScriptRoot/SavedSettings" -Value $entry
}


function PrintHeader {
    param (
        $title
    )

    $fullTitle = " Win11Debloat Script - $title"
    $fullTitle = "$fullTitle (User: $Env:UserName)"
	
   

    Clear-Host
    Write-Output "-------------------------------------------------------------------------------------------"
    Write-Output $fullTitle
    Write-Output "-------------------------------------------------------------------------------------------"
}


function PrintFromFile {
    param (
        $path
    )

    Clear-Host

    # Get & print script menu from file
    Foreach ($line in (Get-Content -Path $path )) {   
        Write-Output $line
    }
}


function AwaitKeyToExit {
    # Suppress prompt if Silent parameter was passed
    if (-not $Silent) {
        Write-Output ""
        Write-Output "Press any key to exit..."
        $null = [System.Console]::ReadKey()
    }
}


# =================================================================================================
# REVERTED Set-WindowsSecurityIconPromoted FUNCTION - Simple and works for the current user
# =================================================================================================
function Set-WindowsSecurityIconPromoted {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # This function targets the current user only, as this is the only reliable method.
    $TargetExeSubstring = "securityhealthsystray"
    $RegistryBaseKey = "HKCU:\Control Panel\NotifyIconSettings"
    $PropertyNameToCheck = "ExecutablePath"
    $PromotedValueName = "IsPromoted"
    $Success = $false

    # Check if the base registry key exists
    if (-not (Test-Path $RegistryBaseKey)) {
        Write-Warning "Registry path '$RegistryBaseKey' does not exist for current user. Cannot proceed."
        return $false
    }
    
    $SubKeyItems = Get-ChildItem -Path $RegistryBaseKey -ErrorAction SilentlyContinue
    if ($null -eq $SubKeyItems) { return $false }

    foreach ($KeyItem in $SubKeyItems) {
        $KeyPath = $KeyItem.PSPath
        $ActualPathValue = Get-ItemPropertyValue -Path $KeyPath -Name $PropertyNameToCheck -ErrorAction SilentlyContinue

        if ($null -ne $ActualPathValue -and $ActualPathValue.ToString().ToLower().Contains($TargetExeSubstring.ToLower())) {
            Write-Host "Found target application key for Windows Security: $KeyPath"
            try {
                Set-ItemProperty -Path $KeyPath -Name $PromotedValueName -Value 1 -Type DWord -Force -ErrorAction Stop
                Write-Host " - Successfully set '$PromotedValueName = 1' for Windows Security icon for current user."
                $Success = $true
                break # Exit loop after finding the correct key
            } catch {
                Write-Warning " - Failed to set '$PromotedValueName' for '$KeyPath'. Error: $($_.Exception.Message)"
            }
        }
    }
    return $Success
}


function Set-WindowsNtpServer {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$NtpServerAddress = "de.pool.ntp.org"
    )

    $NtpServerWithFlags = "$NtpServerAddress,0x9"
    $OverallSuccess = $true # Assume success unless a critical step fails

    # Stop W32Time Service
    Stop-Service -Name W32Time -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3 # Brief pause for service to stop

    # Set Registry Values Directly
    $ParamsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters"
    $NtpClientProviderPath = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient"
    try {
        Set-ItemProperty -Path $ParamsPath -Name "NtpServer" -Value $NtpServerWithFlags -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path $ParamsPath -Name "Type" -Value "NTP" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path $NtpClientProviderPath -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction Stop
        Write-Host "NTP registry keys set for '$NtpServerAddress'."
    } catch {
        Write-Warning "Failed to set one or more NTP registry values. Error: $($_.Exception.Message)"
        $OverallSuccess = $false # Critical step failed
        # Attempt to start service anyway if it was stopped, but with a warning
        Start-Service -Name W32Time -ErrorAction SilentlyContinue
        return $false # Exit function as configuration is incomplete
    }

    # Start W32Time Service
    Start-Service -Name W32Time -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5 # Pause for service to start

    # Check if service is running
    $W32TimeService = Get-Service W32Time -ErrorAction SilentlyContinue
    if ($W32TimeService.Status -ne "Running") {
        Write-Warning "W32Time service did not start after configuration. Status: $($W32TimeService.Status). Manual check required."
        $OverallSuccess = $false
    } else {
        # Tell the RUNNING service to update its configuration
        w32tm /config /update
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Warning: 'w32tm /config /update' (notify running service) returned an error (Exit Code: $LASTEXITCODE)."
            # This isn't always fatal if registry keys are correct, but it's not ideal.
        }
        Start-Sleep -Seconds 2 # Pause for update to be processed

        # Resynchronize Time
        w32tm /resync /force
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "w32tm /resync command indicated an issue (Exit Code: $LASTEXITCODE)."
            # Don't mark as overall failure for this, as sync can happen later.
        } else {
            Write-Host "Time resync command sent for '$NtpServerAddress'."
        }
    }

    if ($OverallSuccess) {
        Write-Host "NTP server configuration attempted. Verify with 'w32tm /query /status' shortly."
    }
    return $OverallSuccess
}

# =================================================================================================
# FINAL AUTOSART METHOD (v2 - Simple .REG file creation)
# =================================================================================================

Write-Host "`n--- Autostart Configuration ---" -ForegroundColor Yellow

# --- Create the .reg file content ---
$RegFileContent = @"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run]
"MicrosoftEdgeAutoLaunch_29EBC4579851B72EE312C449CF839B1A"=hex:03,00,00,00,00,00,00,00,00,00,00,00

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run]
"OneDrive"=hex:03,00,00,00,00,00,00,00,00,00,00,00
"@

# Find the currently logged-in user's desktop path
$UserDesktop = ""
try {
    $ExplorerProcess = Get-WmiObject -Class Win32_Process -Filter "Name = 'explorer.exe'" | Select-Object -First 1
    $OwnerInfo = $ExplorerProcess.GetOwner()
    $UserName = $OwnerInfo.User
    $UserDesktop = "C:\Users\$UserName\Desktop"
} catch {
    Write-Warning "Could not automatically determine the logged-in user's desktop."
}

if (Test-Path $UserDesktop) {
    $UserRegPath = Join-Path -Path $UserDesktop -ChildPath "Disable Autostart Programs.reg"
    try {
        Set-Content -Path $UserRegPath -Value $RegFileContent -Encoding Unicode
        Write-Host "ACTION REQUIRED: A new registry file has been created on your desktop:" -ForegroundColor Cyan
        Write-Host "'Disable Autostart Programs.reg'" -ForegroundColor Cyan
        Write-Host "Please DOUBLE-CLICK this new file and accept the prompt to finalize the changes." -ForegroundColor Cyan
    } catch {
        Write-Warning "Could not create the registry file on the desktop. Error: $($_.Exception.Message)"
    }
}
Write-Host "--- Autostart Configuration Finished ---"

# =================================================================================================
# NEW FUNCTION - Sets default UI settings for all NEW users
# =================================================================================================
function Set-DefaultUserSettings {
    [CmdletBinding()]
    param()

    Write-Host "> Applying default UI settings for all new users..." -ForegroundColor Yellow

    # --- 1. Set a clean default taskbar layout (Removes Store, Outlook, etc.) ---
    # This XML defines a taskbar with only File Explorer and Edge.
    $XMLContent = @"
<LayoutModificationTemplate xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" Version="1">
  <CustomTaskbarLayoutCollection PinListPlacement="Replace">
    <defaultlayout:TaskbarLayout>
      <taskbar:TaskbarPinList>
        <taskbar:DesktopApp DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\System Tools\File Explorer.lnk" />
        <taskbar:DesktopApp DesktopApplicationLinkPath="%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk" />
      </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
  </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@
    $LayoutFilePath = "$env:SystemDrive\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml"
    try {
        if (-not (Test-Path (Split-Path $LayoutFilePath))) { New-Item -Path (Split-Path $LayoutFilePath) -ItemType Directory -Force | Out-Null }
        Set-Content -Path $LayoutFilePath -Value $XMLContent -Encoding UTF8 -Force
        Write-Host "  - Default taskbar layout has been set for new users."
    } catch { Write-Warning "  - Could not set the default taskbar layout. Error: $($_.Exception.Message)" }

    # --- 2. Load Default User Hive to apply registry changes ---
    $DefaultUserPath = $env:SystemDrive + '\Users\Default\NTUSER.DAT'
    if (-not (Test-Path $DefaultUserPath)) {
        Write-Warning "  - Default User profile hive not found. Cannot apply other new user settings."
        return
    }
    
    try {
        Write-Host "  - Loading Default User hive to apply registry settings..."
        reg load "HKU\DefaultUserHive" $DefaultUserPath | Out-Null

        # --- Hide the Search Bar on the Taskbar for new users ---
        $SearchKey = "HKU:\DefaultUserHive\Software\Microsoft\Windows\CurrentVersion\Search"
        if (-not (Test-Path $SearchKey)) { New-Item -Path $SearchKey -Force | Out-Null }
        Set-ItemProperty -Path $SearchKey -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -Force
        
        # --- Revert to the old Context Menu for new users ---
        $ContextMenuKey = "HKU:\DefaultUserHive\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        if (-not (Test-Path $ContextMenuKey)) { New-Item -Path $ContextMenuKey -Force -Recurse | Out-Null }
        Set-ItemProperty -Path $ContextMenuKey -Name "(Default)" -Value "" -Type String -Force

        Write-Host "  - Search bar and context menu settings applied for new users."
    }
    catch {
        Write-Warning "  - An error occurred while modifying the Default User hive. Error: $($_.Exception.Message)"
    }
    finally {
        # CRITICAL: Always unload the hive
        reg unload "HKU\DefaultUserHive" | Out-Null
        Write-Host "  - Default User hive has been unloaded."
    }
}
##################################################################################################################
#                                                                                                                #
#                                                  SCRIPT START                                                  #
#                                                                                                                #
##################################################################################################################

# =================================================================================================
# NEW AND IMPROVED BITLOCKER CONFIGURATION SECTION (v2 - with y/n prompts)
# This section checks the current status and allows enabling, disabling, or skipping.
# =================================================================================================

# Check for Administrator Privileges, as BitLocker management requires it.
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Administrator privileges are required to manage BitLocker. Skipping this section."
} else {
    Write-Host "`n--- BitLocker Configuration for Drive C: ---" -ForegroundColor Yellow
    
    try {
        # Get the BitLocker volume information for the C: drive
        $BitLockerVolume = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
        $ProtectionStatus = $BitLockerVolume.ProtectionStatus
        $EncryptionPercentage = $BitLockerVolume.EncryptionPercentage
        $VolumeType = $BitLockerVolume.VolumeType
        
        # --- Scenario 1: BitLocker is ON ---
        if ($ProtectionStatus -eq 'On') {
            Write-Host "Status: BitLocker protection is currently ON for drive C:." -ForegroundColor Green
            $choice = Read-Host "Do you want to disable it? (y/n)"
            if ($choice -eq 'y') {
                Write-Host "Disabling BitLocker on C:. This can take a long time as the drive decrypts..."
                # This is an asynchronous operation. The command finishes instantly, but decryption runs in the background.
                Disable-BitLocker -MountPoint "C:"
                Write-Host "Decryption has been initiated. You can check the progress in the BitLocker control panel."
            } else {
                Write-Host "Keeping BitLocker enabled."
            }
        
        # --- Scenario 2: BitLocker is OFF ---
        } elseif ($ProtectionStatus -eq 'Off') {
            # Check if drive is already encrypted but protection is just suspended (less common for C:)
            if ($EncryptionPercentage -gt 0) {
                 Write-Host "Status: BitLocker protection is OFF, but the drive is partially/fully encrypted." -ForegroundColor Cyan
                 $choice = Read-Host "Do you want to re-enable protection? (y/n)"
                 if ($choice -eq 'y') {
                    Write-Host "Resuming BitLocker protection on C:..."
                    Resume-BitLocker -MountPoint "C:"
                 } else {
                    Write-Host "Keeping BitLocker protection off."
                 }
            # Drive is fully decrypted
            } else {
                Write-Host "Status: BitLocker is currently OFF and the drive is not encrypted." -ForegroundColor Cyan
                # Check if the drive is an Operating System drive, as this is required for standard BitLocker.
                if ($VolumeType -ne 'OperatingSystem') {
                    Write-Warning "Drive C: is not identified as an 'OperatingSystem' volume type. BitLocker cannot be enabled via this script."
                } else {
                    $choice = Read-Host "Do you want to enable it? (y/n)"
                    if ($choice -eq 'y') {
                        Write-Warning "ENABLING BITLOCKER:"
                        Write-Warning "1. A recovery key will be saved to a file on your Desktop."
                        Write-Warning "2. You MUST save this key in a safe place, separate from your computer."
                        Write-Warning "3. If you lose this key, you could permanently lose access to all your data."
                        $confirmEnable = Read-Host "Are you sure you want to proceed? This is your final confirmation. (y/n)"
                        if ($confirmEnable -eq 'y') {
                            try {
                                Write-Host "Enabling BitLocker on C:. Please follow any on-screen prompts..."
                                # Save the recovery key to the current user's desktop
                                $RecoveryKeyPath = "$env:USERPROFILE\Desktop"
                                # Enable BitLocker with a recovery password. This is the most compatible method.
                                Enable-BitLocker -MountPoint "C:" -RecoveryPasswordProtector -SkipHardwareTest -ErrorAction Stop
                                
                                # After enabling, retrieve the recovery key and save it.
                                $RecoveryKey = (Get-BitLockerVolume -MountPoint 'C:').KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}
                                if ($RecoveryKey) {
                                    $KeyInfo = "BitLocker Recovery Key for $($env:COMPUTERNAME) - Drive C:`n`n"
                                    $KeyInfo += "Identifier: $($RecoveryKey.KeyProtectorId)`n"
                                    $KeyInfo += "Recovery Key: $($RecoveryKey.RecoveryPassword)`n`n"
                                    $KeyInfo += "Date Generated: $(Get-Date)"
                                    $KeyFileName = "BitLocker-Recovery-Key-$($env:COMPUTERNAME)-C-Drive.txt"
                                    Set-Content -Path "$RecoveryKeyPath\$KeyFileName" -Value $KeyInfo
                                    Write-Host "SUCCESS: BitLocker is now enabling. A recovery key file has been saved to your Desktop: '$KeyFileName'" -ForegroundColor Green
                                    Write-Host "IMPORTANT: Copy this file to a USB drive or cloud storage and keep it safe!" -ForegroundColor Green
                                }
                            } catch {
                                Write-Error "Failed to enable BitLocker. Error: $($_.Exception.Message)"
                                Write-Error "This can happen if the system does not have a TPM, if Secure Boot is disabled, or other hardware requirements are not met."
                            }
                        } else {
                            Write-Host "BitLocker enablement cancelled."
                        }
                    } else {
                        Write-Host "Keeping BitLocker disabled."
                    }
                }
            }
        }
    } catch {
        # This catch block handles cases where Get-BitLockerVolume fails
        Write-Error "Could not get BitLocker status for C:. Error: $($_.Exception.Message)"
        Write-Warning "This usually means BitLocker is not available on this edition of Windows (e.g., Windows Home) or the necessary services are not running."
    }
    Write-Host "--- BitLocker Configuration Finished ---`n"
}



powercfg /change monitor-timeout-ac 45
powercfg /change monitor-timeout-dc 15
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 60

Set-Volume -DriveLetter 'C' -NewFileSystemLabel 'System'

# --- Network Adapter Rename (Corrected) ---
if (Get-NetAdapter -Name "Ethernet" -ErrorAction SilentlyContinue) {
    Rename-NetAdapter -Name "Ethernet" -NewName "LAN"
}
if (Get-NetAdapter -Name "Wi-Fi" -ErrorAction SilentlyContinue) {
    Rename-NetAdapter -Name "Wi-Fi" -NewName "WLAN" # Optional: common for Wi-Fi
}
Rename-NetAdapter -Name "Bluetooth*" -NewName "BLE" -ErrorAction SilentlyContinue

$promotionAttempted = Set-WindowsSecurityIconPromoted
 if ($promotionAttempted) {
     Write-Host "Windows Security Icon promotion script executed. Check if changes were applied after Explorer restart."
 } else {
     Write-Host "Windows Security Icon promotion script did not find the target or failed."
 }



# Check if winget is installed & if it is, check if the version is at least v1.4
if ((Get-AppxPackage -Name "*Microsoft.DesktopAppInstaller*") -and ((winget -v) -replace 'v','' -gt 1.4)) {
    $global:wingetInstalled = $true
}
else {
    $global:wingetInstalled = $false

    # Show warning that requires user confirmation, Suppress confirmation if Silent parameter was passed
    if (-not $Silent) {
        Write-Warning "Winget is not installed or outdated. This may prevent Win11Debloat from removing certain apps."
        Write-Output ""
        Write-Output "Press any key to continue anyway..."
        $null = [System.Console]::ReadKey()
    }
}

Write-Host "`n--- Configuring Autostart Programs ---"

# =================================================================================================
# FINAL INTERACTIVE AUTOSART CONFIGURATION SECTION (using the generic function)
# =================================================================================================

Write-Host "`n--- Interactive Autostart Configuration ---" -ForegroundColor Yellow

# --- Configure Microsoft Edge Autostart ---
$choiceEdge = Read-Host "Do you want to disable Microsoft Edge from starting automatically? (y/n)"
if ($choiceEdge -eq 'y') {
    # We search for any Run key value that contains "msedge.exe"
    if (Set-ProgramAutostart -ExecutableName "msedge.exe") {
        Write-Host "Microsoft Edge autostart has been disabled." -ForegroundColor Green
    } else {
        Write-Host "No active Microsoft Edge autostart entries were found to disable."
    }
} else {
    Write-Host "Skipping Microsoft Edge autostart configuration."
}
Write-Output ""

# --- Configure OneDrive Autostart ---
$choiceOneDrive = Read-Host "Do you want to disable OneDrive from starting automatically? (y/n)"
if ($choiceOneDrive -eq 'y') {
    # OneDrive uses a specific, known Run key value named "OneDrive". Targeting it directly is more precise.
    if (Set-ProgramAutostart -ExecutableName "OneDrive.exe" -RegistryValueName "OneDrive") {
        Write-Host "OneDrive autostart has been disabled." -ForegroundColor Green
    } else {
        Write-Host "No active OneDrive autostart entries were found to disable."
    }
} else {
    Write-Host "Skipping OneDrive autostart configuration."
}
Write-Output ""

# --- Example for Future Use: Microsoft Teams ---
# $choiceTeams = Read-Host "Do you want to disable Microsoft Teams from starting automatically? (y/n)"
# if ($choiceTeams -eq 'y') {
#     if (Set-ProgramAutostart -ExecutableName "Teams.exe") {
#         Write-Host "Microsoft Teams autostart has been disabled." -ForegroundColor Green
#     }
# }
# Write-Output ""


Write-Host "--- Autostart Configuration Finished ---"

# Change NTP Server
if (Set-WindowsNtpServer -NtpServerAddress "de.pool.ntp.org") { # Or your desired server
    Write-Host "NTP server configuration function completed its attempt."
} else {
    Write-Host "NTP server configuration function encountered critical errors."
}


# Get current Windows build version to compare against features
$WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

$global:Params = $PSBoundParameters
$global:FirstSelection = $true
$SPParams = 'WhatIf', 'Confirm', 'Verbose', 'Silent', 'Debug'
$SPParamCount = 0

# Count how many SPParams exist within Params
# This is later used to check if any options were selected
foreach ($Param in $SPParams) {
    if ($global:Params.ContainsKey($Param)) {
        $SPParamCount++
    }
}

# Hide progress bars for app removal, as they block Win11Debloat's output
if (-not ($global:Params.ContainsKey("Verbose"))) {
    $ProgressPreference = 'SilentlyContinue'
}
else {
    Read-Host "Verbose mode is enabled, press enter to continue"
    $ProgressPreference = 'Continue'
}

# Since the script now always modifies the Default User profile, these checks are always relevant.
$defaultUserPath = $env:SystemDrive + '\Users\Default\NTUSER.DAT'
if (-not (Test-Path "$defaultUserPath")) {
    Write-Host "Error: Cannot find default user profile at '$defaultUserPath'. Settings for new users cannot be applied." -ForegroundColor Red
    AwaitKeyToExit
    Exit
}

# Remove SavedSettings file if it exists and is empty
if ((Test-Path "$PSScriptRoot/SavedSettings") -and ([String]::IsNullOrWhiteSpace((Get-content "$PSScriptRoot/SavedSettings")))) {
    Remove-Item -Path "$PSScriptRoot/SavedSettings" -recurse
}

# Only run the app selection form if the 'RunAppConfigurator' parameter was passed to the script
if ($RunAppConfigurator) {
    PrintHeader "App Configurator"

    $result = ShowAppSelectionForm

    # Show different message based on whether the app selection was saved or cancelled
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "App configurator was closed without saving." -ForegroundColor Red
    }
    else {
        Write-Output "Your app selection was saved to the 'CustomAppsList' file in the root folder of the script."
    }

    AwaitKeyToExit
    Exit
}

# Change script execution based on provided parameters or user input
if ((-not $global:Params.Count) -or $RunDefaults -or $RunWin11Defaults -or $RunSavedSettings -or ($SPParamCount -eq $global:Params.Count)) {
    if ($RunDefaults -or $RunWin11Defaults) {
        $Mode = '1'
    }
    elseif ($RunSavedSettings) {
        if(-not (Test-Path "$PSScriptRoot/SavedSettings")) {
            PrintHeader 'Custom Mode'
            Write-Host "Error: No saved settings found, no changes were made" -ForegroundColor Red
            AwaitKeyToExit
            Exit
        }

        $Mode = '4'
    }
    else {
        # Show menu and wait for user input, loops until valid input is provided
        Do { 
            $ModeSelectionMessage = "Please select an option (1/2/3/0)" 

            PrintHeader 'Menu'

            Write-Output "(1) Default mode: Apply the default settings"
            Write-Output "(2) Custom mode: Modify the script to your needs"
            Write-Output "(3) App removal mode: Select & remove apps, without making other changes"

            # Only show this option if SavedSettings file exists
            if (Test-Path "$PSScriptRoot/SavedSettings") {
                Write-Output "(4) Apply saved custom settings from last time"
                
                $ModeSelectionMessage = "Please select an option (1/2/3/4/0)" 
            }

            Write-Output ""
            Write-Output "(0) Show more information"
            Write-Output ""
            Write-Output ""

            $Mode = Read-Host $ModeSelectionMessage

            # Show information based on user input, Suppress user prompt if Silent parameter was passed
            if ($Mode -eq '0') {
                # Get & print script information from file
                PrintFromFile "$PSScriptRoot/Assets/Menus/Info"

                Write-Output ""
                Write-Output "Press any key to go back..."
                $null = [System.Console]::ReadKey()
            }
            elseif (($Mode -eq '4')-and -not (Test-Path "$PSScriptRoot/SavedSettings")) {
                $Mode = $null
            }
        }
        while ($Mode -ne '1' -and $Mode -ne '2' -and $Mode -ne '3' -and $Mode -ne '4') 
    }

    # Add execution parameters based on the mode
    switch ($Mode) {
        # Default mode, loads defaults after confirmation
        '1' { 
            # Print the default settings & require userconfirmation, unless Silent parameter was passed
            if (-not $Silent) {
                PrintFromFile "$PSScriptRoot/Assets/Menus/DefaultSettings"

                Write-Output ""
                if ((Read-Host "Do you want to remove Microsoft Teams? (y/n)") -eq 'n') {
                    $global:keepTeams = $true
                }
                if ((Read-Host "Do you want to remove Microsoft OneDrive? (y/n)") -eq 'y') {
                    $global:removeOneDrive = $true
                }
                Write-Output "Press enter to execute the script or press CTRL+C to quit..."
                Read-Host | Out-Null
            }

            $DefaultParameterNames = 'RemoveApps','DisableTelemetry','DisableBing','DisableLockscreenTips','DisableSuggestions','ShowKnownFileExt','DisableWidgets','DisableCopilot','DisableDVR','ClearStartAllUsers','DisableRecall','RevertContextMenu','TaskbarAlignLeft','HideSearchTb','HideTaskview','ExplorerToThisPC','HideDupliDrive','SharingWizardOn','FullPath','NavPaneShowAllFolders','AutoSetup','DesktopIcons','ShowFrequentList','StartLayout','HiberbootEnabled','HideNewOutlookToggle','HighPerformance'

            PrintHeader 'Default Mode'

            # Add default parameters if they don't already exist
            foreach ($ParameterName in $DefaultParameterNames) {
                if (-not $global:Params.ContainsKey($ParameterName)){
                    $global:Params.Add($ParameterName, $true)
                }
            }

           
        }

        # Custom mode, show & add options based on user input
        '2' { 
            # Get current Windows build version to compare against features
            $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild
            
            PrintHeader 'Custom Mode'

            # Show options for removing apps, only continue on valid input
            Do {
                Write-Host "Options:" -ForegroundColor Yellow
                Write-Host " (n) Don't remove any apps" -ForegroundColor Yellow
                Write-Host " (1) Only remove the default selection of bloatware apps from 'Appslist.txt'" -ForegroundColor Yellow
                Write-Host " (2) Remove default selection of bloatware apps, aswell as mail & calendar apps, developer apps and gaming apps"  -ForegroundColor Yellow
                Write-Host " (3) Select which apps to remove and which to keep" -ForegroundColor Yellow
                $RemoveAppsInput = Read-Host "Remove any pre-installed apps? (n/1/2/3)" 

                # Show app selection form if user entered option 3
                if ($RemoveAppsInput -eq '3') {
                    $result = ShowAppSelectionForm

                    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
                        # User cancelled or closed app selection, show error and change RemoveAppsInput so the menu will be shown again
                        Write-Output ""
                        Write-Host "Cancelled application selection, please try again" -ForegroundColor Red

                        $RemoveAppsInput = 'c'
                    }
                    
                    Write-Output ""
                }
            }
            while ($RemoveAppsInput -ne 'n' -and $RemoveAppsInput -ne '0' -and $RemoveAppsInput -ne '1' -and $RemoveAppsInput -ne '2' -and $RemoveAppsInput -ne '3') 

            # Select correct option based on user input
            switch ($RemoveAppsInput) {
                '1' {
                    AddParameter 'RemoveApps' 'Remove default selection of bloatware apps'
                }
                '2' {
                    AddParameter 'RemoveApps' 'Remove default selection of bloatware apps'
                    AddParameter 'RemoveCommApps' 'Remove the Mail, Calendar, and People apps'
                    AddParameter 'RemoveW11Outlook' 'Remove the new Outlook for Windows app'
                    AddParameter 'RemoveDevApps' 'Remove developer-related apps'
                    AddParameter 'RemoveGamingApps' 'Remove the Xbox App and Xbox Gamebar'
                    AddParameter 'DisableDVR' 'Disable Xbox game/screen recording'
                }
                '3' {
                    Write-Output "You have selected $($global:SelectedApps.Count) apps for removal"

                    AddParameter 'RemoveAppsCustom' "Remove $($global:SelectedApps.Count) apps:"

                    Write-Output ""

                    if ($( Read-Host -Prompt "Disable Xbox game/screen recording? Also stops gaming overlay popups (y/n)" ) -eq 'y') {
                        AddParameter 'DisableDVR' 'Disable Xbox game/screen recording'
                    }
                }
            }

            # Only show this option for Windows 11 users running build 22621 or later
            if ($WinVersion -ge 22621){
                Write-Output ""
		# Since the script now always applies settings for all users, we only need one simple question.
		if ($( Read-Host -Prompt "Remove all pinned apps from the start menu for all existing and new users? (y/n)" ) -eq 'y') {
   		AddParameter 'ClearStartAllUsers' 'Remove all pinned apps from the start menu for existing and new users'
		}
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Disable telemetry, diagnostic data, activity history, app-launch tracking and targeted ads? (y/n)" ) -eq 'y') {
                AddParameter 'DisableTelemetry' 'Disable telemetry, diagnostic data, activity history, app-launch tracking & targeted ads'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Disable tips, tricks, suggestions and ads in start, settings, notifications, explorer, desktop and lockscreen? (y/n)" ) -eq 'y') {
                AddParameter 'DisableSuggestions' 'Disable tips, tricks, suggestions and ads in start, settings, notifications and File Explorer'
                AddParameter 'DisableDesktopSpotlight' 'Disable the Windows Spotlight desktop background option.'
                AddParameter 'DisableLockscreenTips' 'Disable tips & tricks on the lockscreen'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Disable & remove bing web search, bing AI & cortana in Windows search? (y/n)" ) -eq 'y') {
                AddParameter 'DisableBing' 'Disable & remove bing web search, bing AI & cortana in Windows search'
            }

            # Only show this option for Windows 11 users running build 22621 or later
            if ($WinVersion -ge 22621){
                Write-Output ""

                if ($( Read-Host -Prompt "Disable and remove Windows Copilot? This applies to all users (y/n)" ) -eq 'y') {
                    AddParameter 'DisableCopilot' 'Disable and remove Windows Copilot'
                }

                Write-Output ""

                if ($( Read-Host -Prompt "Disable Windows Recall snapshots? This applies to all users (y/n)" ) -eq 'y') {
                    AddParameter 'DisableRecall' 'Disable Windows Recall snapshots'
                }
            }

            # Only show this option for Windows 11 users running build 22000 or later
            if ($WinVersion -ge 22000){
                Write-Output ""

                if ($( Read-Host -Prompt "Restore the old Windows 10 style context menu? (y/n)" ) -eq 'y') {
                    AddParameter 'RevertContextMenu' 'Restore the old Windows 10 style context menu'
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Do you want to make any changes to the taskbar and related services? (y/n)" ) -eq 'y') {
                # Only show these specific options for Windows 11 users running build 22000 or later
                if ($WinVersion -ge 22000){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   Align taskbar buttons to the left side? (y/n)" ) -eq 'y') {
                        AddParameter 'TaskbarAlignLeft' 'Align taskbar icons to the left'
                    }

                    # Show options for search icon on taskbar, only continue on valid input
                    Do {
                        Write-Output ""
                        Write-Host "   Options:" -ForegroundColor Yellow
                        Write-Host "    (n) No change" -ForegroundColor Yellow
                        Write-Host "    (1) Hide search icon from the taskbar" -ForegroundColor Yellow
                        Write-Host "    (2) Show search icon on the taskbar" -ForegroundColor Yellow
                        Write-Host "    (3) Show search icon with label on the taskbar" -ForegroundColor Yellow
                        Write-Host "    (4) Show search box on the taskbar" -ForegroundColor Yellow
                        $TbSearchInput = Read-Host "   Hide or change the search icon on the taskbar? (n/1/2/3/4)" 
                    }
                    while ($TbSearchInput -ne 'n' -and $TbSearchInput -ne '0' -and $TbSearchInput -ne '1' -and $TbSearchInput -ne '2' -and $TbSearchInput -ne '3' -and $TbSearchInput -ne '4') 

                    # Select correct taskbar search option based on user input
                    switch ($TbSearchInput) {
                        '1' {
                            AddParameter 'HideSearchTb' 'Hide search icon from the taskbar'
                        }
                        '2' {
                            AddParameter 'ShowSearchIconTb' 'Show search icon on the taskbar'
                        }
                        '3' {
                            AddParameter 'ShowSearchLabelTb' 'Show search icon with label on the taskbar'
                        }
                        '4' {
                            AddParameter 'ShowSearchBoxTb' 'Show search box on the taskbar'
                        }
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   Hide the taskview button from the taskbar? (y/n)" ) -eq 'y') {
                        AddParameter 'HideTaskview' 'Hide the taskview button from the taskbar'
                    }
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Disable the widgets service and hide the icon from the taskbar? (y/n)" ) -eq 'y') {
                    AddParameter 'DisableWidgets' 'Disable the widget service & hide the widget (news and interests) icon from the taskbar'
                }

                # Only show this options for Windows users running build 22621 or earlier
                if ($WinVersion -le 22621){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   Hide the chat (meet now) icon from the taskbar? (y/n)" ) -eq 'y') {
                        AddParameter 'HideChat' 'Hide the chat (meet now) icon from the taskbar'
                    }
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Do you want to make any changes to File Explorer? (y/n)" ) -eq 'y') {
                # Show options for changing the File Explorer default location
                Do {
                    Write-Output ""
                    Write-Host "   Options:" -ForegroundColor Yellow
                    Write-Host "    (n) No change" -ForegroundColor Yellow
                    Write-Host "    (1) Open File Explorer to 'Home'" -ForegroundColor Yellow
                    Write-Host "    (2) Open File Explorer to 'This PC'" -ForegroundColor Yellow
                    Write-Host "    (3) Open File Explorer to 'Downloads'" -ForegroundColor Yellow
                    Write-Host "    (4) Open File Explorer to 'OneDrive'" -ForegroundColor Yellow
                    $ExplSearchInput = Read-Host "   Change the default location that File Explorer opens to? (n/1/2/3/4)" 
                }
                while ($ExplSearchInput -ne 'n' -and $ExplSearchInput -ne '0' -and $ExplSearchInput -ne '1' -and $ExplSearchInput -ne '2' -and $ExplSearchInput -ne '3' -and $ExplSearchInput -ne '4') 

                # Select correct taskbar search option based on user input
                switch ($ExplSearchInput) {
                    '1' {
                        AddParameter 'ExplorerToHome' "Change the default location that File Explorer opens to 'Home'"
                    }
                    '2' {
                        AddParameter 'ExplorerToThisPC' "Change the default location that File Explorer opens to 'This PC'"
                    }
                    '3' {
                        AddParameter 'ExplorerToDownloads' "Change the default location that File Explorer opens to 'Downloads'"
                    }
                    '4' {
                        AddParameter 'ExplorerToOneDrive' "Change the default location that File Explorer opens to 'OneDrive'"
                    }
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Show hidden files, folders and drives? (y/n)" ) -eq 'y') {
                    AddParameter 'ShowHiddenFolders' 'Show hidden files, folders and drives'
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Show file extensions for known file types? (y/n)" ) -eq 'y') {
                    AddParameter 'ShowKnownFileExt' 'Show file extensions for known file types'
                }

                # Only show this option for Windows 11 users running build 22000 or later
                if ($WinVersion -ge 22000){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   Hide the Home section from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                        AddParameter 'HideHome' 'Hide the Home section from the File Explorer sidepanel'
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   Hide the Gallery section from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                        AddParameter 'HideGallery' 'Hide the Gallery section from the File Explorer sidepanel'
                    }
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Hide duplicate removable drive entries from the File Explorer sidepanel so they only show under This PC? (y/n)" ) -eq 'y') {
                    AddParameter 'HideDupliDrive' 'Hide duplicate removable drive entries from the File Explorer sidepanel'
                }

                # Only show option for disabling these specific folders for Windows 10 users
                if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'"){
                    Write-Output ""

                    if ($( Read-Host -Prompt "Do you want to hide any folders from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                        Write-Output ""

                        if ($( Read-Host -Prompt "   Hide the OneDrive folder from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                            AddParameter 'HideOnedrive' 'Hide the OneDrive folder in the File Explorer sidepanel'
                        }

                        Write-Output ""
                        
                        if ($( Read-Host -Prompt "   Hide the 3D objects folder from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                            AddParameter 'Hide3dObjects' "Hide the 3D objects folder under 'This pc' in File Explorer" 
                        }
                        
                        Write-Output ""

                        if ($( Read-Host -Prompt "   Hide the music folder from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                            AddParameter 'HideMusic' "Hide the music folder under 'This pc' in File Explorer"
                        }
                    }
                }
            }

            # Only show option for disabling context menu items for Windows 10 users or if the user opted to restore the Windows 10 context menu
            if ((get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") -or $global:Params.ContainsKey('RevertContextMenu')){
                Write-Output ""

                if ($( Read-Host -Prompt "Do you want to disable any context menu options? (y/n)" ) -eq 'y') {
                    Write-Output ""

                    if ($( Read-Host -Prompt "   Hide the 'Include in library' option in the context menu? (y/n)" ) -eq 'y') {
                        AddParameter 'HideIncludeInLibrary' "Hide the 'Include in library' option in the context menu"
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   Hide the 'Give access to' option in the context menu? (y/n)" ) -eq 'y') {
                        AddParameter 'HideGiveAccessTo' "Hide the 'Give access to' option in the context menu"
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   Hide the 'Share' option in the context menu? (y/n)" ) -eq 'y') {
                        AddParameter 'HideShare' "Hide the 'Share' option in the context menu"
                    }
                }
            }

            # Suppress prompt if Silent parameter was passed
            if (-not $Silent) {
                Write-Output ""
                Write-Output ""
                Write-Output ""
                Write-Output "Press enter to confirm your choices and execute the script or press CTRL+C to quit..."
                Read-Host | Out-Null
            }

            PrintHeader 'Custom Mode'
        }

        # App removal, remove apps based on user selection
        '3' {
            PrintHeader "App Removal"

            $result = ShowAppSelectionForm

            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                Write-Output "You have selected $($global:SelectedApps.Count) apps for removal"
                AddParameter 'RemoveAppsCustom' "Remove $($global:SelectedApps.Count) apps:"

                # Suppress prompt if Silent parameter was passed
                if (-not $Silent) {
                    Write-Output ""
                    Write-Output "Press enter to remove the selected apps or press CTRL+C to quit..."
                    Read-Host | Out-Null
                    PrintHeader "App Removal"
                }
            }
            else {
                Write-Host "Selection was cancelled, no apps have been removed" -ForegroundColor Red
                Write-Output ""
            }
        }

        # Load custom options selection from the "SavedSettings" file
        '4' {
            PrintHeader 'Custom Mode'
            Write-Output "Win11Debloat will make the following changes:"

            # Get & print default settings info from file
            Foreach ($line in (Get-Content -Path "$PSScriptRoot/SavedSettings" )) { 
                # Remove any spaces before and after the line
                $line = $line.Trim()
            
                # Check if the line contains a comment
                if (-not ($line.IndexOf('#') -eq -1)) {
                    $parameterName = $line.Substring(0, $line.IndexOf('#'))

                    # Print parameter description and add parameter to Params list
                    if ($parameterName -eq "RemoveAppsCustom") {
                        if (-not (Test-Path "$PSScriptRoot/CustomAppsList")) {
                            # Apps file does not exist, skip
                            continue
                        }
                        
                        $appsList = ReadAppslistFromFile "$PSScriptRoot/CustomAppsList"
                        Write-Output "- Remove $($appsList.Count) apps:"
                        Write-Host $appsList -ForegroundColor DarkGray
                    }
                    else {
                        Write-Output $line.Substring(($line.IndexOf('#') + 1), ($line.Length - $line.IndexOf('#') - 1))
                    }

                    if (-not $global:Params.ContainsKey($parameterName)){
                        $global:Params.Add($parameterName, $true)
                    }
                }
            }

            if (-not $Silent) {
                Write-Output ""
                Write-Output ""
                Write-Output "Press enter to execute the script or press CTRL+C to quit..."
                Read-Host | Out-Null
            }

            PrintHeader 'Custom Mode'
        }
    }
}
else {
    PrintHeader 'Custom Mode'
}


# If the number of keys in SPParams equals the number of keys in Params then no modifications/changes were selected
#  or added by the user, and the script can exit without making any changes.
if ($SPParamCount -eq $global:Params.Keys.Count) {
    Write-Output "The script completed without making any changes."

    AwaitKeyToExit
}
else {
    # Execute all selected/provided parameters
    switch ($global:Params.Keys) {
        'RemoveApps' {
            $appsList = ReadAppslistFromFile "$PSScriptRoot/Appslist.txt"
            if ($global:keepTeams) {
                $appsList = $appsList | Where-Object { $_ -ne 'MicrosoftTeams' -and $_ -ne 'MSTeams' }
            }
            if ($global:removeOneDrive) {
                $appsList += 'Microsoft.OneDrive'
            } 
            Write-Output "> Removing default selection of $($appsList.Count) apps..."
            RemoveApps $appsList
            continue
        }
        'RemoveAppsCustom' {
            if (-not (Test-Path "$PSScriptRoot/CustomAppsList")) {
                Write-Host "> Error: Could not load custom apps list from file, no apps were removed" -ForegroundColor Red
                Write-Output ""
                continue
            }
            
            $appsList = ReadAppslistFromFile "$PSScriptRoot/CustomAppsList"
            Write-Output "> Removing $($appsList.Count) apps..."
            RemoveApps $appsList
            continue
        }
        'RemoveCommApps' {
            Write-Output "> Removing Mail, Calendar and People apps..."
            
            $appsList = 'Microsoft.windowscommunicationsapps', 'Microsoft.People'
            RemoveApps $appsList
            continue
        }
        'RemoveW11Outlook' {
            $appsList = 'Microsoft.OutlookForWindows'
            Write-Output "> Removing new Outlook for Windows app..."
            RemoveApps $appsList
            continue
        }
        'RemoveDevApps' {
            $appsList = 'Microsoft.PowerAutomateDesktop', 'Microsoft.RemoteDesktop', 'Windows.DevHome'
            Write-Output "> Removing developer-related related apps..."
            RemoveApps $appsList
            continue
        }
        'RemoveGamingApps' {
            $appsList = 'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay'
            Write-Output "> Removing gaming related apps..."
            RemoveApps $appsList
            continue
        }
        "ForceRemoveEdge" {
            ForceRemoveEdge
            continue
        }
        'DisableDVR' {
            RegImport "> Disabling Xbox game/screen recording..." "Disable_DVR.reg"
            continue
        }
        'ClearStart' {
            Write-Output "> Removing all pinned apps from the start menu for user $env:USERNAME..."
            ReplaceStartMenu
            Write-Output ""
            continue
        }
        'ClearStartAllUsers' {
            ReplaceStartMenuForAllUsers
            continue
        }
        'DisableTelemetry' {
            RegImport "> Disabling telemetry, diagnostic data, activity history, app-launch tracking and targeted ads..." "Disable_Telemetry.reg"
            continue
        }
        {$_ -in "DisableBingSearches", "DisableBing"} {
            RegImport "> Disabling bing web search, bing AI & cortana in Windows search..." "Disable_Bing_Cortana_In_Search.reg"
            
            # Also remove the app package for bing search
            $appsList = 'Microsoft.BingSearch'
            RemoveApps $appsList
            continue
        }
        'DisableDesktopSpotlight' {
            RegImport "> Disabling the 'Windows Spotlight' desktop background option..." "Disable_Desktop_Spotlight.reg"
            continue
        }
        {$_ -in "DisableLockscrTips", "DisableLockscreenTips"} {
            RegImport "> Disabling tips & tricks on the lockscreen..." "Disable_Lockscreen_Tips.reg"
            continue
        }
        {$_ -in "DisableSuggestions", "DisableWindowsSuggestions"} {
            RegImport "> Disabling tips, tricks, suggestions and ads across Windows..." "Disable_Windows_Suggestions.reg"
            continue
        }
        'RevertContextMenu' {
            RegImport "> Restoring the old Windows 10 style context menu..." "Disable_Show_More_Options_Context_Menu.reg"
            continue
        }
        'TaskbarAlignLeft' {
            RegImport "> Aligning taskbar buttons to the left..." "Align_Taskbar_Left.reg"

            continue
        }
        'HideSearchTb' {
            RegImport "> Hiding the search icon from the taskbar..." "Hide_Search_Taskbar.reg"
            continue
        }
        'ShowSearchIconTb' {
            RegImport "> Changing taskbar search to icon only..." "Show_Search_Icon.reg"
            continue
        }
        'ShowSearchLabelTb' {
            RegImport "> Changing taskbar search to icon with label..." "Show_Search_Icon_And_Label.reg"
            continue
        }
        'ShowSearchBoxTb' {
            RegImport "> Changing taskbar search to search box..." "Show_Search_Box.reg"
            continue
        }
        'HideTaskview' {
            RegImport "> Hiding the taskview button from the taskbar..." "Hide_Taskview_Taskbar.reg"
            continue
        }
        'DisableCopilot' {
            RegImport "> Disabling & removing Windows Copilot..." "Disable_Copilot.reg"

            # Also remove the app package for bing search
            $appsList = 'Microsoft.Copilot'
            RemoveApps $appsList
            continue
        }
        'DisableRecall' {
            RegImport "> Disabling Windows Recall snapshots..." "Disable_AI_Recall.reg"
            continue
        }
        {$_ -in "HideWidgets", "DisableWidgets"} {
            RegImport "> Disabling the widget service and hiding the widget icon from the taskbar..." "Disable_Widgets_Taskbar.reg"
            continue
        }
        {$_ -in "HideChat", "DisableChat"} {
            RegImport "> Hiding the chat icon from the taskbar..." "Disable_Chat_Taskbar.reg"
            continue
        }
        'ShowHiddenFolders' {
            RegImport "> Unhiding hidden files, folders and drives..." "Show_Hidden_Folders.reg"
            continue
        }
        'ShowKnownFileExt' {
            RegImport "> Enabling file extensions for known file types..." "Show_Extensions_For_Known_File_Types.reg"
            continue
        }
        'HideHome' {
            RegImport "> Hiding the home section from the File Explorer navigation pane..." "Hide_Home_from_Explorer.reg"
            continue
        }
        'HideGallery' {
            RegImport "> Hiding the gallery section from the File Explorer navigation pane..." "Hide_Gallery_from_Explorer.reg"
            continue
        }
        'ExplorerToHome' {
            RegImport "> Changing the default location that File Explorer opens to `Home`..." "Launch_File_Explorer_To_Home.reg"
            continue
        }
        'ExplorerToThisPC' {
            RegImport "> Changing the default location that File Explorer opens to `This PC`..." "Launch_File_Explorer_To_This_PC.reg"
            continue
        }
        'ExplorerToDownloads' {
            RegImport "> Changing the default location that File Explorer opens to `Downloads`..." "Launch_File_Explorer_To_Downloads.reg"
            continue
        }
        'ExplorerToOneDrive' {
            RegImport "> Changing the default location that File Explorer opens to `OneDrive`..." "Launch_File_Explorer_To_OneDrive.reg"
            continue
        }
        'HideDupliDrive' {
            RegImport "> Hiding duplicate removable drive entries from the File Explorer navigation pane..." "Hide_duplicate_removable_drives_from_navigation_pane_of_File_Explorer.reg"
            continue
        }
	'SharingWizardOn' {
            RegImport "> Sharing wizard off..." "Sharing_Wizard_Explorer_Off.reg"
            continue
        }
	'FullPath' {
            RegImport "> Setting Full Path in explorer option..." "Full_Path_Explorer.reg"
            continue
        }
	'NavPaneShowAllFolders' {
            RegImport "> Show all folders in navigation panel..." "Show_all_Folders_NavPane.reg"
            continue
        }
	'AutoSetup' {
            RegImport "> Network Auto Setup..." "Network_Private_Auto_Setup.reg"
            continue
        }
	'DesktopIcons' {
            RegImport "> Desktop Icons..." "Show_Desktop_Icons_PC_Folder.reg"
            continue
        }
	'ShowFrequentList' {
            RegImport "> Start Show Frequent list Off..." "Start_Show_Frequent_List_Off.reg"
            continue
        }
	'StartLayout' {
            RegImport "> Start Layout More Elements..." "Start_Layout_More_Elements.reg"
            continue
        }
	'HiberbootEnabled' {
            RegImport "> Power Hibernation boot Enabled Off..." "Power_Hibernation_boot_Enabled_Off.reg"
            continue
        }
	'HighPerformance' {
    	RegImport "> Enabling High Performance Power Plan option..." "Enable_High_Performance.reg"
    	Write-Host "  - Setting the High Performance power plan as active..."
   		 # This command finds the GUID for High Performance and activates it.
    	$HighPerfGUID = (powercfg -l | Where-Object { $_ -match "High performance" }).Split(' ')[3]
    	if ($HighPerfGUID) {
        	powercfg -s $HighPerfGUID
    	} else {
        	# Fallback in case the import didn't work and the plan isn't visible yet.
        	# The GUID for High Performance is static.
        	powercfg -s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    	}
    	continue
	}	
	'HideNewOutlookToggle' {
   			RegImport "> Disabling the 'Try the new Outlook' toggle in Classic Outlook for all users..." "Disable_New_Outlook_Toggle.reg"
   			continue
		}
        {$_ -in "HideOnedrive", "DisableOnedrive"} {
            RegImport "> Hiding the OneDrive folder from the File Explorer navigation pane..." "Hide_Onedrive_Folder.reg"
            continue
        }
        {$_ -in "Hide3dObjects", "Disable3dObjects"} {
            RegImport "> Hiding the 3D objects folder from the File Explorer navigation pane..." "Hide_3D_Objects_Folder.reg"
            continue
        }
        {$_ -in "HideMusic", "DisableMusic"} {
            RegImport "> Hiding the music folder from the File Explorer navigation pane..." "Hide_Music_folder.reg"
            continue
        }
		
        {$_ -in "HideIncludeInLibrary", "DisableIncludeInLibrary"} {
            RegImport "> Hiding 'Include in library' in the context menu..." "Disable_Include_in_library_from_context_menu.reg"
            continue
        }
        {$_ -in "HideGiveAccessTo", "DisableGiveAccessTo"} {
            RegImport "> Hiding 'Give access to' in the context menu..." "Disable_Give_access_to_context_menu.reg"
            continue
        }
        {$_ -in "HideShare", "DisableShare"} {
            RegImport "> Hiding 'Share' in the context menu..." "Disable_Share_from_context_menu.reg"
            continue
        }
    }
	Set-DefaultUserSettings

    RestartExplorer

    Write-Output ""
    Write-Output ""
    Write-Output ""
    Write-Output "Script completed successfully!"

    AwaitKeyToExit
}
