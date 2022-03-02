Function Write-LogAnalytics
{
    [CmdletBinding(
		SupportsShouldProcess=$True,
		ConfirmImpact="Low"
	)]
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]$WorkspaceID,
        [Parameter(Mandatory=$true)]
        [String]$SharedKey,
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$True)]
        [PSObject]$Content,
        [String]$LogType = "CustomLog"
    )

    Begin {}

    Process
    {
        $Body = $Content | ConvertTo-Json

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
            "Log-Type" = $LogType
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
