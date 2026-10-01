---
description: Compile EA Yoogi 1FA bằng MetaEditor64 từ command line (không mở GUI)
---

# Compile MQL5

Workflow này cung cấp các bước biên dịch tự động EA Yoogi 1FA bằng MetaEditor64 CLI.

## Các bước thực hiện:

1. Xóa file log cũ:
```powershell
Remove-Item "d:\Project\yoogi 1fa\compile.log" -Force -ErrorAction SilentlyContinue
```

2. Biên dịch EA:
```powershell
cmd.exe /c '"C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" /compile:"d:\Project\yoogi 1fa\Yoogi 1FA.mq5" /log:"d:\Project\yoogi 1fa\compile.log"'
```

3. Kiểm tra kết quả biên dịch:
```powershell
Get-Content -Path "d:\Project\yoogi 1fa\compile.log" -Encoding Unicode | Select-Object -Last 10
```

4. Xác nhận file `.ex5` đã được cập nhật:
```powershell
Get-ChildItem -Path "d:\Project\yoogi 1fa" -Filter *.ex5 | Select-Object FullName,LastWriteTime,Length
```
