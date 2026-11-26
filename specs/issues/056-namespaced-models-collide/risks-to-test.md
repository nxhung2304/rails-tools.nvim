# Risks to test - #56

- Ghi đè cùng tên file đã hết: chạy headless `annotate.scan` trên `test-app/` (có `User` và `Admin::User`), kỳ vọng trả về cả hai.
- Project chỉ có `app/models/admin/user.rb` (không có `User` top-level): `user.email` trước đây resolve, giờ không. Test: ghi chỉ `admin/user.rb` trong describe riêng, `hover_lines("user", ...)` kỳ vọng nil.
- Trong `app/models/admin/user.rb`, gõ `email` và `self.email` rồi hover: kỳ vọng hiện cột của `Admin::User`.
- Mở file concern: kỳ vọng hover LSP bình thường. `test-app/app/models/` chỉ có `concern/` rỗng, nên tạo tạm `concerns/searchable.rb`, mở nó, bấm `K`.
- nvim-cmp thật với `user&.`: unit test chỉ stub cmp. Test tay: trong `test-app/`, gõ `user&.` trong buffer ruby có cmp, kỳ vọng thấy cột của `User`.
- Root path chứa `app/models/`: chạy case tương ứng trong `model_context_spec`.
- App dùng Zeitwerk `collapse` hoặc thêm `app/models/<dir>` vào autoload_paths: `model.col` ngoài file model không còn resolve. Test: fixture `app/models/billing/invoice.rb`, `hover_lines("invoice", ...)` kỳ vọng nil (đã chấp nhận).
- Acronym (`API::Token`) ra nhãn `Api::Token`: chỉ ảnh hưởng nhãn hiển thị. Test: `model_for_path("app/models/api/token.rb")` kỳ vọng `Api::Token`.
- Xung đột merge với #61 (sửa `singularize`/`pluralize`, thêm hằng số đầu `model_context.lua`): bên merge sau rebase rồi chạy lại `tests/core/model_context_spec.lua`.

## Related
- [issue.md](issue.md)
- [implement.md](implement.md)
- [comment.log](comment.log)
