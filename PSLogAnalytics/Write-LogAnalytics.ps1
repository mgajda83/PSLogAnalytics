Function Write-LogAnalytics
{
<#
	.SYNOPSIS
	    Write object to LogAnalytics workspace.

	.PARAMETER WorkspaceID
	    WorkspaceID of LogAnalytics workspace.

	.PARAMETER SharedKey
	    SharedKey of LogAnalytics workspace.

	.PARAMETER Object
	    PowerShell object to write to LogAnalytics workspace

	.PARAMETER Table
	    Custom table name in LogAnalytics workspace.

	.EXAMPLE
		$WorkspaceID = "<GUID WorkspaceID>"
        $SharedKey = "<SharedKey>"
        $Object = [PSCustomObject]@{
            Requester    = $env:USERNAME
            ComputerName = $env:COMPUTERNAME
            Id           = (New-Guid).Guid
            Message      = "Custom Message"
        }

        $Log = @{
            WorkspaceID = $WorkspaceID
            SharedKey = $SharedKey
            Object = $Object
            Table = "CustomLog"
        }
        Write-LogAnalytics @Log

	.NOTES
		Author: Michal Gajda
	#>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]$WorkspaceID,
        [Parameter(Mandatory=$true)]
        [String]$SharedKey,
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$True)]
        [PSObject]$Object,
        [String]$Table = "CustomLog"
    )

    Begin {}

    Process
    {
        $Body = $Object | ConvertTo-Json

        #Sign params
        $Method = "POST"
        $ContentType = "application/json"
        $ContentLength = $Body.Length
        $SignDate = [DateTime]::UtcNow.ToString("r")
        $xHeaders = "x-ms-date:" + $SignDate
        $APIResource = "/api/logs"

        #String to Sign
        $StringToSign = $Method + "`n" + $ContentLength + "`n" + $ContentType + "`n" + $xHeaders + "`n" + $APIResource
        $BytesToHash = [Text.Encoding]::UTF8.GetBytes($StringToSign)
        $KeyBytes = [Convert]::FromBase64String($SharedKey)
        $HMACSHA256 = New-Object System.Security.Cryptography.HMACSHA256
        $HMACSHA256.Key = $KeyBytes
        $CalculatedHash = $HMACSHA256.ComputeHash($BytesToHash)
        $EncodedHash = [Convert]::ToBase64String($CalculatedHash)
        $Authorization = 'SharedKey {0}:{1}' -f $WorkspaceID, $EncodedHash

        #Request params
        $Uri = "https://" + $WorkspaceID + ".ods.opinsights.azure.com" + $APIResource + "?api-version=2016-04-01"
        $Headers = @{
            "Authorization" = $Authorization
            "Log-Type" = $Table
            "x-ms-date" = $SignDate
            "time-generated-field" = $(Get-Date)
        }

        $Request = @{
            Uri = $Uri
            Method = $Method
            ContentType = "application/json"
            Headers = $Headers
            Body = $Body
            UseBasicParsing = $true
        }

        #Send request
        $Response = Invoke-WebRequest @Request

        if ($Response.StatusCode -eq 200)
        {
            Write-Information -MessageData "Event was write to Log Analytics Workspace" -InformationAction Continue
        }
    }

    End {}
}
