[CmdletBinding(SupportsShouldProcess)]
param ()

# Load Assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Main Form
$main_form = New-Object System.Windows.Forms.Form
$main_form.Text = "Windows 11 Debloater"
$main_form.Size = New-Object System.Drawing.Size(800, 600)
$main_form.StartPosition = "CenterScreen"

# Tab Control
$tab_control = New-Object System.Windows.Forms.TabControl
$tab_control.Dock = "Fill"
$main_form.Controls.Add($tab_control)

# Functions Tab
$functions_tab = New-Object System.Windows.Forms.TabPage
$functions_tab.Text = "Debloat"
$tab_control.Controls.Add($functions_tab)

# Apps Tab
$apps_tab = New-Object System.Windows.Forms.TabPage
$apps_tab.Text = "Apps"
$tab_control.Controls.Add($apps_tab)

# Registry Tab
$registry_tab = New-Object System.Windows.Forms.TabPage
$registry_tab.Text = "Registry"
$tab_control.Controls.Add($registry_tab)

# Create a FlowLayoutPanel for the buttons
$button_panel = New-Object System.Windows.Forms.FlowLayoutPanel
$button_panel.Dock = "Bottom"
$button_panel.FlowDirection = "RightToLeft"
$button_panel.Height = 40
$main_form.Controls.Add($button_panel)

# Run Button
$run_button = New-Object System.Windows.Forms.Button
$run_button.Text = "Run Debloat"
$run_button.Size = New-Object System.Drawing.Size(100, 30)
$button_panel.Controls.Add($run_button)

# Cancel Button
$cancel_button = New-Object System.Windows.Forms.Button
$cancel_button.Text = "Cancel"
$cancel_button.Size = New-Object System.Drawing.Size(100, 30)
$button_panel.Controls.Add($cancel_button)
$cancel_button.Add_Click({ $main_form.Close() })

# --- Functions Tab Content ---
$functions_layout = New-Object System.Windows.Forms.FlowLayoutPanel
$functions_layout.Dock = "Fill"
$functions_layout.FlowDirection = "TopDown"
$functions_tab.Controls.Add($functions_layout)

# --- Apps Tab Content ---
$apps_layout = New-Object System.Windows.Forms.TableLayoutPanel
$apps_layout.Dock = "Fill"
$apps_layout.ColumnCount = 2
$apps_layout.RowCount = 1
$apps_layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$apps_layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$apps_tab.Controls.Add($apps_layout)

$apps_to_remove_group = New-Object System.Windows.Forms.GroupBox
$apps_to_remove_group.Text = "Apps to Remove"
$apps_to_remove_group.Dock = "Fill"
$apps_layout.Controls.Add($apps_to_remove_group, 0, 0)

$apps_to_keep_group = New-Object System.Windows.Forms.GroupBox
$apps_to_keep_group.Text = "Apps to Keep"
$apps_to_keep_group.Dock = "Fill"
$apps_layout.Controls.Add($apps_to_keep_group, 1, 0)

$apps_to_remove_listbox = New-Object System.Windows.Forms.CheckedListBox
$apps_to_remove_listbox.Dock = "Fill"
$apps_to_remove_group.Controls.Add($apps_to_remove_listbox)

$apps_to_keep_listbox = New-Object System.Windows.Forms.CheckedListBox
$apps_to_keep_listbox.Dock = "Fill"
$apps_to_keep_group.Controls.Add($apps_to_keep_listbox)

# --- Registry Tab Content ---
$registry_layout = New-Object System.Windows.Forms.FlowLayoutPanel
$registry_layout.Dock = "Fill"
$registry_layout.FlowDirection = "TopDown"
$registry_tab.Controls.Add($registry_layout)

# --- Populate Controls ---

# Read Appslist.txt
$appslist_path = "$PSScriptRoot\Appslist.txt"
$appslist = Get-Content -Path $appslist_path

$remove_by_default = $true
foreach ($line in $appslist) {
    if ($line -match "^# -.*-$") {
        if ($line -like "*NOT be uninstalled*") {
            $remove_by_default = $false
        }
        continue
    }

    if ($line.Trim() -eq "" -or $line.StartsWith("# ")) {
        continue
    }

    $app_name = $line.TrimStart("#").Trim()
    if ($remove_by_default) {
        $apps_to_remove_listbox.Items.Add($app_name, [bool]!$line.StartsWith("#"))
    } else {
        $apps_to_keep_listbox.Items.Add($app_name, [bool]!$line.StartsWith("#"))
    }
}

# Read Win11Debloat.ps1 for parameters
$script_content = Get-Content -Path "$PSScriptRoot\Win11Debloat.ps1"
$param_block = $script_content -join "`n" | Select-String -Pattern "(?s)param \((.*?)\)"
if ($param_block) {
    $params = $param_block.Matches[0].Groups[1].Value.Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -like '[switch]*' }

    $current_group_box = $null
    $current_layout = $functions_layout

    foreach ($param in $params) {
        $param_name = ($param -split " ")[1].TrimStart("$")
        $param_desc = "" # You can add descriptions later if you want

        if ($param_name -eq "Sysprep") {
            $current_group_box = New-Object System.Windows.Forms.GroupBox
            $current_group_box.Text = "Sysprep"
            $current_group_box.AutoSize = $true
            $current_layout.Controls.Add($current_group_box)
            $current_layout = New-Object System.Windows.Forms.FlowLayoutPanel
            $current_layout.Dock = "Fill"
            $current_layout.FlowDirection = "TopDown"
            $current_group_box.Controls.Add($current_layout)
        }

        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Text = $param_name
        $checkbox.Name = $param_name
        $checkbox.AutoSize = $true

        if ($param_name -like "*Remove*") {
            $functions_layout.Controls.Add($checkbox)
        } elseif ($param_name -like "*Disable*" -or $param_name -like "*Hide*" -or $param_name -like "*Show*" -or $param_name -like "*Align*" -or $param_name -like "*Revert*" -or $param_name -like "*Clear*" -or $param_name -like "*ExplorerTo*") {
            $registry_layout.Controls.Add($checkbox)
        } else {
            $functions_layout.Controls.Add($checkbox)
        }
    }
}


# Run Button Click Event
$run_button.Add_Click({
    $command = ".\Win11Debloat.ps1"
    $params_to_add = @()

    # Collect selected functions
    foreach ($control in $functions_layout.Controls) {
        if ($control -is [System.Windows.Forms.CheckBox] -and $control.Checked) {
            $params_to_add += "-$($control.Name)"
        }
    }
    foreach ($control in $registry_layout.Controls) {
        if ($control -is [System.Windows.Forms.CheckBox] -and $control.Checked) {
            $params_to_add += "-$($control.Name)"
        }
    }

    # Collect selected apps
    $custom_app_list = @()
    foreach ($item in $apps_to_remove_listbox.CheckedItems) {
        $custom_app_list += $item
    }
    foreach ($item in $apps_to_keep_listbox.CheckedItems) {
        $custom_app_list += $item
    }

    if ($custom_app_list.Count -gt 0) {
        $params_to_add += "-RemoveAppsCustom"
        Set-Content -Path "$PSScriptRoot\CustomAppsList.txt" -Value $custom_app_list
    }


    if ($params_to_add.Count -gt 0) {
        $command += " " + ($params_to_add -join " ")
    }

    try {
        Invoke-Expression -Command $command
        [System.Windows.Forms.MessageBox]::Show("Debloat script executed successfully!", "Success", "OK", "Information")
    } catch {
        [System.Windows.Forms.MessageBox]::Show("An error occurred while running the debloat script:`n$($_.Exception.Message)", "Error", "OK", "Error")
    }
    $main_form.Close()
})

# Show the form
$main_form.ShowDialog() | Out-Null
