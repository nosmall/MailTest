# mailtest

## Popis

`mailtest` je jednoduchá aplikace pro testování SMTP spojení a autentizace. Skládá se z PowerShell skriptu (`libmailtest.ps1`) a konfiguračního souboru (`.mailtest`). Skript se připojí k zadanému SMTP serveru, provede autentizaci. Výsledky každého spuštění jsou logovány do souboru `log.txt`. Aplikace také podporuje odesílání notifikací do Uptime Kuma.

## Použití

1.  **Konfigurace:** Upravte soubor `.mailtest` a nastavte parametry pro vaše SMTP spojení (server, port, uživatelské jméno, heslo, odesílatel, příjemce, atd.). Příklad konfiguračního souboru naleznete v `.mailtest.example`.
2.  **Spuštění:** Spusťte aplikaci pomocí dávkového souboru `mailtest.bat`.
    ```bash
    .\mailtest.bat
    ```
3.  **Logování:** Výsledky každého spuštění naleznete v souboru `log.txt`.

## Kompatibilita

Aplikace byla testována na operačním systému Windows 11.

## Soubory

-   `libmailtest.ps1`: Hlavní PowerShell skript.
-   `.mailtest`: Konfigurační soubor.
-   `mailtest.bat`: Dávkový soubor pro spuštění skriptu.
-   `log.txt`: Soubor s logy.
-   `.mailtest.example`: Příklad konfiguračního souboru.
-   `README.md`: Tato dokumentace.
