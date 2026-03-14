# ============================================================================
# CopyToolz - Advanced Network File Copy Utility
# Author: Henchman33
# Version: 2.0
# ============================================================================

#=============================== MODULE LOADING ===============================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework  # For modern WPF styles

# Create paths
$basePath = Split-Path -Parent $MyInvocation.MyCommand.Definition
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
$form.Text = "📋 CopyToolz v2.0 - by Henchman33"
$form.Size = New-Object System.Drawing.Size(1200, 800)
$form.StartPosition = "CenterScreen"
$form.BackColor = "#2d2d2d"  # Dark theme default
$form.ForeColor = "#ffffff"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# Modern title bar with accent color
$titlePanel = New-Object System.Windows.Forms.Panel
$titlePanel.Size = New-Object System.Drawing.Size($form.Width, 40)
$titlePanel.BackColor = "#007acc"
$titlePanel.Dock = "Top"
$form.Controls.Add($titlePanel)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "📋 CopyToolz - Network File Transfer Utility"
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
$mainPanel.Size = New-Object System.Drawing.Size(1160, 700)
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

# Source path textbox
$textBoxSource = New-Object System.Windows.Forms.TextBox
$textBoxSource.Location = New-Object System.Drawing.Point(20, 35)
$textBoxSource.Size = New-Object System.Drawing.Size(400, 25)
$textBoxSource.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$textBoxSource.BackColor = "#2d2d2d"
$textBoxSource.ForeColor = "#ffffff"
$textBoxSource.BorderStyle = "FixedSingle"
$textBoxSource.Text = $settings.LastSource
$sourceGroup.Controls.Add($textBoxSource)

# Browse button for source
$btnBrowseSource = New-ModernButton "📁 Browse" 430 32 90
$btnBrowseSource.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select Source Folder"
    $folderBrowser.RootFolder = "MyComputer"
    if ($folderBrowser.ShowDialog() -eq "OK") {
        $textBoxSource.Text = $folderBrowser.SelectedPath
    }
})
$sourceGroup.Controls.Add($btnBrowseSource)

# Network button for source
$btnNetworkSource = New-ModernButton "🌐 Network" 430 62 90 30 "#6c757d"
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

# Destination path textbox
$textBoxDest = New-Object System.Windows.Forms.TextBox
$textBoxDest.Location = New-Object System.Drawing.Point(20, 35)
$textBoxDest.Size = New-Object System.Drawing.Size(400, 25)
$textBoxDest.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$textBoxDest.BackColor = "#2d2d2d"
$textBoxDest.ForeColor = "#ffffff"
$textBoxDest.BorderStyle = "FixedSingle"
$textBoxDest.Text = $settings.LastDestination
$destGroup.Controls.Add($textBoxDest)

# Browse button for destination
$btnBrowseDest = New-ModernButton "📁 Browse" 430 32 90
$btnBrowseDest.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select Destination Folder"
    if ($folderBrowser.ShowDialog() -eq "OK") {
        $textBoxDest.Text = $folderBrowser.SelectedPath
    }
})
$destGroup.Controls.Add($btnBrowseDest)

# Network button for destination
$btnNetworkDest = New-ModernButton "🌐 Network" 430 62 90 30 "#6c757d"
$btnNetworkDest.Add_Click({
    $uncPath = [Microsoft.VisualBasic.Interaction]::InputBox("Enter UNC path:", "Network Location", "\\server\share")
    if ($uncPath) {
        $textBoxDest.Text = $uncPath
    }
})
$destGroup.Controls.Add($btnNetworkDest)

# =============================== OPTIONS PANEL ===============================
$optionsGroup = New-Object System.Windows.Forms.GroupBox
$optionsGroup.Text = " Options "
$optionsGroup.Location = New-Object System.Drawing.Point(15, 235)
$optionsGroup.Size = New-Object System.Drawing.Size(550, 120)
$optionsGroup.ForeColor = "#ffffff"
$optionsGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($optionsGroup)

# Checkboxes with modern styling
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

# Credentials button
$btnCred = New-ModernButton "🔑 Set Credentials" 200 30 150 35 "#28a745"
$btnCred.Enabled = $false
$btnCred.Add_Click({
    $script:cred = Get-Credential
    $btnCred.Text = "✅ Credentials Set"
    Start-Sleep -Seconds 2
    $btnCred.Text = "🔑 Set Credentials"
})
$optionsGroup.Controls.Add($btnCred)

$chkUseCred.Add_CheckedChanged({
    $btnCred.Enabled = $chkUseCred.Checked
})

$script:cred = $null

# =============================== PROGRESS & LOG SECTION ===============================
$progressGroup = New-Object System.Windows.Forms.GroupBox
$progressGroup.Text = " Progress "
$progressGroup.Location = New-Object System.Drawing.Point(15, 365)
$progressGroup.Size = New-Object System.Drawing.Size(550, 210)
$progressGroup.ForeColor = "#ffffff"
$progressGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($progressGroup)

# Modern progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 30)
$progressBar.Size = New-Object System.Drawing.Size(510, 30)
$progressBar.Style = "Continuous"
$progressBar.ForeColor = "#007acc"
$progressBar.BackColor = "#2d2d2d"
$progressGroup.Controls.Add($progressBar)

# Status label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Ready"
$lblStatus.Location = New-Object System.Drawing.Point(20, 70)
$lblStatus.Size = New-Object System.Drawing.Size(510, 25)
$lblStatus.ForeColor = "#cccccc"
$progressGroup.Controls.Add($lblStatus)

# Log textbox with improved styling
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(20, 100)
$logBox.Size = New-Object System.Drawing.Size(510, 95)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = "#1e1e1e"
$logBox.ForeColor = "#00ff00"
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$logBox.BorderStyle = "FixedSingle"
$progressGroup.Controls.Add($logBox)

# =============================== RIGHT COLUMN (280px wide) ===============================
# =============================== STATISTICS PANEL ===============================
$statsGroup = New-Object System.Windows.Forms.GroupBox
$statsGroup.Text = " Statistics "
$statsGroup.Location = New-Object System.Drawing.Point(585, 15)
$statsGroup.Size = New-Object System.Drawing.Size(280, 160)
$statsGroup.ForeColor = "#ffffff"
$statsGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($statsGroup)

$statsLabels = @{}
$statsPositions = @(
    @{Name="Total Files"; Top=30},
    @{Name="Copied Files"; Top=55},
    @{Name="Failed Files"; Top=80},
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

# Time Elapsed label (separate to highlight it)
$lblTimeElapsed = New-Object System.Windows.Forms.Label
$lblTimeElapsed.Text = "Time Elapsed: 00:00:00"
$lblTimeElapsed.Location = New-Object System.Drawing.Point(20, 155)
$lblTimeElapsed.Size = New-Object System.Drawing.Size(240, 20)
$lblTimeElapsed.ForeColor = "#00ff00"
$lblTimeElapsed.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$statsGroup.Controls.Add($lblTimeElapsed)
$statsLabels["Time Elapsed"] = $lblTimeElapsed

# =============================== RECENT LOCATIONS ===============================
$recentGroup = New-Object System.Windows.Forms.GroupBox
$recentGroup.Text = " Recent Locations "
$recentGroup.Location = New-Object System.Drawing.Point(585, 185)
$recentGroup.Size = New-Object System.Drawing.Size(280, 150)
$recentGroup.ForeColor = "#ffffff"
$recentGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($recentGroup)

$recentList = New-Object System.Windows.Forms.ListBox
$recentList.Location = New-Object System.Drawing.Point(15, 25)
$recentList.Size = New-Object System.Drawing.Size(250, 80)
$recentList.BackColor = "#2d2d2d"
$recentList.ForeColor = "#ffffff"
$recentList.BorderStyle = "FixedSingle"
# Add some sample recent locations (in real app, these would be loaded from settings)
$recentList.Items.AddRange(@("\\server\share1", "\\server\share2", "C:\Users\Public\Documents", "D:\Backups", "\\nas\media"))
$recentGroup.Controls.Add($recentList)

$recentList.Add_DoubleClick({
    if ($recentList.SelectedItem) {
        $textBoxSource.Text = $recentList.SelectedItem
    }
})

# Instructions label
$recentInstructions = New-Object System.Windows.Forms.Label
$recentInstructions.Text = "Double-click to use as source"
$recentInstructions.Location = New-Object System.Drawing.Point(15, 110)
$recentInstructions.Size = New-Object System.Drawing.Size(250, 20)
$recentInstructions.ForeColor = "#888888"
$recentInstructions.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$recentGroup.Controls.Add($recentInstructions)

# =============================== ACTION BUTTONS PANEL (ENLARGED) ===============================
$actionGroup = New-Object System.Windows.Forms.GroupBox
$actionGroup.Text = " Actions "
$actionGroup.Location = New-Object System.Drawing.Point(585, 345)
$actionGroup.Size = New-Object System.Drawing.Size(280, 240)  # Increased height from 210 to 240
$actionGroup.ForeColor = "#ffffff"
$actionGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$mainPanel.Controls.Add($actionGroup)

# Start Copy button (large, prominent)
$btnCopy = New-ModernButton "▶ Start Copy" 20 30 240 50 "#28a745"
$btnCopy.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$actionGroup.Controls.Add($btnCopy)

# Cancel button
$btnCancel = New-ModernButton "✖ Cancel" 20 95 115 40 "#dc3545"
$btnCancel.Enabled = $false
$actionGroup.Controls.Add($btnCancel)

# History button
$btnHistory = New-ModernButton "📜 History" 145 95 115 40 "#6c757d"
$actionGroup.Controls.Add($btnHistory)

# Settings button
$btnSettings = New-ModernButton "⚙ Settings" 20 150 115 40 "#6c757d"
$actionGroup.Controls.Add($btnSettings)

# Help button
$btnHelp = New-ModernButton "❓ Help" 145 150 115 40 "#6c757d"
$actionGroup.Controls.Add($btnHelp)

# Version info with plenty of space
$lblVersion = New-Object System.Windows.Forms.Label
$lblVersion.Text = "CopyToolz v2.0  |  © 2024 Henchman33"
$lblVersion.Location = New-Object System.Drawing.Point(20, 205)
$lblVersion.Size = New-Object System.Drawing.Size(240, 25)
$lblVersion.ForeColor = "#aaaaaa"
$lblVersion.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblVersion.TextAlign = "MiddleCenter"
$actionGroup.Controls.Add($lblVersion)

# Add a small separator line for visual appeal
$separator = New-Object System.Windows.Forms.Label
$separator.BorderStyle = "Fixed3D"
$separator.Location = New-Object System.Drawing.Point(20, 195)
$separator.Size = New-Object System.Drawing.Size(240, 2)
$separator.BackColor = "#555555"
$actionGroup.Controls.Add($separator)

# =============================== COPY FUNCTION ===============================
$btnCopy.Add_Click({
    $source = $textBoxSource.Text.Trim()
    $destination = $textBoxDest.Text.Trim()
    $mounted = @()
    $script:copyCancelled = $false
    $script:copyRunning = $true
    
    # Validate inputs
    if ([string]::IsNullOrWhiteSpace($source) -or [string]::IsNullOrWhiteSpace($destination)) {
        [System.Windows.Forms.MessageBox]::Show("Please specify both source and destination paths.", "Validation Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    # Enable/disable buttons
    $btnCancel.Enabled = $true
    $btnCopy.Enabled = $false
    $btnHistory.Enabled = $false
    $btnSettings.Enabled = $false
    $btnHelp.Enabled = $false
    $lblStatus.Text = "Initializing copy operation..."
    
    # Load saved credentials if enabled
    if ($chkUseCred.Checked -and -not $script:cred -and (Test-Path $credFile)) {
        try {
            $script:cred = Import-Clixml $credFile
            $lblStatus.Text = "Loaded saved credentials"
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to load saved credentials. Please set them manually.", 
                "Credential Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $btnCancel.Enabled = $false
            $btnCopy.Enabled = $true
            $btnHistory.Enabled = $true
            $btnSettings.Enabled = $true
            $btnHelp.Enabled = $true
            return
        }
    }
    
    # Save settings
    $settings.LastSource = $source
    $settings.LastDestination = $destination
    $settings.SaveCredentials = $chkSaveCred.Checked
    $settings.AutoDisconnect = $chkDisconnect.Checked
    $settings | ConvertTo-Json | Set-Content $settingsFile
    
    # Add to recent locations if not already there
    if ($recentList.Items -notcontains $source) {
        $recentList.Items.Insert(0, $source)
        if ($recentList.Items.Count -gt 10) {
            $recentList.Items.RemoveAt($recentList.Items.Count - 1)
        }
    }
    
    # Map source if needed
    if (-not (Test-Path $source)) {
        if ($chkUseCred.Checked -and $script:cred) {
            try {
                $lblStatus.Text = "Mapping source drive..."
                New-PSDrive -Name "Z" -PSProvider FileSystem -Root $source -Credential $script:cred -Persist -ErrorAction Stop | Out-Null
                $source = "Z:\"
                $mounted += "Z"
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to map source drive: $($_.Exception.Message)", 
                    "Mapping Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                $btnCancel.Enabled = $false
                $btnCopy.Enabled = $true
                $btnHistory.Enabled = $true
                $btnSettings.Enabled = $true
                $btnHelp.Enabled = $true
                return
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("Invalid source path and no credentials provided.", 
                "Path Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $btnCancel.Enabled = $false
            $btnCopy.Enabled = $true
            $btnHistory.Enabled = $true
            $btnSettings.Enabled = $true
            $btnHelp.Enabled = $true
            return
        }
    }
    
    # Map destination if needed
    if (-not (Test-Path $destination)) {
        if ($chkUseCred.Checked -and $script:cred) {
            try {
                $lblStatus.Text = "Mapping destination drive..."
                New-PSDrive -Name "Y" -PSProvider FileSystem -Root $destination -Credential $script:cred -Persist -ErrorAction Stop | Out-Null
                $destination = "Y:\"
                $mounted += "Y"
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to map destination drive: $($_.Exception.Message)", 
                    "Mapping Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                $btnCancel.Enabled = $false
                $btnCopy.Enabled = $true
                $btnHistory.Enabled = $true
                $btnSettings.Enabled = $true
                $btnHelp.Enabled = $true
                return
            }
        } else {
            try {
                New-Item -ItemType Directory -Path $destination -Force | Out-Null
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to create destination directory: $($_.Exception.Message)", 
                    "Directory Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                $btnCancel.Enabled = $false
                $btnCopy.Enabled = $true
                $btnHistory.Enabled = $true
                $btnSettings.Enabled = $true
                $btnHelp.Enabled = $true
                return
            }
        }
    }
    
    # Save credentials if requested
    if ($chkUseCred.Checked -and $chkSaveCred.Checked -and $script:cred) {
        $script:cred | Export-Clixml -Path $credFile
        $lblStatus.Text = "Credentials saved"
    }
    
    # Start copy operation
    $logFile = Join-Path $logPath ("CopyLog_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
    $lblStatus.Text = "Scanning files..."
    $files = Get-ChildItem -Path $source -Recurse -File
    $total = $files.Count
    $counter = 0
    $failed = 0
    $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
    $startTime = Get-Date
    
    $logBox.Clear()
    $logBox.AppendText("Starting copy operation...`r`n")
    $logBox.AppendText("Source: $source`r`n")
    $logBox.AppendText("Destination: $destination`r`n")
    $logBox.AppendText("Total files: $total`r`n")
    $logBox.AppendText("Total size: $([math]::Round($totalSize / 1MB, 2)) MB`r`n")
    $logBox.AppendText("=" * 50 + "`r`n")
    
    Add-Content $logFile "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Copy started: $source -> $destination"
    Add-Content $logFile "Total files: $total, Total size: $([math]::Round($totalSize / 1MB, 2)) MB"
    
    # Update statistics
    $statsLabels["Total Files"].Text = "Total Files: $total"
    $statsLabels["Total Size"].Text = "Total Size: $([math]::Round($totalSize / 1MB, 2)) MB"
    
    foreach ($file in $files) {
        if ($script:copyCancelled) {
            $logBox.AppendText("`r`n⚠ Copy cancelled by user")
            Add-Content $logFile "[$(Get-Date -Format "HH:mm:ss")] Copy cancelled by user"
            break
        }
        
        $relative = $file.FullName.Substring($source.Length).TrimStart('\')
        $destPath = Join-Path $destination $relative
        $destDir = Split-Path $destPath -Parent
        
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        try {
            Copy-Item -Path $file.FullName -Destination $destPath -Force
            $logBox.AppendText("✓ $relative`r`n")
            Add-Content $logFile "[$(Get-Date -Format "HH:mm:ss")] Copied: $relative"
            $statsLabels["Copied Files"].Text = "Copied Files: $($counter + 1)"
        } catch {
            $logBox.AppendText("✗ ERROR: $relative - $($_.Exception.Message)`r`n")
            Add-Content $logFile "[$(Get-Date -Format "HH:mm:ss")] ERROR: $relative - $($_.Exception.Message)"
            $failed++
            $statsLabels["Failed Files"].Text = "Failed Files: $failed"
        }
        
        $counter++
        $percentComplete = [math]::Min(100, [math]::Round(($counter / $total) * 100))
        $progressBar.Value = $percentComplete
        
        # Update time elapsed
        $elapsed = (Get-Date) - $startTime
        $statsLabels["Time Elapsed"].Text = "Time Elapsed: $($elapsed.ToString('hh\:mm\:ss'))"
        
        if ($counter -gt 0 -and $elapsed.TotalSeconds -gt 0) {
            $itemsPerSecond = $counter / $elapsed.TotalSeconds
            $statsLabels["Transfer Speed"].Text = "Transfer Speed: $([math]::Round($itemsPerSecond, 1)) files/s"
        }
        
        $lblStatus.Text = "Copying: $([math]::Round($percentComplete))% complete - $counter of $total files"
        [System.Windows.Forms.Application]::DoEvents()
    }
    
    # Disconnect drives if requested
    if ($chkDisconnect.Checked -and $mounted.Count -gt 0) {
        $lblStatus.Text = "Disconnecting network drives..."
        foreach ($d in $mounted) {
            Remove-PSDrive -Name $d -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Final status
    $endTime = Get-Date
    $totalTime = $endTime - $startTime
    
    $logBox.AppendText("=" * 50 + "`r`n")
    $logBox.AppendText("Copy operation completed!`r`n")
    $logBox.AppendText("Total time: $($totalTime.ToString('hh\:mm\:ss'))`r`n")
    $logBox.AppendText("Files copied: $counter`r`n")
    $logBox.AppendText("Files failed: $failed`r`n")
    
    Add-Content $logFile "[$(Get-Date -Format "HH:mm:ss")] Copy completed - Files: $counter, Failed: $failed, Time: $($totalTime.ToString('hh\:mm\:ss'))"
    
    # Show completion message
    [System.Windows.Forms.MessageBox]::Show("✅ Copy complete!`nFiles: $counter`nFailed: $failed`nTime: $($totalTime.ToString('hh\:mm\:ss'))`nLog saved at:`n$logFile", 
        "Copy Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    
    # Reset buttons
    $btnCancel.Enabled = $false
    $btnCopy.Enabled = $true
    $btnHistory.Enabled = $true
    $btnSettings.Enabled = $true
    $btnHelp.Enabled = $true
    $btnCancel.Text = "✖ Cancel"
    $lblStatus.Text = "Ready"
    $script:copyRunning = $false
})

# Cancel button functionality
$btnCancel.Add_Click({
    $script:copyCancelled = $true
    $btnCancel.Enabled = $false
    $btnCancel.Text = "✖ Cancelling..."
    $lblStatus.Text = "Cancelling copy operation..."
})

# History button
$btnHistory.Add_Click({
    if (Test-Path $logPath) {
        $logs = Get-ChildItem $logPath -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 10
        $logList = $logs | ForEach-Object { "$($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')) - $($_.Name)" }
        
        $historyForm = New-Object System.Windows.Forms.Form
        $historyForm.Text = "Copy History"
        $historyForm.Size = New-Object System.Drawing.Size(500, 400)
        $historyForm.StartPosition = "CenterParent"
        $historyForm.BackColor = "#2d2d2d"
        
        $listBox = New-Object System.Windows.Forms.ListBox
        $listBox.Location = New-Object System.Drawing.Point(10, 10)
        $listBox.Size = New-Object System.Drawing.Size(465, 300)
        $listBox.BackColor = "#1e1e1e"
        $listBox.ForeColor = "#ffffff"
        $listBox.Items.AddRange($logList)
        $historyForm.Controls.Add($listBox)
        
        $btnView = New-ModernButton "View Log" 10 320 100 35
        $btnView.Add_Click({
            if ($listBox.SelectedIndex -ge 0) {
                $selectedLog = $logs[$listBox.SelectedIndex]
                Start-Process notepad.exe $selectedLog.FullName
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

# Settings button
$btnSettings.Add_Click({
    $settingsForm = New-Object System.Windows.Forms.Form
    $settingsForm.Text = "Settings"
    $settingsForm.Size = New-Object System.Drawing.Size(400, 300)
    $settingsForm.StartPosition = "CenterParent"
    $settingsForm.BackColor = "#2d2d2d"
    
    $lblTheme = New-Object System.Windows.Forms.Label
    $lblTheme.Text = "Theme:"
    $lblTheme.Location = New-Object System.Drawing.Point(20, 20)
    $lblTheme.Size = New-Object System.Drawing.Size(100, 25)
    $lblTheme.ForeColor = "#ffffff"
    $settingsForm.Controls.Add($lblTheme)
    
    $cmbTheme = New-Object System.Windows.Forms.ComboBox
    $cmbTheme.Location = New-Object System.Drawing.Point(130, 17)
    $cmbTheme.Size = New-Object System.Drawing.Size(150, 25)
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
        [System.Windows.Forms.MessageBox]::Show("Settings saved. Please restart the application to apply theme changes.", 
            "Settings", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })
    $settingsForm.Controls.Add($btnSave)
    
    $settingsForm.ShowDialog()
})

# Help button
$btnHelp.Add_Click({
    [System.Windows.Forms.MessageBox]::Show(
        "CopyToolz v2.0 - Network File Copy Utility`n`n" +
        "Features:`n" +
        "• Copy files between local and network locations`n" +
        "• Support for UNC paths and network drives`n" +
        "• Save and reuse network credentials`n" +
        "• Real-time progress tracking`n" +
        "• Detailed copy logs`n`n" +
        "Instructions:`n" +
        "1. Enter source and destination paths (use Browse/Network buttons)`n" +
        "2. Configure options as needed`n" +
        "3. Click Start Copy to begin`n" +
        "4. Monitor progress in real-time`n`n" +
        "Author: Henchman33",
        "CopyToolz Help",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
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

$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Ready"
$statusStrip.Items.Add($statusLabel)

$versionLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$versionLabel.Text = "v2.0 by Henchman33"
$versionLabel.Alignment = "Right"
$statusStrip.Items.Add($versionLabel)

$form.Controls.Add($statusStrip)

# =============================== LAUNCH FORM ===============================
[void]$form.ShowDialog()
