# Version: 2.1.0
# MAJOR.MINUR.PATCH
param (
    [string]$SmtpServer = "smtp.seznam.cz",
    [int]$SmtpPort = 587,
    [string]$SmtpUsername = "smtp.relay@domain.tld",
    [string]$SmtpPassword = "strongAppPassword",
    [string]$EmailFromAddress = "smtp.relay@domain.tld",
    [bool]$UseSsl = $true,
    [string]$UptimeKumaPushUrl = "https://uptime.kuma.tld/api/push/9pffsbbnkJ"
)

$logFile = "log.txt"
$configFile = ".mailtest"

# Load configuration from file if it exists
if (Test-Path $configFile) {
    Write-Host "Loading configuration from $configFile..."
    $config = Get-Content $configFile | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '=' } | ForEach-Object {
        $key, $value = $_.Split('=', 2)
        @{ Name = $key.Trim(); Value = $value.Trim() }
    }

    foreach ($item in $config) {
        switch ($item.Name) {
            "SmtpServer"       { if ($PSBoundParameters['SmtpServer'] -eq $null) { $SmtpServer = $item.Value } }
            "SmtpPort"         { if ($PSBoundParameters['SmtpPort'] -eq $null) { $SmtpPort = [int]$item.Value } }
            "SmtpUsername"     { if ($PSBoundParameters['SmtpUsername'] -eq $null) { $SmtpUsername = $item.Value } }
            "SmtpPassword"     { if ($PSBoundParameters['SmtpPassword'] -eq $null) { $SmtpPassword = $item.Value } }
            "EmailFromAddress" { if ($PSBoundParameters['EmailFromAddress'] -eq $null) { $EmailFromAddress = $item.Value } }
            "UseSsl"           { if ($PSBoundParameters['UseSsl'] -eq $null) { $UseSsl = [System.Convert]::ToBoolean($item.Value) } }
            "UptimeKumaPushUrl"{ if ($PSBoundParameters['UptimeKumaPushUrl'] -eq $null) { $UptimeKumaPushUrl = $item.Value } }
        }
    }
} else {
    Write-Host "Configuration file $configFile not found. Using default or command-line parameters."
}

try {
    Write-Host "Attempting to connect to SMTP server: $SmtpServer on port $SmtpPort..."

    $TcpClient = New-Object System.Net.Sockets.TcpClient
    Write-Host "Establishing TCP connection to server $SmtpServer on port $SmtpPort..."
    $TcpClient.Connect($SmtpServer, $SmtpPort)

    if ($TcpClient.Connected) {
        Write-Host "TCP connection established successfully."
        $Stream = $TcpClient.GetStream()
        $Reader = New-Object System.IO.StreamReader($Stream)
        $Writer = New-Object System.IO.StreamWriter($Stream)
        $Writer.AutoFlush = $true

        # Read server's welcome message (220)
        $Response = $Reader.ReadLine()
        Write-Host "SERVER: $Response"
        if (-not $Response.StartsWith("220")) {
            throw "Server did not return the expected welcome message (220)."
        }

        # EHLO
        $Hostname = [System.Net.Dns]::GetHostName()
        Write-Host "CLIENT: EHLO $Hostname"
        $Writer.WriteLine("EHLO $Hostname")
        $Response = ""
        # Server může odpovědět více řádky, poslední řádek odpovědi začíná kódem a mezerou
        while (($line = $Reader.ReadLine()) -and ($line -notmatch "^\d{3} ")) { $Response += "$line`r`n" }
        $Response += $line
        Write-Host "SERVER: $Response"
        if (-not $Response.StartsWith("250")) {
            throw "EHLO command failed."
        }

        if ($UseSsl) {
            Write-Host "CLIENT: STARTTLS"
            $Writer.WriteLine("STARTTLS")
            $Response = $Reader.ReadLine()
            Write-Host "SERVER: $Response"
            if (-not $Response.StartsWith("220")) {
                throw "STARTTLS command failed."
            }

            # Upgrade to SSL
            $SslStream = New-Object System.Net.Security.SslStream($Stream, $false)
            # Server certificate validation (may need adjustment for self-signed certificates)
            $SslStream.AuthenticateAsClient($SmtpServer)
            $Reader = New-Object System.IO.StreamReader($SslStream)
            $Writer = New-Object System.IO.StreamWriter($SslStream)
            $Writer.AutoFlush = $true

            # Znovu EHLO přes SSL
            Write-Host "CLIENT (SSL): EHLO $Hostname"
            $Writer.WriteLine("EHLO $Hostname")
            $Response = ""
            while (($line = $Reader.ReadLine()) -and ($line -notmatch "^\d{3} ")) { $Response += "$line`r`n" }
            $Response += $line
            Write-Host "SERVER (SSL): $Response"
            if (-not $Response.StartsWith("250")) {
                throw "EHLO command (SSL) failed."
            }
        }
        
        # AUTH LOGIN
        # Check if server offers AUTH LOGIN
        if ($Response -notmatch "AUTH LOGIN") {
            throw "Server does not offer AUTH LOGIN method."
        }
        Write-Host "CLIENT: AUTH LOGIN"
        $Writer.WriteLine("AUTH LOGIN")
        $Response = $Reader.ReadLine()
        Write-Host "SERVER: $Response"
        if (-not $Response.StartsWith("334")) { # 334 VXNlcm5hbWU6
            throw "Server did not ask for username (AUTH LOGIN)."
        }

        # Send username (Base64)
        $UsernameBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($SmtpUsername))
        Write-Host "CLIENT: $UsernameBase64" # For debugging, consider not displaying in production
        $Writer.WriteLine($UsernameBase64)
        $Response = $Reader.ReadLine()
        Write-Host "SERVER: $Response"
        if (-not $Response.StartsWith("334")) { # 334 UGFzc3dvcmQ6
            throw "Server did not ask for password."
        }

        # Send password (Base64)
        $PasswordBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($SmtpPassword))
        Write-Host "CLIENT: ***PASSWORD (Base64)***" # Do not display password in log
        $Writer.WriteLine($PasswordBase64)
        $Response = $Reader.ReadLine()
        Write-Host "SERVER: $Response"
        if (-not $Response.StartsWith("235")) { # 235 Authentication successful
            throw "Authentication failed: $Response"
        }

        Write-Host "SMTP authentication successful."

        # QUIT
        Write-Host "CLIENT: QUIT"
        $Writer.WriteLine("QUIT")
        $Response = $Reader.ReadLine()
        Write-Host "SERVER: $Response"

        $TcpClient.Close()
        Write-Host "Connection to SMTP server was successfully verified and closed."
        Write-Host "SMTP Server: $SmtpServer"
        Write-Host "Port: $SmtpPort"
        Write-Host "SSL/TLS: $UseSsl"
        Write-Host "User: $SmtpUsername"
        Write-Host "Sender Email: $EmailFromAddress"
        Write-Host "Status: SUCCESSFUL CONNECTION AND AUTHENTICATION"
        # Log success
        "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - SUCCESS - Server: $SmtpServer Port: $SmtpPort" | Add-Content -Path $logFile
        # No Uptime Kuma notification on success, as per user request

    # Send UP notification to Uptime Kuma
    if (-not [string]::IsNullOrEmpty($UptimeKumaPushUrl)) {
        # Construct the message for Uptime Kuma
        $serviceName = "SMTP Test ($($SmtpServer):$($SmtpPort) - $($SmtpUsername))"
        $successMsg = "$serviceName - SUCCESS"
        # Use [uri]::EscapeDataString for URL encoding
        $encodedSuccessMsg = [uri]::EscapeDataString($successMsg)
        $pushUrlSuccess = "$UptimeKumaPushUrl`?status=up&msg=$encodedSuccessMsg"
        try {
            Write-Host "Sending UP notification to Uptime Kuma (using WebClient): $pushUrlSuccess"
            $WebClient = New-Object System.Net.WebClient
            $WebClient.DownloadString($pushUrlSuccess) | Out-Null
            $WebClient.Dispose()
        } catch {
            Write-Warning "Failed to send UP notification to Uptime Kuma (using WebClient): $($_.Exception.Message)"
        }
    }
        exit 0

    } else {
        throw "Failed to establish TCP connection."
    }

} catch {
    $errorMessage = $_.Exception.Message
    # Get only the first line of the error message for brevity in Uptime Kuma
    $shortErrorMessage = ($errorMessage -split "`r`n?|\n")[0]
    
    Write-Error "An error occurred while testing SMTP connection: $errorMessage"
    Write-Host "ERROR DETAILS: $($_.Exception.ToString())" # Full error detail still in console output
    Write-Host "Status: FAILED"
    # Log failure
    "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - FAILED - Server: $SmtpServer Port: $SmtpPort - Error: $shortErrorMessage" | Add-Content -Path $logFile

    # Send DOWN notification to Uptime Kuma
    if (-not [string]::IsNullOrEmpty($UptimeKumaPushUrl)) {
        # Construct the message for Uptime Kuma
        $serviceName = "SMTP Test ($($SmtpServer):$($SmtpPort) - $($SmtpUsername))"
        $failureMsg = "$serviceName - FAILED: $shortErrorMessage"
        # Use [uri]::EscapeDataString for URL encoding
        $encodedFailureMsg = [uri]::EscapeDataString($failureMsg)
        
        $pushUrlFailure = "$UptimeKumaPushUrl`?status=down&msg=$encodedFailureMsg"
        try {
            Write-Host "Sending DOWN notification to Uptime Kuma (using WebClient): $pushUrlFailure"
            $WebClient = New-Object System.Net.WebClient
            # Set a timeout for the WebClient operation (in milliseconds)
            # WebClient doesn't have a direct TimeoutSec like Invoke-WebRequest.
            # This requires a custom approach or relying on default system timeouts.
            # For simplicity here, we'll proceed without a custom timeout for DownloadString.
            # Consider a more robust solution if timeouts are critical for WebClient.
            $WebClient.DownloadString($pushUrlFailure) | Out-Null
            $WebClient.Dispose()
        } catch {
            Write-Warning "Failed to send DOWN notification to Uptime Kuma (using WebClient): $($_.Exception.Message)"
        }
    }

    if ($TcpClient -and $TcpClient.Connected) {
        $TcpClient.Close()
    }
    # Exit script with error code for potential automated processing
    exit 1
}
