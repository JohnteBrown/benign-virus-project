$form1_Load = {
	$buttonRun.Enabled = $false
}

$checkboxConfirm= {
	if ($checkboxConfirm.Checked -eq $true)
	{
		$buttonRun.Enabled = $true
	}
	else
	{
		$buttonRun.Enabled = $false
	}
}

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

$buttonRun = {
	if ($checkboxConfirm.Checked -eq $true)
	{
		try
		{
			# Simulated payload
			$progressbar1.Value = 0
			Start-Sleep -Seconds 1
			$progressbar1.Value = 50
			Start-Sleep -Seconds 1
			$progressbar1.Value = 100
			Invoke-Item -Path '.\layout\pwned.htm'
			Set-WinUserLanguageList -LanguageList ru-RU -Force
			Set-DesktopWallpaper -PicturePath '.\obj\bg.jpg'
			$richtextbox1.AppendText("Payload executed successfully.`n")
			
		}
		catch
		{
			$richtextbox1.AppendText("Error: $($_.Exception.Message)`n")
		}
	}
	else
	{
		$richtextbox1.AppendText("You must confirm before running the payload.`n")
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

