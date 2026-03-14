# ==========================================
# CopyToolz Enterprise Pro
# Author: Henchman33
# ==========================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Management.Automation

# =============================
# PATH SETUP (EXE SAFE)
# =============================

$basePath = [System.AppDomain]::CurrentDomain.BaseDirectory
$configPath = Join-Path $basePath "config"
$logPath = Join-Path $basePath "logs"
$favFile = Join-Path $configPath "favorites.json"
$appLog = Join-Path $logPath "CopyToolz_App.log"
$credFile = Join-Path $configPath "credentials.xml"

foreach($p in @($configPath,$logPath)){
    if(!(Test-Path $p)){ New-Item $p -ItemType Directory | Out-Null }
}

# =============================
# LOGGING
# =============================

function Write-AppLog{
    param($msg)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $msg"
    Add-Content $appLog $line
}

# =============================
# FAVORITES
# =============================

function Load-Favorites{
    if(Test-Path $favFile){
        try { return Get-Content $favFile | ConvertFrom-Json } catch { return @() }
    }
    return @()
}
function Save-Favorites($list){ $list | ConvertTo-Json | Set-Content $favFile }

$favorites = Load-Favorites

# =============================
# FORM
# =============================

$form = New-Object Windows.Forms.Form
$form.Text = "CopyToolz Enterprise Pro | Author: Henchman33"
$form.Size = "1050,760"
$form.StartPosition = "CenterScreen"
$form.BackColor = "#2d2d30"
$form.ForeColor = "White"
$form.Font = "Segoe UI,10"

# =============================
# FUNCTIONS
# =============================

function Write-Log{
    param($msg)
    $logBox.AppendText("$msg`r`n")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
}

function Browse-Folder{
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if($dialog.ShowDialog() -eq "OK"){ return $dialog.SelectedPath }
}

function Get-FolderSize{
    param($path)
    try{ return (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | Measure Length -Sum).Sum } catch{ return 0 }
}

# =============================
# SOURCE & DESTINATION INPUTS
# =============================

$lblSource = New-Object Windows.Forms.Label
$lblSource.Text="Source"
$lblSource.Location="20,20"
$form.Controls.Add($lblSource)

$textSource = New-Object Windows.Forms.TextBox
$textSource.Location="20,45"
$textSource.Size="700,25"
$form.Controls.Add($textSource)

$btnSrc = New-Object Windows.Forms.Button
$btnSrc.Text="Browse"
$btnSrc.Location="730,43"
$form.Controls.Add($btnSrc)
$btnSrc.Add_Click({$p=Browse-Folder;if($p){$textSource.Text=$p}})

$lblDest = New-Object Windows.Forms.Label
$lblDest.Text="Destination"
$lblDest.Location="20,85"
$form.Controls.Add($lblDest)

$textDest = New-Object Windows.Forms.TextBox
$textDest.Location="20,110"
$textDest.Size="700,25"
$form.Controls.Add($textDest)

$btnDst = New-Object Windows.Forms.Button
$btnDst.Text="Browse"
$btnDst.Location="730,108"
$form.Controls.Add($btnDst)
$btnDst.Add_Click({$p=Browse-Folder;if($p){$textDest.Text=$p}})

# =============================
# CREDENTIALS SUPPORT
# =============================

$chkCred = New-Object Windows.Forms.CheckBox
$chkCred.Text="Use Network Credentials"
$chkCred.Location="20,150"
$form.Controls.Add($chkCred)

$btnCred = New-Object Windows.Forms.Button
$btnCred.Text="Set Credentials"
$btnCred.Location="200,145"
$btnCred.Enabled=$false
$form.Controls.Add($btnCred)

$cred = $null
$btnCred.Add_Click({ $cred = Get-Credential; $btnCred.Text="✔️ Set" })
$chkCred.Add_CheckedChanged({ $btnCred.Enabled=$chkCred.Checked })

# =============================
# FAVORITES BUTTON
# =============================

$btnAddFav = New-Object Windows.Forms.Button
$btnAddFav.Text="Add to Favorites"
$btnAddFav.Location="350,145"
$form.Controls.Add($btnAddFav)

$btnAddFav.Add_Click({
    if($textSource.Text){
        $favorites+=$textSource.Text
        Save-Favorites $favorites
        [Windows.Forms.MessageBox]::Show("Favorite Saved!")
    }
})

# =============================
# PROGRESS BAR + SPEED/ETA
# =============================

$progressBar = New-Object Windows.Forms.ProgressBar
$progressBar.Location="20,190"
$progressBar.Size="1010,25"
$form.Controls.Add($progressBar)

$lblSpeed = New-Object Windows.Forms.Label
$lblSpeed.Location="20,220"
$lblSpeed.Text="Speed: waiting"
$form.Controls.Add($lblSpeed)

$lblETA = New-Object Windows.Forms.Label
$lblETA.Location="250,220"
$lblETA.Text="ETA: waiting"
$form.Controls.Add($lblETA)

# =============================
# LOG BOX
# =============================

$logBox = New-Object Windows.Forms.TextBox
$logBox.Location="20,250"
$logBox.Size="1010,460"
$logBox.Multiline=$true
$logBox.ScrollBars="Vertical"
$logBox.ReadOnly=$true
$logBox.BackColor="#1e1e1e"
$logBox.ForeColor="LightGreen"
$form.Controls.Add($logBox)

# =============================
# START / PAUSE / RESUME BUTTONS
# =============================

$btnStart = New-Object Windows.Forms.Button
$btnStart.Text="Start Copy"
$btnStart.Location="420,720"
$btnStart.Size="120,30"
$form.Controls.Add($btnStart)

$btnPause = New-Object Windows.Forms.Button
$btnPause.Text="Pause"
$btnPause.Location="550,720"
$form.Controls.Add($btnPause)

$btnResume = New-Object Windows.Forms.Button
$btnResume.Text="Resume"
$btnResume.Location="650,720"
$form.Controls.Add($btnResume)

# =============================
# COPY ENGINE
# =============================

$global:proc = $null

$btnStart.Add_Click({

$src=$textSource.Text
$dst=$textDest.Text

if(!$src -or !$dst){
[Windows.Forms.MessageBox]::Show("Source and Destination required")
return
}

# Map UNC if credentials are set
$mounted = @()
if($chkCred.Checked -and $cred){
    try{
        New-PSDrive -Name "Z" -PSProvider FileSystem -Root $src -Credential $cred -Persist -ErrorAction Stop | Out-Null
        $src="Z:\"
        $mounted += "Z"
        New-PSDrive -Name "Y" -PSProvider FileSystem -Root $dst -Credential $cred -Persist -ErrorAction Stop | Out-Null
        $dst="Y:\"
        $mounted += "Y"
    } catch{
        [Windows.Forms.MessageBox]::Show("Failed to map network drive: $($_.Exception.Message)")
        return
    }
}

$totalSize=Get-FolderSize $src
$startTime=Get-Date
$copyLog=Join-Path $logPath ("Copy_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

$args=@("`"$src`"","`"$dst`"","/E","/MT:32","/R:2","/W:2","/TEE","/LOG:`"$copyLog`"")

$psi = New-Object Diagnostics.ProcessStartInfo
$psi.FileName="robocopy.exe"
$psi.Arguments=$args -join " "
$psi.RedirectStandardOutput=$true
$psi.UseShellExecute=$false
$psi.CreateNoWindow=$true

$proc = New-Object Diagnostics.Process
$proc.StartInfo=$psi
$proc.Start()|Out-Null
$global:proc=$proc

Write-AppLog "Copy started $src -> $dst"
Write-Log "Starting copy..."

while(!$proc.HasExited){
$line=$proc.StandardOutput.ReadLine()
if($line){ Write-Log $line }

$elapsed=(Get-Date)-$startTime
if($elapsed.TotalSeconds -gt 0 -and $totalSize -gt 0){
$destSize=Get-FolderSize $dst
$percent=($destSize/$totalSize)*100
$progressBar.Value=[math]::Min([int]$percent,100)

$rate=$destSize/$elapsed.TotalSeconds
if($rate -gt 0){
$remaining=($totalSize-$destSize)/$rate
$eta=[TimeSpan]::FromSeconds($remaining)
$lblETA.Text="ETA: $eta"
$lblSpeed.Text="Speed: $([math]::Round($rate/1MB,2)) MB/s"
}
}

[System.Windows.Forms.Application]::DoEvents()
}

# Disconnect drives if mapped
foreach($d in $mounted){ Remove-PSDrive -Name $d -Force }

Write-Log "Copy completed"
Write-AppLog "Copy completed"

})

# Pause / Resume
$btnPause.Add_Click({ if($global:proc){Suspend-Process $global:proc.Id; Write-Log "Paused"}})
$btnResume.Add_Click({ if($global:proc){Resume-Process $global:proc.Id; Write-Log "Resumed"}})

Write-AppLog "CopyToolz Enterprise Pro Launched"

[void]$form.ShowDialog()