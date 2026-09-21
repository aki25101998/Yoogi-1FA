# LUẬT BACKUP BẮT BUỘC (GIT PUSH RULE)

Mỗi khi bạn (Agent) thực hiện thay đổi, cập nhật hoặc sửa lỗi code trong dự án này (dù là nhỏ nhất), bạn **BẮT BUỘC** phải tự động chạy lệnh commit và push lên GitHub ngay lập tức sau khi hoàn thành công việc.
TUYỆT ĐỐI KHÔNG CẦN đợi người dùng nhắc nhở hoặc yêu cầu lệnh "push".

**Cách thực hiện (sử dụng tool `run_command` trên PowerShell):**
```powershell
git add . ; git commit -m "Tóm tắt ngắn gọn thay đổi" ; git push
```

**Mục tiêu:** 
Đảm bảo source code không bao giờ bị mất, lưu lại lịch sử rõ ràng và luôn đồng bộ. Hãy thực hiện việc này một cách chủ động như một phần bắt buộc của quy trình kết thúc task.

# LU?T COMPILE B?T BU?C

M?i khi b?n ch?nh s?a xong c�c file code (.mq5, .mqh), b?n **B?T BU?C** ph?i bi�n d?ch (compile) m� ngu?n b?ng c�ch tu�n th? d�ng quy tr�nh du?c d?nh nghia trong file hu?ng d?n compile: .agents/workflows/auto-compile.md.

**C? th?:**
- S? d?ng d�ng l?nh CLI (b?c b?ng `cmd.exe /c`) d? g?i `MetaEditor64.exe` v?i tham s? `/compile` v� `/log`.
- Ch? l?nh ch?y xong v� d?c file `compile.log` d? x�c minh k?t qu? c� `0 errors` kh�ng.
- Th�ng b�o r� r�ng cho ngu?i d�ng v? k?t qu? compile v� s? t?n t?i c?a file `.ex5`.
- TUY?T �?I KH�NG du?c lu?i bi?ng b? qua bu?c compile sau khi s?a code, v� c?n c� file `.ex5` m?i nh?t d? user test ngay.

