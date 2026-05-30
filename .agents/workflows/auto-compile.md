# Auto Compile MQL5

This workflow provides instructions on how to compile MQL5 code automatically using the CLI. Use this workflow whenever you finish editing an `.mq5` or `.mqh` file to provide the user with the final compiled `.ex5` file.

## Method

To prevent MetaEditor from hanging in PowerShell (which blocks your capabilities), you MUST wrap the command using `cmd.exe /c` and provide the proper CLI arguments `/compile` and `/log`.

### Compile Command

```powershell
// turbo
cmd.exe /c '"C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" /compile:"d:\Project\yoogi 1fa\Yoogi 1FA.mq5" /log:"d:\Project\yoogi 1fa\compile.log"'
```

### Steps to Compile
1. Run the compilation command above using `run_command` (`SafeToAutoRun=true`). Wait 3-5 seconds before async or until it finishes.
2. Read the `compile.log` output to check if compilation was successful (`0 errors`). Lệnh xem log:
   `Get-Content -Path "d:\Project\yoogi 1fa\compile.log" -Encoding Unicode | Select-Object -Last 10`
3. Verify the `.ex5` file was successfully generated with `Get-ChildItem -Path "d:\Project\yoogi 1fa" -Filter *.ex5`.
4. Inform the user whether the compilation succeeded or failed, and confirm the `.ex5` file is ready.
