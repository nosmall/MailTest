# mailtest

## Description

`mailtest` is a simple application for testing SMTP connections and authentication. It consists of a PowerShell script (`libmailtest.ps1`) and a configuration file (`.mailtest`). The script connects to the specified SMTP server and performs authentication. The results of each run are logged to the `log.txt` file. The application also supports sending notifications to Uptime Kuma.

## Usage

1.  **Configuration:** Edit the `.mailtest` file and set the parameters for your SMTP connection (server, port, username, password, sender, recipient, etc.). An example configuration file can be found in [.mailtest.example](.mailtest.example).
2.  **Running:** Run the application using the batch file `mailtest.bat`.
    ```bash
    .\mailtest.bat
    ```
3.  **Logging:** The results of each run can be found in the `log.txt` file.

## Compatibility

The application has been tested on the Windows 11 operating system.

## Files

-   `libmailtest.ps1`: The main PowerShell script.
-   `.mailtest`: The configuration file.
-   `mailtest.bat`: Batch file for running the script.
-   `log.txt`: Log file.
-   `.mailtest.example`: Example configuration file.
-   `README.md`: This documentation.
