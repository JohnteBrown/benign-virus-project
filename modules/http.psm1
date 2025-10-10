function Invoke-RemoteScript {
    param (
        [Parameter(Mandatory)]
        [string]$Uri
    )

    try {
        $scriptContent = Invoke-WebRequest -Uri $Uri -UseBasicParsing | Select-Object -ExpandProperty Content
        Invoke-Expression $scriptContent
    } catch {
        Write-Error "Failed to download or execute script: $_"
    }
}