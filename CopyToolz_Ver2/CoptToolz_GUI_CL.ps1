# ===============================================================
#  CopyToolz - by Henchman33
#  Modern file copy/backup/move tool with network support
#  Claude.AI Build
# ===============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

# ─────────────────────────────────────────────────────────────
#  PATHS & FOLDERS
# ─────────────────────────────────────────────────────────────
# Safely resolve the script's own folder regardless of how it was launched
# (double-click, ISE, VS Code, PS console, right-click Run)
if ($PSScriptRoot) {
    $basePath = $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Definition -and
          (Test-Path $MyInvocation.MyCommand.Definition -ErrorAction SilentlyContinue)) {
    $basePath = Split-Path -Parent $MyInvocation.MyCommand.Definition
} else {
    # Fallback: store next to wherever the user is currently sitting
    $basePath = $PWD.Path
}

$script:configPath = Join-Path $basePath "config"
$script:logPath    = Join-Path $basePath "logs"
$script:credFile   = Join-Path $script:configPath "credentials.xml"

foreach ($dir in @($script:configPath, $script:logPath)) {
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory | Out-Null }
}

# ─────────────────────────────────────────────────────────────
#  COLOR PALETTE  (dark industrial theme)
# ─────────────────────────────────────────────────────────────
$clrBg        = [System.Drawing.Color]::FromArgb(18,  18,  24)
$clrPanel     = [System.Drawing.Color]::FromArgb(28,  28,  38)
$clrCard      = [System.Drawing.Color]::FromArgb(36,  36,  50)
$clrBorder    = [System.Drawing.Color]::FromArgb(55,  55,  75)
$clrAccent    = [System.Drawing.Color]::FromArgb(0,  188, 140)   # teal
$clrAccentDim = [System.Drawing.Color]::FromArgb(0,  130,  96)
$clrDanger    = [System.Drawing.Color]::FromArgb(220,  70,  70)
$clrText      = [System.Drawing.Color]::FromArgb(220, 220, 230)
$clrMuted     = [System.Drawing.Color]::FromArgb(120, 120, 145)
$clrInput     = [System.Drawing.Color]::FromArgb(22,  22,  32)
$clrSuccess   = [System.Drawing.Color]::FromArgb(0,  210, 150)

$fontTitle    = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$fontSub      = New-Object System.Drawing.Font("Segoe UI", 8,  [System.Drawing.FontStyle]::Regular)
$fontLabel    = New-Object System.Drawing.Font("Segoe UI", 9,  [System.Drawing.FontStyle]::Bold)
$fontInput    = New-Object System.Drawing.Font("Consolas", 9,  [System.Drawing.FontStyle]::Regular)
$fontBtn      = New-Object System.Drawing.Font("Segoe UI", 9,  [System.Drawing.FontStyle]::Bold)
$fontLog      = New-Object System.Drawing.Font("Consolas", 8,  [System.Drawing.FontStyle]::Regular)
$fontSmall    = New-Object System.Drawing.Font("Segoe UI", 8,  [System.Drawing.FontStyle]::Regular)

# ─────────────────────────────────────────────────────────────
#  HELPER: styled flat button
# ─────────────────────────────────────────────────────────────
function New-FlatButton {
    param(
        [string]$Text,
        [int]$X, [int]$Y,
        [int]$W = 130, [int]$H = 32,
        [System.Drawing.Color]$Bg,
        [System.Drawing.Color]$Fg,
        [System.Drawing.Font]$Font
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text        = $Text
    $btn.Location    = New-Object System.Drawing.Point($X, $Y)
    $btn.Size        = New-Object System.Drawing.Size($W, $H)
    $btn.FlatStyle   = [System.Windows.Forms.FlatStyle]::Flat
    $btn.BackColor   = $Bg
    $btn.ForeColor   = $Fg
    $btn.Font        = $Font
    $btn.Cursor      = [System.Windows.Forms.Cursors]::Hand
    $btn.FlatAppearance.BorderSize  = 0
    $btn.FlatAppearance.MouseOverBackColor  = [System.Drawing.Color]::FromArgb(
        [math]::Min(255, $Bg.R + 25),
        [math]::Min(255, $Bg.G + 25),
        [math]::Min(255, $Bg.B + 25))
    $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(
        [math]::Max(0, $Bg.R - 20),
        [math]::Max(0, $Bg.G - 20),
        [math]::Max(0, $Bg.B - 20))
    return $btn
}

# ─────────────────────────────────────────────────────────────
#  HELPER: styled checkbox
# ─────────────────────────────────────────────────────────────
function New-StyledCheckBox {
    param([string]$Text, [int]$X, [int]$Y, [int]$W = 220)
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text      = $Text
    $chk.Location  = New-Object System.Drawing.Point($X, $Y)
    $chk.Size      = New-Object System.Drawing.Size($W, 22)
    $chk.Font      = $fontSmall
    $chk.ForeColor = $clrText
    $chk.BackColor = [System.Drawing.Color]::Transparent
    $chk.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    return $chk
}

# ─────────────────────────────────────────────────────────────
#  HELPER: section label
# ─────────────────────────────────────────────────────────────
function New-SectionLabel {
    param([string]$Text, [int]$X, [int]$Y, [int]$W = 200)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text      = $Text
    $lbl.Location  = New-Object System.Drawing.Point($X, $Y)
    $lbl.Size      = New-Object System.Drawing.Size($W, 18)
    $lbl.Font      = $fontLabel
    $lbl.ForeColor = $clrAccent
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    return $lbl
}

# ─────────────────────────────────────────────────────────────
#  HELPER: styled text input
# ─────────────────────────────────────────────────────────────
function New-StyledTextBox {
    param([int]$X, [int]$Y, [int]$W, [string]$Placeholder = "")
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location    = New-Object System.Drawing.Point($X, $Y)
    $tb.Size        = New-Object System.Drawing.Size($W, 26)
    $tb.Font        = $fontInput
    $tb.BackColor   = $clrInput
    $tb.ForeColor   = $clrText
    $tb.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    if ($Placeholder) { $tb.Text = $Placeholder }
    return $tb
}

# ─────────────────────────────────────────────────────────────
#  HELPER: log entry
# ─────────────────────────────────────────────────────────────
$script:logFile = ""
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts   = Get-Date -Format "HH:mm:ss"
    $line = "[$ts][$Level] $Message"
    $logBox.AppendText("$line`r`n")
    $logBox.ScrollToCaret()
    if ($script:logFile) { Add-Content $script:logFile $line }
}

# ─────────────────────────────────────────────────────────────
#  HELPER: find free drive letters
# ─────────────────────────────────────────────────────────────
function Get-FreeDriveLetter {
    $used = (Get-PSDrive -PSProvider FileSystem).Name
    foreach ($letter in ([char[]]('Z'..'A'))) {
        if ($used -notcontains $letter) { return $letter }
    }
    return $null
}

# ─────────────────────────────────────────────────────────────
#  HELPER: browse for folder (local or mapped)
# ─────────────────────────────────────────────────────────────
function Browse-Folder {
    param([System.Windows.Forms.TextBox]$Target)
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description         = "Select folder or mapped drive"
    $dlg.ShowNewFolderButton = $true
    $dlg.RootFolder          = [System.Environment+SpecialFolder]::MyComputer
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $Target.Text = $dlg.SelectedPath
    }
}

# ─────────────────────────────────────────────────────────────
#  MAIN FORM
# ─────────────────────────────────────────────────────────────
$form = New-Object System.Windows.Forms.Form
$form.Text            = "CopyToolz"
$form.Size            = New-Object System.Drawing.Size(900, 740)
$form.MinimumSize     = New-Object System.Drawing.Size(900, 740)
$form.StartPosition   = "CenterScreen"
$form.BackColor       = $clrBg
$form.ForeColor       = $clrText
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox     = $false
$form.Icon            = [System.Drawing.SystemIcons]::Application

# ─────────────────────────────────────────────────────────────
#  HEADER PANEL
# ─────────────────────────────────────────────────────────────
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size     = New-Object System.Drawing.Size(900, 72)
$headerPanel.BackColor = $clrPanel

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text      = "  COPYTOOLZ"
$lblTitle.Location  = New-Object System.Drawing.Point(12, 12)
$lblTitle.Size      = New-Object System.Drawing.Size(340, 32)
$lblTitle.Font      = $fontTitle
$lblTitle.ForeColor = $clrAccent
$lblTitle.BackColor = [System.Drawing.Color]::Transparent
$headerPanel.Controls.Add($lblTitle)

$lblAuthor = New-Object System.Windows.Forms.Label
$lblAuthor.Text      = "  by Henchman33  |  Copy · Backup · Move"
$lblAuthor.Location  = New-Object System.Drawing.Point(14, 46)
$lblAuthor.Size      = New-Object System.Drawing.Size(400, 18)
$lblAuthor.Font      = $fontSub
$lblAuthor.ForeColor = $clrMuted
$lblAuthor.BackColor = [System.Drawing.Color]::Transparent
$headerPanel.Controls.Add($lblAuthor)

# Status dot
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text      = "● READY"
$lblStatus.Location  = New-Object System.Drawing.Point(770, 26)
$lblStatus.Size      = New-Object System.Drawing.Size(100, 20)
$lblStatus.Font      = $fontLabel
$lblStatus.ForeColor = $clrAccent
$lblStatus.BackColor = [System.Drawing.Color]::Transparent
$headerPanel.Controls.Add($lblStatus)

$form.Controls.Add($headerPanel)

# ─────────────────────────────────────────────────────────────
#  MAIN CARD PANEL
# ─────────────────────────────────────────────────────────────
$card = New-Object System.Windows.Forms.Panel
$card.Location  = New-Object System.Drawing.Point(16, 84)
$card.Size      = New-Object System.Drawing.Size(862, 250)
$card.BackColor = $clrCard

$form.Controls.Add($card)

# ── SOURCE ──────────────────────────────────────────────────
$lblSrc = New-SectionLabel "SOURCE" 16 16
$card.Controls.Add($lblSrc)

$txtSource = New-StyledTextBox 16 40 700 "\\server\share\folder  or  C:\Path\To\Source"
$card.Controls.Add($txtSource)

$btnBrowseSrc = New-FlatButton "📂 Browse" 724 38 120 28 $clrAccentDim $clrText $fontBtn
$card.Controls.Add($btnBrowseSrc)
$btnBrowseSrc.Add_Click({ Browse-Folder $txtSource })

# ── DESTINATION ─────────────────────────────────────────────
$lblDst = New-SectionLabel "DESTINATION" 16 82
$card.Controls.Add($lblDst)

$txtDest = New-StyledTextBox 16 106 700 "\\server\share\folder  or  D:\Backup"
$card.Controls.Add($txtDest)

$btnBrowseDst = New-FlatButton "📂 Browse" 724 104 120 28 $clrAccentDim $clrText $fontBtn
$card.Controls.Add($btnBrowseDst)
$btnBrowseDst.Add_Click({ Browse-Folder $txtDest })

# ── DIVIDER ──────────────────────────────────────────────────
$divider = New-Object System.Windows.Forms.Label
$divider.Location  = New-Object System.Drawing.Point(16, 146)
$divider.Size      = New-Object System.Drawing.Size(830, 1)
$divider.BackColor = $clrBorder
$card.Controls.Add($divider)

# ── OPERATION MODE ───────────────────────────────────────────
$lblMode = New-SectionLabel "OPERATION MODE" 16 158
$card.Controls.Add($lblMode)

$rbCopy   = New-Object System.Windows.Forms.RadioButton
$rbCopy.Text      = "Copy  (keep originals)"
$rbCopy.Location  = New-Object System.Drawing.Point(16, 180)
$rbCopy.Size      = New-Object System.Drawing.Size(190, 22)
$rbCopy.Checked   = $true
$rbCopy.Font      = $fontSmall
$rbCopy.ForeColor = $clrText
$rbCopy.BackColor = [System.Drawing.Color]::Transparent
$rbCopy.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$card.Controls.Add($rbCopy)

$rbBackup = New-Object System.Windows.Forms.RadioButton
$rbBackup.Text      = "Backup  (timestamped subfolder)"
$rbBackup.Location  = New-Object System.Drawing.Point(210, 180)
$rbBackup.Size      = New-Object System.Drawing.Size(240, 22)
$rbBackup.Font      = $fontSmall
$rbBackup.ForeColor = $clrText
$rbBackup.BackColor = [System.Drawing.Color]::Transparent
$rbBackup.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$card.Controls.Add($rbBackup)

$rbMove   = New-Object System.Windows.Forms.RadioButton
$rbMove.Text      = "Move  (delete originals after)"
$rbMove.Location  = New-Object System.Drawing.Point(460, 180)
$rbMove.Size      = New-Object System.Drawing.Size(240, 22)
$rbMove.Font      = $fontSmall
$rbMove.ForeColor = $clrDanger
$rbMove.BackColor = [System.Drawing.Color]::Transparent
$rbMove.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$card.Controls.Add($rbMove)

# ── DIVIDER 2 ────────────────────────────────────────────────
$div2 = New-Object System.Windows.Forms.Label
$div2.Location  = New-Object System.Drawing.Point(16, 212)
$div2.Size      = New-Object System.Drawing.Size(830, 1)
$div2.BackColor = $clrBorder
$card.Controls.Add($div2)

# ── CREDENTIAL OPTIONS ───────────────────────────────────────
$chkUseCred  = New-StyledCheckBox "Use Network Credentials"     16  222 210
$chkSaveCred = New-StyledCheckBox "Save Credentials"           234  222 160
$chkDisconn  = New-StyledCheckBox "Disconnect Drives After Op" 402  222 230
$card.Controls.Add($chkUseCred)
$card.Controls.Add($chkSaveCred)
$card.Controls.Add($chkDisconn)

$script:cred = $null
$btnSetCred = New-FlatButton "🔑 Set Credentials" 650 218 190 28 $clrBorder $clrText $fontBtn
$btnSetCred.Enabled = $false
$card.Controls.Add($btnSetCred)

$btnSetCred.Add_Click({
    $script:cred = Get-Credential
    if ($script:cred) {
        $btnSetCred.Text      = "✔ Credentials Set"
        $btnSetCred.BackColor = $clrAccentDim
    }
})
$chkUseCred.Add_CheckedChanged({
    $btnSetCred.Enabled = $chkUseCred.Checked
    if (-not $chkUseCred.Checked) {
        $btnSetCred.Text      = "🔑 Set Credentials"
        $btnSetCred.BackColor = $clrBorder
        $script:cred = $null
    }
})

# ─────────────────────────────────────────────────────────────
#  ACTION BAR
# ─────────────────────────────────────────────────────────────
$actionBar = New-Object System.Windows.Forms.Panel
$actionBar.Location  = New-Object System.Drawing.Point(16, 342)
$actionBar.Size      = New-Object System.Drawing.Size(862, 48)
$actionBar.BackColor = $clrPanel
$form.Controls.Add($actionBar)

$btnStart = New-FlatButton "▶  START" 16 8 160 32 $clrAccent ([System.Drawing.Color]::FromArgb(10,10,14)) $fontBtn
$actionBar.Controls.Add($btnStart)

$btnClear = New-FlatButton "✖  Clear Log" 188 8 120 32 $clrBorder $clrText $fontBtn
$actionBar.Controls.Add($btnClear)
$btnClear.Add_Click({ $logBox.Clear() })

$btnOpenLog = New-FlatButton "📄  Open Log Folder" 320 8 160 32 $clrBorder $clrText $fontBtn
$actionBar.Controls.Add($btnOpenLog)
$btnOpenLog.Add_Click({ Start-Process "explorer.exe" -ArgumentList $script:logPath })

# File filter
$lblFilter = New-Object System.Windows.Forms.Label
$lblFilter.Text      = "FILE FILTER:"
$lblFilter.Location  = New-Object System.Drawing.Point(510, 15)
$lblFilter.Size      = New-Object System.Drawing.Size(90, 18)
$lblFilter.Font      = $fontLabel
$lblFilter.ForeColor = $clrMuted
$lblFilter.BackColor = [System.Drawing.Color]::Transparent
$actionBar.Controls.Add($lblFilter)

$txtFilter = New-Object System.Windows.Forms.TextBox
$txtFilter.Location  = New-Object System.Drawing.Point(604, 11)
$txtFilter.Size      = New-Object System.Drawing.Size(240, 26)
$txtFilter.Font      = $fontInput
$txtFilter.BackColor = $clrInput
$txtFilter.ForeColor = $clrText
$txtFilter.Text      = "*.*"
$txtFilter.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$actionBar.Controls.Add($txtFilter)

# ─────────────────────────────────────────────────────────────
#  PROGRESS BAR
# ─────────────────────────────────────────────────────────────
$progressBg = New-Object System.Windows.Forms.Panel
$progressBg.Location  = New-Object System.Drawing.Point(16, 398)
$progressBg.Size      = New-Object System.Drawing.Size(862, 24)
$progressBg.BackColor = $clrBorder
$form.Controls.Add($progressBg)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location  = New-Object System.Drawing.Point(0, 0)
$progressBar.Size      = New-Object System.Drawing.Size(862, 24)
$progressBar.Style     = [System.Windows.Forms.ProgressBarStyle]::Continuous
$progressBar.ForeColor = $clrAccent
$progressBar.BackColor = $clrBorder
$progressBg.Controls.Add($progressBar)

$lblProgress = New-Object System.Windows.Forms.Label
$lblProgress.Location  = New-Object System.Drawing.Point(16, 426)
$lblProgress.Size      = New-Object System.Drawing.Size(862, 18)
$lblProgress.Font      = $fontSmall
$lblProgress.ForeColor = $clrMuted
$lblProgress.BackColor = [System.Drawing.Color]::Transparent
$lblProgress.Text      = "Waiting to start..."
$form.Controls.Add($lblProgress)

# ─────────────────────────────────────────────────────────────
#  LOG BOX
# ─────────────────────────────────────────────────────────────
$lblLog = New-SectionLabel "ACTIVITY LOG" 16 452
$form.Controls.Add($lblLog)

$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location    = New-Object System.Drawing.Point(16, 474)
$logBox.Size        = New-Object System.Drawing.Size(862, 212)
$logBox.Font        = $fontLog
$logBox.BackColor   = $clrInput
$logBox.ForeColor   = $clrText
$logBox.ReadOnly    = $true
$logBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$logBox.ScrollBars  = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
$form.Controls.Add($logBox)

# Footer
$lblFooter = New-Object System.Windows.Forms.Label
$lblFooter.Location  = New-Object System.Drawing.Point(0, 695)
$lblFooter.Size      = New-Object System.Drawing.Size(900, 20)
$lblFooter.Font      = $fontSub
$lblFooter.ForeColor = $clrMuted
$lblFooter.BackColor = $clrPanel
$lblFooter.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblFooter.Text      = "CopyToolz  ·  by Henchman33  ·  Logs saved to: $script:logPath"
$form.Controls.Add($lblFooter)

# ─────────────────────────────────────────────────────────────
#  LOG COLORING HELPER
# ─────────────────────────────────────────────────────────────
function Write-ColorLog {
    param([string]$Message, [string]$Level = "INFO")
    $ts   = Get-Date -Format "HH:mm:ss"
    $line = "[$ts][$Level] $Message"

    $start = $logBox.TextLength
    $logBox.AppendText("$line`n")
    $logBox.Select($start, $line.Length)

    switch ($Level) {
        "OK"    { $logBox.SelectionColor = $clrSuccess }
        "ERROR" { $logBox.SelectionColor = $clrDanger  }
        "WARN"  { $logBox.SelectionColor = [System.Drawing.Color]::FromArgb(240,180,0) }
        "MOVE"  { $logBox.SelectionColor = [System.Drawing.Color]::FromArgb(100,160,255) }
        default { $logBox.SelectionColor = $clrMuted }
    }

    $logBox.SelectionLength = 0
    $logBox.ScrollToCaret()

    if ($script:logFile) { Add-Content $script:logFile $line }
}

# ─────────────────────────────────────────────────────────────
#  DRIVE MAP HELPER
# ─────────────────────────────────────────────────────────────
function Mount-NetworkPath {
    param([string]$UncPath, [System.Management.Automation.PSCredential]$Credential)
    $letter = Get-FreeDriveLetter
    if (-not $letter) { throw "No free drive letters available." }
    $params = @{
        Name       = $letter
        PSProvider = "FileSystem"
        Root       = $UncPath
        Persist    = $true
        ErrorAction = "Stop"
    }
    if ($Credential) { $params.Credential = $Credential }
    New-PSDrive @params | Out-Null
    return "${letter}:\"
}

# ─────────────────────────────────────────────────────────────
#  MAIN OPERATION
# ─────────────────────────────────────────────────────────────
$btnStart.Add_Click({

    $source      = $txtSource.Text.Trim()
    $destination = $txtDest.Text.Trim()
    $filter      = $txtFilter.Text.Trim()
    if (-not $filter) { $filter = "*.*" }

    # Validation
    if (-not $source) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a source path.", "CopyToolz", "OK", "Warning")
        return
    }
    if (-not $destination) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a destination path.", "CopyToolz", "OK", "Warning")
        return
    }

    # Warn on Move
    if ($rbMove.Checked) {
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "MOVE mode will DELETE source files after copying.`nAre you sure?",
            "CopyToolz — Move Warning",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }

    $mounted = @()
    $script:logFile = Join-Path $script:logPath ("CopyToolz_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
    $logBox.Clear()
    $progressBar.Value = 0
    $lblStatus.Text      = "● RUNNING"
    $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(240,180,0)
    $btnStart.Enabled    = $false
    $form.Refresh()

    Write-ColorLog "Operation started" "INFO"
    Write-ColorLog "Source      : $source" "INFO"
    Write-ColorLog "Destination : $destination" "INFO"
    Write-ColorLog "Mode        : $(if ($rbCopy.Checked) {'Copy'} elseif ($rbBackup.Checked) {'Backup'} else {'Move'})" "INFO"
    Write-ColorLog "Filter      : $filter" "INFO"

    # ── Load saved credentials ──────────────────────────────
    if ($chkUseCred.Checked -and -not $script:cred -and (Test-Path $script:credFile)) {
        try {
            $script:cred = Import-Clixml $script:credFile
            Write-ColorLog "Loaded saved credentials from disk." "INFO"
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Could not load saved credentials.`nPlease set them manually.", "CopyToolz", "OK", "Warning")
            $lblStatus.Text = "● READY"; $lblStatus.ForeColor = $clrAccent
            $btnStart.Enabled = $true
            return
        }
    }

    # ── Mount source if UNC ─────────────────────────────────
    if (-not (Test-Path $source)) {
        if ($chkUseCred.Checked) {
            try {
                Write-ColorLog "Mounting source UNC path..." "INFO"
                $source = Mount-NetworkPath $source $script:cred
                $mounted += ($source[0])   # drive letter
                Write-ColorLog "Source mounted as $source" "OK"
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to mount source path.`n$($_.Exception.Message)", "CopyToolz", "OK", "Error")
                $lblStatus.Text = "● ERROR"; $lblStatus.ForeColor = $clrDanger
                $btnStart.Enabled = $true
                return
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("Source path is not accessible.`nEnable credentials or check the path.", "CopyToolz", "OK", "Warning")
            $lblStatus.Text = "● READY"; $lblStatus.ForeColor = $clrAccent
            $btnStart.Enabled = $true
            return
        }
    }

    # ── Backup mode: append timestamp subfolder ─────────────
    if ($rbBackup.Checked) {
        $destination = Join-Path $destination ("Backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
        Write-ColorLog "Backup destination: $destination" "INFO"
    }

    # ── Mount or create destination ─────────────────────────
    if (-not (Test-Path $destination)) {
        if ($destination -like "\\*") {
            if ($chkUseCred.Checked) {
                try {
                    Write-ColorLog "Mounting destination UNC path..." "INFO"
                    $destination = Mount-NetworkPath $destination $script:cred
                    $mounted += ($destination[0])
                    Write-ColorLog "Destination mounted as $destination" "OK"
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to mount destination.`n$($_.Exception.Message)", "CopyToolz", "OK", "Error")
                    $lblStatus.Text = "● ERROR"; $lblStatus.ForeColor = $clrDanger
                    $btnStart.Enabled = $true
                    return
                }
            }
        } else {
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
            Write-ColorLog "Created destination folder: $destination" "INFO"
        }
    }

    # ── Save credentials ────────────────────────────────────
    if ($chkUseCred.Checked -and $chkSaveCred.Checked -and $script:cred) {
        $script:cred | Export-Clixml -Path $script:credFile
        Write-ColorLog "Credentials saved." "INFO"
    }

    # ── Enumerate files ─────────────────────────────────────
    try {
        $files = Get-ChildItem -Path $source -Filter $filter -Recurse -File -ErrorAction Stop
    } catch {
        Write-ColorLog "Failed to enumerate files: $($_.Exception.Message)" "ERROR"
        $lblStatus.Text = "● ERROR"; $lblStatus.ForeColor = $clrDanger
        $btnStart.Enabled = $true
        return
    }

    $total   = $files.Count
    $counter = 0
    $errors  = 0

    if ($total -eq 0) {
        Write-ColorLog "No files matched filter '$filter' in source." "WARN"
    }

    Write-ColorLog "Found $total file(s) to process." "INFO"

    foreach ($file in $files) {
        $relative = $file.FullName.Substring($source.TrimEnd('\').Length).TrimStart('\')
        $destPath = Join-Path $destination $relative
        $destDir  = Split-Path $destPath

        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        try {
            Copy-Item -Path $file.FullName -Destination $destPath -Force -ErrorAction Stop

            if ($rbMove.Checked) {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                Write-ColorLog "Moved : $relative" "MOVE"
            } else {
                Write-ColorLog "OK    : $relative" "OK"
            }
        } catch {
            Write-ColorLog "ERROR : ${relative} — $($_.Exception.Message)" "ERROR"
            $errors++
        }

        $counter++
        $pct = [math]::Min(100, [math]::Round(($counter / $total) * 100))
        $progressBar.Value    = $pct
        $lblProgress.Text     = "$counter / $total files  ($pct%)  ·  Errors: $errors"
        $form.Refresh()
    }

    # ── Disconnect drives ───────────────────────────────────
    if ($chkDisconn.Checked -and $mounted.Count -gt 0) {
        foreach ($d in $mounted) {
            Remove-PSDrive -Name $d -Force -ErrorAction SilentlyContinue
            Write-ColorLog "Disconnected drive $d" "INFO"
        }
    }

    # ── Done ────────────────────────────────────────────────
    $lblStatus.Text      = if ($errors -gt 0) { "● DONE (errors)" } else { "● DONE" }
    $lblStatus.ForeColor = if ($errors -gt 0) { $clrDanger } else { $clrSuccess }
    $btnStart.Enabled    = $true

    $summary = "Processed: $counter / $total`nErrors: $errors`nLog: $($script:logFile)"
    $icon    = if ($errors -gt 0) { [System.Windows.Forms.MessageBoxIcon]::Warning } else { [System.Windows.Forms.MessageBoxIcon]::Information }
    [System.Windows.Forms.MessageBox]::Show($summary, "CopyToolz — Complete", "OK", $icon)

    $lblProgress.Text = "Last run: $counter files, $errors errors. Log at: $($script:logFile)"})

# ─────────────────────────────────────────────────────────────
#  LAUNCH
# ─────────────────────────────────────────────────────────────
[void]$form.ShowDialog()
