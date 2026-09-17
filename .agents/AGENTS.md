# LUẬT BACKUP BẮT BUỘC (GIT PUSH RULE)

Mỗi khi bạn (Agent) thực hiện thay đổi, cập nhật hoặc sửa lỗi code trong dự án này (dù là nhỏ nhất), bạn **BẮT BUỘC** phải tự động chạy lệnh commit và push lên GitHub ngay lập tức sau khi hoàn thành công việc.
TUYỆT ĐỐI KHÔNG CẦN đợi người dùng nhắc nhở hoặc yêu cầu lệnh "push".

**Cách thực hiện (sử dụng tool `run_command` trên PowerShell):**
```powershell
git add . ; git commit -m "Tóm tắt ngắn gọn thay đổi" ; git push
```

**Mục tiêu:** 
Đảm bảo source code không bao giờ bị mất, lưu lại lịch sử rõ ràng và luôn đồng bộ. Hãy thực hiện việc này một cách chủ động như một phần bắt buộc của quy trình kết thúc task.
