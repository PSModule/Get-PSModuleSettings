#Requires -Modules GitHub

[CmdletBinding()]
param(
    [Parameter()]
    [string] $Subject = $env:PSMOUDLE_TEMPLATE_ACTION_INPUT_Subject
)

begin {
    $scriptName = $MyInvocation.MyCommand.Name
    Write-Debug "[$scriptName] - Start"
}

process {
    try {
        Write-Output "Hello, $Subject!"
    } catch {
        throw $_
    }
}

end {
    Write-Debug "[$scriptName] - End"
}
