---
description: Tự động backup (git commit + push GitHub) trước khi sửa code để đảm bảo an toàn
---

// turbo-all

## Trước khi sửa code

1. Kiểm tra trạng thái
```powershell
git status
```

2. Nếu có thay đổi chưa commit, lưu checkpoint
```powershell
git add .
git commit -m "Auto-backup truoc khi sua code"
git push
```

## Sau khi sửa code xong

3. Lưu checkpoint mới và push lên GitHub
```powershell
git add .
git commit -m "[Mo ta thay doi]"
git push
```

## Khi user muốn quay lại bản trước

4. Xem lịch sử
```powershell
git log --oneline -10
```

5. Hoàn tác commit cuối
```powershell
git revert HEAD --no-edit
git push
```
