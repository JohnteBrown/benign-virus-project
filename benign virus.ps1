<# 
	---------------------------- DISCLAIMER ------------------------------
	This script is for educational purposes only and is part of a 
	cybersecurity training project developed by students at the Ohio Mahoning 
	County Career and Technical Center (MCCTC). It is **NOT** a real virus or 
	malware, and it does not cause permanent damage to your system.
	
	The script simulates a set of actions commonly seen in cyberattacks, such as 
	changing system settings and wallpapers, and modifying user language preferences. 
	These actions are meant solely for learning and demonstration purposes in a safe, 
	controlled environment (e.g., virtual machines, labs).
	
	**Important**: This script should **NOT** be executed on any system without explicit 
	permission from the system owner. Unauthorized use may be unethical and could 
	violate laws, such as the Computer Fraud and Abuse Act (CFAA) of 1986.
	
	By running this script, you acknowledge that you are using it in a **safe and 
	controlled environment** and agree to take full responsibility for its execution.
	
	Please use responsibly and ethically.
	----------------------------------------------------------------------
	#>

function Show-benign_v_psf
{
	[void][reflection.assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
	[void][reflection.assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
	
	[System.Windows.Forms.Application]::EnableVisualStyles()
	$form1 = New-Object 'System.Windows.Forms.Form'
	$buttonRun = New-Object 'System.Windows.Forms.Button'
	$checkboxYesIWantToDetonateTh = New-Object 'System.Windows.Forms.CheckBox'
	$richtextbox1 = New-Object 'System.Windows.Forms.RichTextBox'
	$progressbar1 = New-Object 'System.Windows.Forms.ProgressBar'
	$timer1 = New-Object 'System.Windows.Forms.Timer'
	
	# UI setup
	$form1.ClientSize = New-Object System.Drawing.Size(407, 378)
	$form1.Text = 'Form'
	
	$buttonRun.Location = New-Object System.Drawing.Point(157, 149)
	$buttonRun.Size = New-Object System.Drawing.Size(75, 23)
	$buttonRun.Text = 'Run'
	$buttonRun.Enabled = $false
	
	$checkboxYesIWantToDetonateTh.Location = New-Object System.Drawing.Point(67, 344)
	$checkboxYesIWantToDetonateTh.Size = New-Object System.Drawing.Size(300, 24)
	$checkboxYesIWantToDetonateTh.Text = 'Yes I want to detonate the payload'
	
	$richtextbox1.Location = New-Object System.Drawing.Point(67, 208)
	$richtextbox1.Size = New-Object System.Drawing.Size(272, 129)
	$richtextbox1.ReadOnly = $true
	
	$progressbar1.Location = New-Object System.Drawing.Point(67, 178)
	$progressbar1.Size = New-Object System.Drawing.Size(272, 23)
	$progressbar1.Minimum = 0
	$progressbar1.Maximum = 100
	$progressbar1.Value = 0
	
	$form1.Controls.AddRange(@($buttonRun, $checkboxYesIWantToDetonateTh, $richtextbox1, $progressbar1))
	
	# Non-blocking timer configuration (simulate progress)
	$timer1.Interval = 200 # ms
	$timer1.Tag = @{ Step = 0 } # state holder
	$timer1.Add_Tick({
			$state = $timer1.Tag
			$state.Step += 1
			$progressbar1.Value = [Math]::Min(100, $state.Step * 10)
			if ($progressbar1.Value -ge 100)
			{
				$timer1.Stop()
				$richtextbox1.AppendText("Payload executed successfully (SIMULATED).`n")
				# If you really need to run heavy real work, do it in a background job and marshal results back:
				# Start-Job { ... } | Receive-Job -Wait
			}
			$timer1.Tag = $state
		})
	
	# Event handlers (correct control references)
	$checkboxYesIWantToDetonateTh.Add_CheckedChanged({
			$buttonRun.Enabled = $checkboxYesIWantToDetonateTh.Checked
		})
	
	$buttonRun.Add_Click({
			if ($checkboxYesIWantToDetonateTh.Checked)
			{
				# Disable UI while 'running'
				$buttonRun.Enabled = $false
				$checkboxYesIWantToDetonateTh.Enabled = $false
				$progressbar1.Value = 0
				$timer1.Tag = @{ Step = 0 }
				$timer1.Start()
				
				# --- DANGEROUS stuff removed while debugging ---
				# Invoke-Item -Path '.\layout\pwned.htm'
				# Set-WinUserLanguageList -LanguageList ru-RU -Force
				# Set-DesktopWallpaper -PicturePath '.\obj\bg.jpg'
				# --------------------------------------------------
			}
			else
			{
				$richtextbox1.AppendText("You must confirm before running the payload.`n")
			}
		})
	
	# Show form
	$form1.Add_Shown({ $buttonRun.Enabled = $false })
	$form1.ShowDialog() | Out-Null
}

# Call the form
Show-benign_v_psf

$form1_Load = {
	#TODO: Place custom script here
	
}

function Invoke-RemoteScript
{
	param (
		[Parameter(Mandatory)]
		[string]$Uri
	)
	
	try
	{
		$scriptContent = Invoke-WebRequest -Uri $Uri -UseBasicParsing | Select-Object -ExpandProperty Content
		Invoke-Expression $scriptContent
	}
	catch
	{
		Write-Error "Failed to download or execute script: $_"
	}
}

function Set-DesktopWallpaper
{
    <#
    .DESCRIPTION
        Sets a desktop background image.
    .PARAMETER PicturePath
        Defines the path to the picture to use for background.
    .PARAMETER Style
        Defines the style of the wallpaper. Valid values are, Tiled, Centered, Stretched, Fill, Fit, Span.
    .EXAMPLE
        Set-DesktopWallpaper -PicturePath "C:\pictures\picture1.jpg" -Style Fill
    .EXAMPLE
        Set-DesktopWallpaper -PicturePath "C:\pictures\picture2.png" -Style Centered
    .NOTES
        Supports jpg, png and bmp files.
    #>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[String]$PicturePath,
		[ValidateSet('Tiled', 'Centered', 'Stretched', 'Fill', 'Fit', 'Span')]
		$Style = 'Fill'
	)
	BEGIN
	{
		$Definition = @"
[DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
"@
		Add-Type -MemberDefinition $Definition -Name Win32SystemParametersInfo -Namespace Win32Functions
		$Action_SetDeskWallpaper = [int]20
		$Action_UpdateIniFile = [int]0x01
		$Action_SendWinIniChangeEvent = [int]0x02
		$HT_WallPaperStyle = @{
			'Tiled'	    = 0
			'Centered'  = 0
			'Stretched' = 2
			'Fill'	    = 10
			'Fit'	    = 6
			'Span'	    = 22
		}
		$HT_TileWallPaper = @{
			'Tiled'	    = 1
			'Centered'  = 0
			'Stretched' = 0
			'Fill'	    = 0
			'Fit'	    = 0
			'Span'	    = 0
		}
	}
	PROCESS
	{
		Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name wallpaperstyle -Value $HT_WallPaperStyle[$Style]
		Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name tilewallpaper -Value $HT_TileWallPaper[$Style]
		$null = [Win32Functions.Win32SystemParametersInfo]::SystemParametersInfo($Action_SetDeskWallpaper, 0, $PicturePath, ($Action_UpdateIniFile -bor $Action_SendWinIniChangeEvent))
	}
}

