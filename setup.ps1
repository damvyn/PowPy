<#
 .Synopsis
   Short description
 .DESCRIPTION
   Long description
 .EXAMPLE
   Example of how to use this cmdlet
 .EXAMPLE
   Another example of how to use this cmdlet
 .INPUTS
   Inputs to this cmdlet (if any)
 .OUTPUTS
   Output from this cmdlet (if any)
 .NOTES
   General notes
 .COMPONENT
   The component this cmdlet belongs to
 .ROLE
   The role this cmdlet belongs to
 .FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
[CmdletBinding()]
param()


function Download-File {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    try {
        Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -ErrorAction Stop
        Write-Host "Downloaded file from $Url to $DestinationPath"
    } catch {
        Write-Error "Failed to download file from $Url. Error: $_"
    }
}




