function Get-EmbeddedResource
{
	param (
		[string]$ResourceName
	)
	# Get the current assembly
	$asm = [Reflection.Assembly]::GetExecutingAssembly()
	
	# Resource names are often full namespace + filename - list them to find yours:
	# $asm.GetManifestResourceNames() | ForEach-Object { Write-Output $_ }
	
	$stream = $asm.GetManifestResourceStream($ResourceName)
	if (-not $stream)
	{
		throw "Resource '$ResourceName' not found"
	}
	
	$tempFile = [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetRandomFileName())
	$fileStream = [IO.File]::OpenWrite($tempFile)
	try
	{
		$stream.CopyTo($fileStream)
	}
	finally
	{
		$fileStream.Close()
		$stream.Close()
	}
	return $tempFile
}
