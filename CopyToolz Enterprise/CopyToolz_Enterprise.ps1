# ============================================================================
# CopyToolz - Enterprise Advanced Network File Copy Utility
# Author: Henchman33
# Version: 2.1
# ============================================================================

#=============================== MODULE LOADING ===============================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework  # For modern WPF styles

# Create paths - resolve script folder regardless of how the script was launched
# (double-click, right-click Run, ISE, VS Code, PS console, etc.)
if ($PSScriptRoot) {
    $basePath = $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Definition -and
          (Test-Path $MyInvocation.MyCommand.Definition -ErrorAction SilentlyContinue)) {
    $basePath = Split-Path -Parent $MyInvocation.MyCommand.Definition
} else {
    $basePath = $PWD.Path
}

$configPath = Join-Path $basePath "config"
$logPath = Join-Path $basePath "logs"
$credFile = Join-Path $configPath "credentials.xml"
$settingsFile = Join-Path $configPath "settings.json"

# Create folders if missing
@($configPath, $logPath) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -Path $_ -ItemType Directory | Out-Null }
}

# Load or create settings
$settings = @{
    LastSource = ""
    LastDestination = ""
    SaveCredentials = $false
    AutoDisconnect = $true
    Theme = "Dark"
    CopyMode = "Folder"  # "Folder" or "Files"
    LastFileFilter = "*.*"
}

if (Test-Path $settingsFile) {
    try {
        $settings = Get-Content $settingsFile | ConvertFrom-Json
    } catch {
        # Use default settings if file is corrupted
    }
}

# =============================== FORM SETUP ===============================
$form = New-Object System.Windows.Forms.Form
$form.Text = "CopyToolz Enterprise v2.2 - by Henchman33"
$form.Size = New-Object System.Drawing.Size(1200, 850)
$form.StartPosition = "CenterScreen"
$form.BackColor = "#2d2d2d"
$form.ForeColor = "#ffffff"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# Modern title bar with accent color
$titlePanel = New-Object System.Windows.Forms.Panel
$titlePanel.Size = New-Object System.Drawing.Size($form.Width, 40)
$titlePanel.BackColor = "#007acc"
$titlePanel.Dock = "Top"
$form.Controls.Add($titlePanel)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "CopyToolz - Enterprise Network File Transfer Utility"
$titleLabel.ForeColor = "#ffffff"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(15, 8)
$titleLabel.Size = New-Object System.Drawing.Size(500, 30)
$titlePanel.Controls.Add($titleLabel)

# Helper function to create modern buttons
function New-ModernButton {
    param($text, $x, $y, $width = 120, $height = 35, $bgColor = "#007acc")
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Size = New-Object System.Drawing.Size($width, $height)
    $btn.BackColor = [System.Drawing.ColorTranslator]::FromHtml($bgColor)
    $btn.ForeColor = "#ffffff"
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 0
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btn.Cursor = "Hand"
    
    # Hover effect
    $btn.Add_MouseEnter({
        $this.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#005a9e")
    })
    $btn.Add_MouseLeave({
        $this.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#007acc")
    })
    
    return $btn
}

# =============================== MAIN PANEL ===============================
$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.Location = New-Object System.Drawing.Point(20, 60)
$mainPanel.Size = New-Object System.Drawing.Size(1160, 750)
$mainPanel.BackColor = "#363636"
$form.Controls.Add($mainPanel)

# =============================== LEFT COLUMN (550px wide) ===============================
# =============================== SOURCE SECTION ===============================
$sourceGroup = New-Object System.Windows.Forms.GroupBox
$sourceGroup.Text = " Source Location "
$sourceGroup.Location = New-Object System.Drawing.Point(15, 15)
$sourceGroup.Size = New-Object System.Drawing.Size(550, 100)
$sourceGroup.ForeColor = "#ffffff"
$sourceGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($sourceGroup)

$textBoxSource = New-Object System.Windows.Forms.TextBox
$textBoxSource.Location = New-Object System.Drawing.Point(20, 35)
$textBoxSource.Size = New-Object System.Drawing.Size(400, 25)
$textBoxSource.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$textBoxSource.BackColor = "#2d2d2d"
$textBoxSource.ForeColor = "#ffffff"
$textBoxSource.BorderStyle = "FixedSingle"
$textBoxSource.Text = $settings.LastSource
$sourceGroup.Controls.Add($textBoxSource)

$btnBrowseSource = New-ModernButton "[Browse]" 430 32 90
$btnBrowseSource.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select Source Folder"
    $folderBrowser.RootFolder = "MyComputer"
    if ($folderBrowser.ShowDialog() -eq "OK") {
        $textBoxSource.Text = $folderBrowser.SelectedPath
        if (Test-Path $folderBrowser.SelectedPath -PathType Container) {
            $radioFolder.Checked = $true
        }
    }
})
$sourceGroup.Controls.Add($btnBrowseSource)

$btnNetworkSource = New-ModernButton "[Network]" 430 62 90 30 "#6c757d"
$btnNetworkSource.Add_Click({
    $uncPath = [Microsoft.VisualBasic.Interaction]::InputBox("Enter UNC path:", "Network Location", "\\server\share")
    if ($uncPath) {
        $textBoxSource.Text = $uncPath
    }
})
$sourceGroup.Controls.Add($btnNetworkSource)

# =============================== DESTINATION SECTION ===============================
$destGroup = New-Object System.Windows.Forms.GroupBox
$destGroup.Text = " Destination Location "
$destGroup.Location = New-Object System.Drawing.Point(15, 125)
$destGroup.Size = New-Object System.Drawing.Size(550, 100)
$destGroup.ForeColor = "#ffffff"
$destGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($destGroup)

$textBoxDest = New-Object System.Windows.Forms.TextBox
$textBoxDest.Location = New-Object System.Drawing.Point(20, 35)
$textBoxDest.Size = New-Object System.Drawing.Size(400, 25)
$textBoxDest.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$textBoxDest.BackColor = "#2d2d2d"
$textBoxDest.ForeColor = "#ffffff"
$textBoxDest.BorderStyle = "FixedSingle"
$textBoxDest.Text = $settings.LastDestination
$destGroup.Controls.Add($textBoxDest)

$btnBrowseDest = New-ModernButton "[Browse]" 430 32 90
$btnBrowseDest.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select Destination Folder"
    if ($folderBrowser.ShowDialog() -eq "OK") {
        $textBoxDest.Text = $folderBrowser.SelectedPath
    }
})
$destGroup.Controls.Add($btnBrowseDest)

$btnNetworkDest = New-ModernButton "[Network]" 430 62 90 30 "#6c757d"
$btnNetworkDest.Add_Click({
    $uncPath = [Microsoft.VisualBasic.Interaction]::InputBox("Enter UNC path:", "Network Location", "\\server\share")
    if ($uncPath) {
        $textBoxDest.Text = $uncPath
    }
})
$destGroup.Controls.Add($btnNetworkDest)

# =============================== COPY MODE SELECTION ===============================
$modeGroup = New-Object System.Windows.Forms.GroupBox
$modeGroup.Text = " Copy Mode "
$modeGroup.Location = New-Object System.Drawing.Point(15, 235)
$modeGroup.Size = New-Object System.Drawing.Size(550, 70)
$modeGroup.ForeColor = "#ffffff"
$modeGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($modeGroup)

$radioFolder = New-Object System.Windows.Forms.RadioButton
$radioFolder.Text = "Copy Entire Folder (including subfolders)"
$radioFolder.Location = New-Object System.Drawing.Point(20, 25)
$radioFolder.Size = New-Object System.Drawing.Size(250, 25)
$radioFolder.ForeColor = "#ffffff"
$radioFolder.Checked = ($settings.CopyMode -eq "Folder")
$modeGroup.Controls.Add($radioFolder)

$radioFiles = New-Object System.Windows.Forms.RadioButton
$radioFiles.Text = "Select Specific Files"
$radioFiles.Location = New-Object System.Drawing.Point(280, 25)
$radioFiles.Size = New-Object System.Drawing.Size(150, 25)
$radioFiles.ForeColor = "#ffffff"
$radioFiles.Checked = ($settings.CopyMode -eq "Files")
$modeGroup.Controls.Add($radioFiles)

$lblFileFilter = New-Object System.Windows.Forms.Label
$lblFileFilter.Text = "File Filter:"
$lblFileFilter.Location = New-Object System.Drawing.Point(430, 28)
$lblFileFilter.Size = New-Object System.Drawing.Size(60, 20)
$lblFileFilter.ForeColor = "#cccccc"
$lblFileFilter.Visible = $false
$modeGroup.Controls.Add($lblFileFilter)

$txtFileFilter = New-Object System.Windows.Forms.TextBox
$txtFileFilter.Text = $settings.LastFileFilter
$txtFileFilter.Location = New-Object System.Drawing.Point(490, 25)
$txtFileFilter.Size = New-Object System.Drawing.Size(40, 25)
$txtFileFilter.BackColor = "#2d2d2d"
$txtFileFilter.ForeColor = "#ffffff"
$txtFileFilter.BorderStyle = "FixedSingle"
$txtFileFilter.Visible = $false
$modeGroup.Controls.Add($txtFileFilter)

$radioFiles.Add_CheckedChanged({
    $lblFileFilter.Visible = $radioFiles.Checked
    $txtFileFilter.Visible = $radioFiles.Checked
})

$radioFolder.Add_CheckedChanged({
    $lblFileFilter.Visible = $false
    $txtFileFilter.Visible = $false
})

# =============================== FILE SELECTION PANEL ===============================
$fileGroup = New-Object System.Windows.Forms.GroupBox
$fileGroup.Text = " File Selection "
$fileGroup.Location = New-Object System.Drawing.Point(15, 315)
$fileGroup.Size = New-Object System.Drawing.Size(550, 180)
$fileGroup.ForeColor = "#ffffff"
$fileGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($fileGroup)

$fileListBox = New-Object System.Windows.Forms.ListBox
$fileListBox.Location = New-Object System.Drawing.Point(20, 25)
$fileListBox.Size = New-Object System.Drawing.Size(350, 120)
$fileListBox.BackColor = "#2d2d2d"
$fileListBox.ForeColor = "#ffffff"
$fileListBox.BorderStyle = "FixedSingle"
$fileListBox.SelectionMode = "MultiExtended"
$fileGroup.Controls.Add($fileListBox)

$btnLoadFiles = New-ModernButton "[Load Files]" 380 25 150 30
$btnLoadFiles.Add_Click({
    $source = $textBoxSource.Text.Trim()
    if (Test-Path $source) {
        $filter = if ($txtFileFilter.Visible -and $txtFileFilter.Text) { $txtFileFilter.Text } else { "*.*" }
        $files = Get-ChildItem -Path $source -File -Filter $filter
        $fileListBox.Items.Clear()
        foreach ($file in $files) {
            $fileListBox.Items.Add($file.Name)
        }
        $lblStatus.Text = "Loaded $($files.Count) files from source"
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please enter a valid source path first.", "Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})
$fileGroup.Controls.Add($btnLoadFiles)

$btnSelectAll = New-ModernButton "[Select All]" 380 60 150 30 "#28a745"
$btnSelectAll.Add_Click({
    for ($i = 0; $i -lt $fileListBox.Items.Count; $i++) {
        $fileListBox.SetSelected($i, $true)
    }
})
$fileGroup.Controls.Add($btnSelectAll)

$btnSelectNone = New-ModernButton "[Select None]" 380 95 150 30 "#dc3545"
$btnSelectNone.Add_Click({
    $fileListBox.ClearSelected()
})
$fileGroup.Controls.Add($btnSelectNone)

$btnInvertSelection = New-ModernButton "[Invert]" 380 130 150 30 "#6c757d"
$btnInvertSelection.Add_Click({
    for ($i = 0; $i -lt $fileListBox.Items.Count; $i++) {
        if ($fileListBox.SelectedIndices.Contains($i)) {
        } else {
            $fileListBox.SetSelected($i, $true)
        }
    }
})
$fileGroup.Controls.Add($btnInvertSelection)

$lblFileInstructions = New-Object System.Windows.Forms.Label
$lblFileInstructions.Text = "Hold Ctrl to select multiple files"
$lblFileInstructions.Location = New-Object System.Drawing.Point(20, 150)
$lblFileInstructions.Size = New-Object System.Drawing.Size(350, 20)
$lblFileInstructions.ForeColor = "#888888"
$lblFileInstructions.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$fileGroup.Controls.Add($lblFileInstructions)

# =============================== OPTIONS PANEL ===============================
$optionsGroup = New-Object System.Windows.Forms.GroupBox
$optionsGroup.Text = " Options "
$optionsGroup.Location = New-Object System.Drawing.Point(15, 505)
$optionsGroup.Size = New-Object System.Drawing.Size(550, 120)
$optionsGroup.ForeColor = "#ffffff"
$optionsGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($optionsGroup)

$chkUseCred = New-Object System.Windows.Forms.CheckBox
$chkUseCred.Text = "Use Network Credentials"
$chkUseCred.Location = New-Object System.Drawing.Point(20, 30)
$chkUseCred.Size = New-Object System.Drawing.Size(180, 25)
$chkUseCred.ForeColor = "#ffffff"
$chkUseCred.UseVisualStyleBackColor = $true
$chkUseCred.Checked = $false
$optionsGroup.Controls.Add($chkUseCred)

$chkSaveCred = New-Object System.Windows.Forms.CheckBox
$chkSaveCred.Text = "Save Credentials"
$chkSaveCred.Location = New-Object System.Drawing.Point(20, 55)
$chkSaveCred.Size = New-Object System.Drawing.Size(140, 25)
$chkSaveCred.ForeColor = "#ffffff"
$chkSaveCred.Checked = $settings.SaveCredentials
$optionsGroup.Controls.Add($chkSaveCred)

$chkDisconnect = New-Object System.Windows.Forms.CheckBox
$chkDisconnect.Text = "Disconnect Drives After Copy"
$chkDisconnect.Location = New-Object System.Drawing.Point(20, 80)
$chkDisconnect.Size = New-Object System.Drawing.Size(200, 25)
$chkDisconnect.ForeColor = "#ffffff"
$chkDisconnect.Checked = $settings.AutoDisconnect
$optionsGroup.Controls.Add($chkDisconnect)

$btnCred = New-ModernButton "[Set Credentials]" 200 30 150 35 "#28a745"
$btnCred.Enabled = $false
$btnCred.Add_Click({
    $script:cred = Get-Credential
    $btnCred.Text = "[Credentials Set]"
    Start-Sleep -Seconds 2
    $btnCred.Text = "[Set Credentials]"
})
$optionsGroup.Controls.Add($btnCred)

$chkUseCred.Add_CheckedChanged({
    $btnCred.Enabled = $chkUseCred.Checked
})

$script:cred = $null

# =============================== PROGRESS & LOG SECTION ===============================
$progressGroup = New-Object System.Windows.Forms.GroupBox
$progressGroup.Text = " Progress "
$progressGroup.Location = New-Object System.Drawing.Point(15, 635)
$progressGroup.Size = New-Object System.Drawing.Size(550, 100)
$progressGroup.ForeColor = "#ffffff"
$progressGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($progressGroup)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 30)
$progressBar.Size = New-Object System.Drawing.Size(510, 25)
$progressBar.Style = "Continuous"
$progressBar.ForeColor = "#007acc"
$progressBar.BackColor = "#2d2d2d"
$progressGroup.Controls.Add($progressBar)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Ready"
$lblStatus.Location = New-Object System.Drawing.Point(20, 65)
$lblStatus.Size = New-Object System.Drawing.Size(510, 25)
$lblStatus.ForeColor = "#cccccc"
$progressGroup.Controls.Add($lblStatus)

# =============================== RIGHT COLUMN (280px wide) ===============================
$statsGroup = New-Object System.Windows.Forms.GroupBox
$statsGroup.Text = " Statistics "
$statsGroup.Location = New-Object System.Drawing.Point(585, 15)
$statsGroup.Size = New-Object System.Drawing.Size(280, 180)
$statsGroup.ForeColor = "#ffffff"
$statsGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($statsGroup)

$statsLabels = @{}
$statsPositions = @(
    @{Name="Total Items"; Top=30},
    @{Name="Copied"; Top=55},
    @{Name="Failed"; Top=80},
    @{Name="Total Size"; Top=105},
    @{Name="Transfer Speed"; Top=130}
)

foreach ($stat in $statsPositions) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "$($stat.Name): 0"
    $label.Location = New-Object System.Drawing.Point(20, $stat.Top)
    $label.Size = New-Object System.Drawing.Size(240, 20)
    $label.ForeColor = "#cccccc"
    $statsGroup.Controls.Add($label)
    $statsLabels[$stat.Name] = $label
}

$lblTimeElapsed = New-Object System.Windows.Forms.Label
$lblTimeElapsed.Text = "Time Elapsed: 00:00:00"
$lblTimeElapsed.Location = New-Object System.Drawing.Point(20, 155)
$lblTimeElapsed.Size = New-Object System.Drawing.Size(240, 20)
$lblTimeElapsed.ForeColor = "#00ff00"
$lblTimeElapsed.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$statsGroup.Controls.Add($lblTimeElapsed)
$statsLabels["Time Elapsed"] = $lblTimeElapsed

# =============================== LOG PANEL ===============================
$logGroup = New-Object System.Windows.Forms.GroupBox
$logGroup.Text = " Log "
$logGroup.Location = New-Object System.Drawing.Point(585, 205)
$logGroup.Size = New-Object System.Drawing.Size(280, 170)
$logGroup.ForeColor = "#ffffff"
$logGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($logGroup)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(15, 25)
$logBox.Size = New-Object System.Drawing.Size(250, 130)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = "#1e1e1e"
$logBox.ForeColor = "#00ff00"
$logBox.Font = New-Object System.Drawing.Font("Consolas", 8)
$logBox.BorderStyle = "FixedSingle"
$logGroup.Controls.Add($logBox)

# =============================== RECENT LOCATIONS ===============================
$recentGroup = New-Object System.Windows.Forms.GroupBox
$recentGroup.Text = " Recent Locations "
$recentGroup.Location = New-Object System.Drawing.Point(585, 385)
$recentGroup.Size = New-Object System.Drawing.Size(280, 140)
$recentGroup.ForeColor = "#ffffff"
$recentGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($recentGroup)

$recentList = New-Object System.Windows.Forms.ListBox
$recentList.Location = New-Object System.Drawing.Point(15, 25)
$recentList.Size = New-Object System.Drawing.Size(250, 70)
$recentList.BackColor = "#2d2d2d"
$recentList.ForeColor = "#ffffff"
$recentList.BorderStyle = "FixedSingle"
$recentList.Items.AddRange(@("\\server\share1", "\\server\share2", "C:\Users\Public\Documents", "D:\Backups"))
$recentGroup.Controls.Add($recentList)

$recentList.Add_DoubleClick({
    if ($recentList.SelectedItem) {
        $textBoxSource.Text = $recentList.SelectedItem
    }
})

$recentInstructions = New-Object System.Windows.Forms.Label
$recentInstructions.Text = "Double-click to use as source"
$recentInstructions.Location = New-Object System.Drawing.Point(15, 100)
$recentInstructions.Size = New-Object System.Drawing.Size(250, 20)
$recentInstructions.ForeColor = "#888888"
$recentInstructions.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$recentGroup.Controls.Add($recentInstructions)

# =============================== ACTION BUTTONS PANEL ===============================
$actionGroup = New-Object System.Windows.Forms.GroupBox
$actionGroup.Text = " Actions "
$actionGroup.Location = New-Object System.Drawing.Point(585, 535)
$actionGroup.Size = New-Object System.Drawing.Size(280, 200)
$actionGroup.ForeColor = "#ffffff"
$actionGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($actionGroup)

$btnCopy = New-ModernButton "[>> Start Copy]" 20 30 240 45 "#28a745"
$btnCopy.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$actionGroup.Controls.Add($btnCopy)

$btnCancel = New-ModernButton "[Cancel]" 20 85 115 35 "#dc3545"
$btnCancel.Enabled = $false
$actionGroup.Controls.Add($btnCancel)

$btnHistory = New-ModernButton "[History]" 145 85 115 35 "#6c757d"
$actionGroup.Controls.Add($btnHistory)

$btnSettings = New-ModernButton "[Settings]" 20 130 115 35 "#6c757d"
$actionGroup.Controls.Add($btnSettings)

$btnHelp = New-ModernButton "[Help]" 145 130 115 35 "#6c757d"
$actionGroup.Controls.Add($btnHelp)

$lblVersion = New-Object System.Windows.Forms.Label
$lblVersion.Text = "CopyToolz v2.1  |  (c) 2024 Henchman33"
$lblVersion.Location = New-Object System.Drawing.Point(20, 175)
$lblVersion.Size = New-Object System.Drawing.Size(240, 20)
$lblVersion.ForeColor = "#aaaaaa"
$lblVersion.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblVersion.TextAlign = "MiddleCenter"
$actionGroup.Controls.Add($lblVersion)

# =============================== COPY FUNCTION ===============================
function Copy-Items {
    param(
        [string]$Source,
        [string]$Destination,
        [bool]$UseCredentials,
        [PSCredential]$Credentials,
        [string]$CopyMode,
        [array]$SelectedFiles
    )

    $mounted = @()
    $originalSource = $Source
    $originalDest   = $Destination

    # Map source drive if path isn't accessible
    if (-not (Test-Path $Source)) {
        if ($UseCredentials -and $Credentials) {
            try {
                $lblStatus.Text = "Mapping source drive..."
                New-PSDrive -Name "Z" -PSProvider FileSystem -Root $Source -Credential $Credentials -Persist -ErrorAction Stop | Out-Null
                $Source = "Z:\"
                $mounted += "Z"
            } catch {
                throw "Failed to map source drive: $($_.Exception.Message)"
            }
        } else {
            throw "Invalid source path and no credentials provided."
        }
    }

    # -- FIX: Build the true destination by appending the source folder name ---
    # Without this, copying C:\Temp\Backup to D:\Archive would dump the *contents*
    # of Backup directly into D:\Archive instead of creating D:\Archive\Backup\.
    $sourceFolderName = Split-Path $Source.TrimEnd('\') -Leaf
    $Destination      = Join-Path $Destination $sourceFolderName
    # -------------------------------------------------------------------------

    # Map destination drive if path isn't accessible
    if (-not (Test-Path $Destination)) {
        if ($Destination -like "\\*" -and $UseCredentials -and $Credentials) {
            try {
                $lblStatus.Text = "Mapping destination drive..."
                New-PSDrive -Name "Y" -PSProvider FileSystem -Root $Destination -Credential $Credentials -Persist -ErrorAction Stop | Out-Null
                $Destination = "Y:\"
                $mounted += "Y"
            } catch {
                throw "Failed to map destination drive: $($_.Exception.Message)"
            }
        } else {
            try {
                New-Item -ItemType Directory -Path $Destination -Force | Out-Null
            } catch {
                throw "Failed to create destination directory: $($_.Exception.Message)"
            }
        }
    }

    # Determine what to copy
    $itemsToCopy = @()

    if ($CopyMode -eq "Folder") {
        # Recurse everything under the source root (files AND directories)
        $itemsToCopy = Get-ChildItem -Path $Source -Recurse
        $statsLabels["Total Items"].Text = "Total Items: $($itemsToCopy.Count)"
    } else {
        # Only the files the user hand-picked in the list box
        foreach ($fileName in $SelectedFiles) {
            $fullPath = Join-Path $Source $fileName
            if (Test-Path $fullPath) {
                $itemsToCopy += Get-Item $fullPath
            }
        }
        $statsLabels["Total Items"].Text = "Total Items: $($itemsToCopy.Count)"
    }

    # Start copy operation
    $logFile   = Join-Path $logPath ("CopyLog_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
    $total     = $itemsToCopy.Count
    $counter   = 0
    $failed    = 0
    $totalSize = ($itemsToCopy | Where-Object { -not $_.PSIsContainer } | Measure-Object -Property Length -Sum).Sum
    $startTime = Get-Date

    $logBox.Clear()
    $logBox.AppendText("Starting copy operation...`r`n")
    $logBox.AppendText("Source      : $originalSource`r`n")
    $logBox.AppendText("Destination : $originalDest`r`n")
    $logBox.AppendText("Root folder : $sourceFolderName`r`n")
    $logBox.AppendText("Full dest   : $Destination`r`n")
    $logBox.AppendText("Mode        : $CopyMode`r`n")
    $logBox.AppendText("Total items : $total`r`n")
    if ($totalSize) {
        $logBox.AppendText("Total size  : $([math]::Round($totalSize / 1MB, 2)) MB`r`n")
    }
    $logBox.AppendText(("=" * 50) + "`r`n")

    Add-Content $logFile "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Copy started: $originalSource -> $Destination"
    Add-Content $logFile "Mode: $CopyMode, Total items: $total"

    foreach ($item in $itemsToCopy) {
        if ($script:copyCancelled) {
            $logBox.AppendText("`r`nCopy cancelled by user")
            Add-Content $logFile "[$(Get-Date -Format "HH:mm:ss")] Copy cancelled by user"
            break
        }

        # Preserve the path relative to the source root so subfolders are recreated
        $relative = $item.FullName.Substring($Source.TrimEnd('\').Length).TrimStart('\')
        $destPath = Join-Path $Destination $relative

        try {
            if ($item.PSIsContainer) {
                if (-not (Test-Path $destPath)) {
                    New-Item -ItemType Directory -Path $destPath -Force | Out-Null
                    $logBox.AppendText("[DIR] Created folder: $relative`r`n")
                }
            } else {
                $destDir = Split-Path $destPath -Parent
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item -Path $item.FullName -Destination $destPath -Force
                $logBox.AppendText("[OK]  Copied: $relative`r`n")
                Add-Content $logFile "[$(Get-Date -Format "HH:mm:ss")] Copied: $relative"
                $statsLabels["Copied"].Text = "Copied: $($counter + 1)"
            }
        } catch {
            $logBox.AppendText("[ERR] ERROR: $relative - $($_.Exception.Message)`r`n")
            Add-Content $logFile "[$(Get-Date -Format "HH:mm:ss")] ERROR: $relative - $($_.Exception.Message)"
            $failed++
            $statsLabels["Failed"].Text = "Failed: $failed"
        }

        $counter++
        if ($total -gt 0) {
            $percentComplete = [math]::Min(100, [math]::Round(($counter / $total) * 100))
            $progressBar.Value = $percentComplete
        }

        $elapsed = (Get-Date) - $startTime
        $statsLabels["Time Elapsed"].Text = "Time Elapsed: $($elapsed.ToString('hh\:mm\:ss'))"

        if ($counter -gt 0 -and $elapsed.TotalSeconds -gt 0) {
            $itemsPerSecond = $counter / $elapsed.TotalSeconds
            $statsLabels["Transfer Speed"].Text = "Transfer Speed: $([math]::Round($itemsPerSecond, 1)) items/s"
        }

        $lblStatus.Text = "Copying: $([math]::Round($percentComplete))% complete - $counter of $total items"
        [System.Windows.Forms.Application]::DoEvents()
    }

    return @{
        LogFile      = $logFile
        Total        = $total
        Copied       = $counter
        Failed       = $failed
        StartTime    = $startTime
        EndTime      = Get-Date
        MountedDrives = $mounted
    }
}

$btnCopy.Add_Click({
    $source      = $textBoxSource.Text.Trim()
    $destination = $textBoxDest.Text.Trim()
    $useCred     = $chkUseCred.Checked
    $copyMode    = if ($radioFolder.Checked) { "Folder" } else { "Files" }
    $script:copyCancelled = $false
    $script:copyRunning   = $true

    if ([string]::IsNullOrWhiteSpace($source) -or [string]::IsNullOrWhiteSpace($destination)) {
        [System.Windows.Forms.MessageBox]::Show("Please specify both source and destination paths.", "Validation Error",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    if (-not (Test-Path $source) -and -not $useCred) {
        [System.Windows.Forms.MessageBox]::Show("Source path does not exist and no credentials provided.", "Validation Error",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    if ($copyMode -eq "Files" -and $fileListBox.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one file to copy.", "Validation Error",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $btnCancel.Enabled   = $true
    $btnCopy.Enabled     = $false
    $btnHistory.Enabled  = $false
    $btnSettings.Enabled = $false
    $btnHelp.Enabled     = $false

    if ($useCred -and -not $script:cred -and (Test-Path $credFile)) {
        try {
            $script:cred = Import-Clixml $credFile
            $lblStatus.Text = "Loaded saved credentials"
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to load saved credentials. Please set them manually.",
                "Credential Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $btnCancel.Enabled = $false; $btnCopy.Enabled = $true
            $btnHistory.Enabled = $true; $btnSettings.Enabled = $true; $btnHelp.Enabled = $true
            return
        }
    }

    $settings.LastSource      = $source
    $settings.LastDestination = $destination
    $settings.SaveCredentials = $chkSaveCred.Checked
    $settings.AutoDisconnect  = $chkDisconnect.Checked
    $settings.CopyMode        = $copyMode
    $settings.LastFileFilter  = $txtFileFilter.Text
    $settings | ConvertTo-Json | Set-Content $settingsFile

    if ($recentList.Items -notcontains $source) {
        $recentList.Items.Insert(0, $source)
        if ($recentList.Items.Count -gt 10) { $recentList.Items.RemoveAt($recentList.Items.Count - 1) }
    }

    if ($useCred -and $chkSaveCred.Checked -and $script:cred) {
        $script:cred | Export-Clixml -Path $credFile
        $lblStatus.Text = "Credentials saved"
    }

    try {
        $selectedFiles = if ($copyMode -eq "Files") { @($fileListBox.SelectedItems) } else { @() }

        $result = Copy-Items -Source $source -Destination $destination `
            -UseCredentials $useCred -Credentials $script:cred `
            -CopyMode $copyMode -SelectedFiles $selectedFiles

        if ($chkDisconnect.Checked -and $result.MountedDrives.Count -gt 0) {
            $lblStatus.Text = "Disconnecting network drives..."
            foreach ($d in $result.MountedDrives) {
                Remove-PSDrive -Name $d -Force -ErrorAction SilentlyContinue
            }
        }

        $totalTime = $result.EndTime - $result.StartTime

        $logBox.AppendText(("=" * 50) + "`r`n")
        $logBox.AppendText("Copy operation completed!`r`n")
        $logBox.AppendText("Total time     : $($totalTime.ToString('hh\:mm\:ss'))`r`n")
        $logBox.AppendText("Items processed: $($result.Copied + $result.Failed)`r`n")
        $logBox.AppendText("Successfully   : $($result.Copied)`r`n")
        $logBox.AppendText("Failed         : $($result.Failed)`r`n")

        Add-Content $result.LogFile "[$(Get-Date -Format "HH:mm:ss")] Copy completed - Items: $($result.Copied + $result.Failed), Copied: $($result.Copied), Failed: $($result.Failed), Time: $($totalTime.ToString('hh\:mm\:ss'))"

        [System.Windows.Forms.MessageBox]::Show(
            "Copy complete!`nItems processed: $($result.Copied + $result.Failed)`nSuccessfully copied: $($result.Copied)`nFailed: $($result.Failed)`nTime: $($totalTime.ToString('hh\:mm\:ss'))`nLog saved at:`n$($result.LogFile)",
            "Copy Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error during copy: $($_.Exception.Message)",
            "Copy Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }

    $btnCancel.Enabled   = $false
    $btnCopy.Enabled     = $true
    $btnHistory.Enabled  = $true
    $btnSettings.Enabled = $true
    $btnHelp.Enabled     = $true
    $btnCancel.Text      = "[Cancel]"
    $lblStatus.Text      = "Ready"
    $script:copyRunning  = $false
})

$btnCancel.Add_Click({
    $script:copyCancelled = $true
    $btnCancel.Enabled    = $false
    $btnCancel.Text       = "[Cancelling...]"
    $lblStatus.Text       = "Cancelling copy operation..."
})

$btnHistory.Add_Click({
    if (Test-Path $logPath) {
        $logs    = Get-ChildItem $logPath -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 10
        $logList = $logs | ForEach-Object { "$($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')) - $($_.Name)" }

        $historyForm = New-Object System.Windows.Forms.Form
        $historyForm.Text          = "Copy History"
        $historyForm.Size          = New-Object System.Drawing.Size(500, 400)
        $historyForm.StartPosition = "CenterParent"
        $historyForm.BackColor     = "#2d2d2d"

        $listBox = New-Object System.Windows.Forms.ListBox
        $listBox.Location  = New-Object System.Drawing.Point(10, 10)
        $listBox.Size      = New-Object System.Drawing.Size(465, 300)
        $listBox.BackColor = "#1e1e1e"
        $listBox.ForeColor = "#ffffff"
        $listBox.Items.AddRange($logList)
        $historyForm.Controls.Add($listBox)

        $btnView = New-ModernButton "View Log" 10 320 100 35
        $btnView.Add_Click({
            if ($listBox.SelectedIndex -ge 0) {
                Start-Process notepad.exe $logs[$listBox.SelectedIndex].FullName
            }
        })
        $historyForm.Controls.Add($btnView)

        $btnClose = New-ModernButton "Close" 120 320 100 35 "#dc3545"
        $btnClose.Add_Click({ $historyForm.Close() })
        $historyForm.Controls.Add($btnClose)

        $historyForm.ShowDialog()
    } else {
        [System.Windows.Forms.MessageBox]::Show("No logs found.", "History",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})

$btnSettings.Add_Click({
    $settingsForm = New-Object System.Windows.Forms.Form
    $settingsForm.Text          = "Settings"
    $settingsForm.Size          = New-Object System.Drawing.Size(400, 300)
    $settingsForm.StartPosition = "CenterParent"
    $settingsForm.BackColor     = "#2d2d2d"

    $lblTheme          = New-Object System.Windows.Forms.Label
    $lblTheme.Text     = "Theme:"
    $lblTheme.Location = New-Object System.Drawing.Point(20, 20)
    $lblTheme.Size     = New-Object System.Drawing.Size(100, 25)
    $lblTheme.ForeColor = "#ffffff"
    $settingsForm.Controls.Add($lblTheme)

    $cmbTheme          = New-Object System.Windows.Forms.ComboBox
    $cmbTheme.Location = New-Object System.Drawing.Point(130, 17)
    $cmbTheme.Size     = New-Object System.Drawing.Size(150, 25)
    $cmbTheme.BackColor = "#1e1e1e"
    $cmbTheme.ForeColor = "#ffffff"
    $cmbTheme.Items.AddRange(@("Dark", "Light", "Blue"))
    $cmbTheme.SelectedItem = $settings.Theme
    $settingsForm.Controls.Add($cmbTheme)

    $btnSave = New-ModernButton "Save" 130 200 100 35 "#28a745"
    $btnSave.Add_Click({
        $settings.Theme = $cmbTheme.SelectedItem
        $settings | ConvertTo-Json | Set-Content $settingsFile
        $settingsForm.Close()
        [System.Windows.Forms.MessageBox]::Show("Settings saved. Please restart to apply theme changes.",
            "Settings", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })
    $settingsForm.Controls.Add($btnSave)
    $settingsForm.ShowDialog()
})

$btnHelp.Add_Click({
    [System.Windows.Forms.MessageBox]::Show(
        "CopyToolz v2.1 - Network File Copy Utility`n`n" +
        "Features:`n" +
        "* Copy entire folders with all subfolders and files`n" +
        "* Select specific files to copy`n" +
        "* Filter files by pattern (e.g., *.txt, *.jpg)`n" +
        "* Copy between local and network locations`n" +
        "* Support for UNC paths and network drives`n" +
        "* Save and reuse network credentials`n" +
        "* Real-time progress tracking`n" +
        "* Detailed copy logs`n`n" +
        "Instructions:`n" +
        "1. Enter source and destination paths (use Browse/Network buttons)`n" +
        "2. Choose copy mode: Folder or Specific Files`n" +
        "3. For file mode, load and select files to copy`n" +
        "4. Configure options as needed`n" +
        "5. Click Start Copy to begin`n" +
        "6. Monitor progress in real-time`n`n" +
        "Author: Henchman33",
        "CopyToolz Help",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information)
})

# =============================== TOOLBAR ===============================
$toolStrip = New-Object System.Windows.Forms.ToolStrip
$toolStrip.BackColor = "#007acc"
$toolStrip.ForeColor = "#ffffff"
$toolStrip.Items.Add("File")
$toolStrip.Items.Add("Edit")
$toolStrip.Items.Add("View")
$toolStrip.Items.Add("Help")
$form.Controls.Add($toolStrip)
$toolStrip.Dock = "Top"

# =============================== STATUS BAR ===============================
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.BackColor = "#1e1e1e"
$statusStrip.ForeColor = "#ffffff"

$statusLabel      = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Ready"
$statusStrip.Items.Add($statusLabel)

$versionLabel           = New-Object System.Windows.Forms.ToolStripStatusLabel
$versionLabel.Text      = "Version 2.2 by Henchman33"
$versionLabel.Alignment = "Right"
$statusStrip.Items.Add($versionLabel)

$form.Controls.Add($statusStrip)

# =============================== LAUNCH FORM ===============================
[void]$form.ShowDialog()
