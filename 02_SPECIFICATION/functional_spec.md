# G06 · Đặc tả chức năng (Functional Specification)

> ⚠️ **CẢNH BÁO ĐỐI CHIẾU CHARTER — một phần yêu cầu Charter mục 4 CHƯA THOẢ.**
>
> | # | Yêu cầu Charter mục 4 | Trạng thái | Bằng chứng |
> |---|---|:-:|---|
> | C4-1 | `ui_in[7:0]` = x · `uio_in[0]` = mẫu hợp lệ · `uo_out[7:0]` = y · `uio_out[0]` = kết quả hợp lệ | ❌ **CHƯA THOẢ** | RTL `g06_iir_half.sv` không có cổng `ui_in`/`uo_out`/`uio_in`/`uio_out`/`uio_oe`/`ena`. Đây là **module lõi**, chưa có lớp vỏ Tiny Tapeout |
> | C4-2 | *"Lỗi ánh xạ cần sửa trước khi thiết kế: chân `uio[0]` bị gán vừa làm đầu vào vừa làm đầu ra… chỉ cần đánh số lại"* | ❌ **CHƯA SỬA** | Việc đánh số lại phải làm ở **lớp vỏ**, mà lớp vỏ chưa tồn tại. Trong hồ sơ này không có file nào chốt `uio[0]` là vào hay ra |
> | C4-3 | Ngân sách chân 18/24 | ✅ **thoả về số học** | Bit dữ liệu thật = 9 vào (`x[7:0]` + `valid_in`) + 9 ra (`y[7:0]` + `valid_out`) = **18** ≤ 24. Đây là đề G **duy nhất trong ba đề G05/G06/G07 không vượt ngân sách chân** |
>
> ⚠️ **Rủi ro kiểu dữ liệu ở biên khối — CẦN CHỐT.** Cổng khai báo **không dấu**
> (`input logic [7:0] x`, `output logic [7:0] y`) nhưng bên trong xử lý **có dấu bù 2**
> (`logic signed [7:0] y_q`, mở rộng dấu `{x[7], x}`, dịch số học `>>>`). Bit là như nhau,
> nhưng **hợp đồng không được ghi ở giao diện**. Nếu tầng ngoài coi `x` là 0…255 thì mẫu
> 200 sẽ được khối hiểu là −56. Đây là khe hở đặc tả, cần thầy chốt rõ.
>
> 📌 **Sai số trong file sinh tự động `interface.md` §3.** File đó tính "Tổng bit vào = 11"
> vì đếm cả `clk` và `rst_n`. `clk`/`rst_n` do **hạ tầng Tiny Tapeout cấp**, không nằm trong
> 24 chân người dùng. Con số đúng là **18 bit dữ liệu**.
>
> **Không tự sửa RTL.** Đặc tả dưới đây mô tả **đúng hành vi RTL đang có**.

---

## 1. Khối này làm gì — phát biểu một câu

G06 là **bộ lọc thông thấp IIR bậc một**, hệ số 1/2, hiện thực bằng đúng một phép cộng và
một phép dịch phải số học. Mỗi khi `valid_in = 1` tại cạnh lên, khối cập nhật:

```
              ⎣ x[n] + y[n−1] ⎦
     y[n]  =  ⎣ ───────────── ⎦        ⎣·⎦ = làm tròn XUỐNG (floor)
              ⎣       2       ⎦
```

Bối cảnh (Charter mục 1): làm trơn tín hiệu cảm biến ánh sáng môi trường để chỉnh độ sáng
màn hình mượt, **tốn ít bộ nhớ hơn lọc trung bình**.

## 2. Vì sao là `⎣·⎦` (floor) chứ không phải "chia 2"

Đây là điểm kỹ thuật **quan trọng nhất** của đề, và cũng là nguồn gốc lỗi mô phỏng — xem
`05_VERIFICATION/known_issues.md`.

RTL dùng `>>> 1` (arithmetic right shift) chứ không dùng `/ 2`:

```systemverilog
y_shift = sum_ext >>> 1;
```

| Toán tử | Với `+199` | Với `−199` | Bản chất |
|---|---:|---:|---|
| `>>> 1` (dịch số học) | 99 | **−100** | **Làm tròn XUỐNG** — về phía −∞ |
| `/ 2` trong C / SystemVerilog | 99 | **−99** | **Làm tròn về 0** (truncation) |
| Python `// 2` | 99 | **−100** | Làm tròn xuống — **khớp `>>>`** |

`>>> 1` **không** tương đương chia 2. Nó tương đương chia 2 **rồi làm tròn xuống**, và hai
phép này chỉ khác nhau khi kết quả âm và lẻ. Mô hình chuẩn Python đã chọn đúng (`v // 2`,
với chú thích ngay trong mã: *"Python // 2 is floor division, matching arithmetic right
shift by one"*).

## 3. Định nghĩa hình thức và bảng hành vi

Gọi `x[n]` là dãy mẫu **đã lọc theo `valid_in`** (chỉ tính những cạnh lên có `valid_in = 1`).

| `rst_n` | `valid_in` | `y_q` (trạng thái) kế tiếp | `y` kế tiếp | `valid_out` kế tiếp |
|:-:|:-:|---|---|:-:|
| 0 | × | `0` | `0` | 0 |
| 1 | 0 | **giữ** | **giữ** | 0 |
| 1 | 1 | `⎣(x + y_q)/2⎦` (8 bit thấp) | như trên | **1** |

Điều kiện đầu: `y[−1] = 0` sau reset.

### Bảng hành vi cụ thể — đáp ứng bước nhảy `x = 100` (lấy từ testbench + golden model)

| `n` | `x[n]` | `x + y[n−1]` | `y[n] = ⎣·/2⎦` | Sai số còn lại `100 − y[n]` |
|---:|---:|---:|---:|---:|
| 1 | 100 | 100 | **50** | 50 |
| 2 | 100 | 150 | **75** | 25 |
| 3 | 100 | 175 | **87** | 13 |
| 4 | 100 | 187 | **93** | 7 |
| 5 | 100 | 193 | **96** | 4 |
| 6 | 100 | 196 | **98** | 2 |
| 7 | 100 | 198 | **99** | 1 |
| 8 | 100 | 199 | **99** | **1 — ĐỨNG YÊN** |

Sai số **giảm một nửa mỗi mẫu** — đây là quy luật tiệm cận mà Charter mục 2 câu 3 hỏi. Nhưng
nó **dừng ở 1**, không về 0. Xem §4.

## 4. Ba hệ quả của việc làm tròn xuống — phần cốt lõi của đề

### 4.1 Đáp ứng bước nhảy dương **không bao giờ đạt tới `x`**

Điểm bất động của phép lặp là `y` thoả `y = ⎣(x+y)/2⎦`. Với `x = 100`:
`y = 99 → ⎣199/2⎦ = 99` ✅ bất động. Vậy bộ lọc **kẹt ở 99**, thiếu đúng **1 LSB**.

Tổng quát: với `x > 0`, đáp ứng bước nhảy hội tụ về **`x − 1`**, không phải `x`.

### 4.2 Đáp ứng bước nhảy **âm** thì đạt đúng — bất đối xứng

Với `x = −100`: golden model cho `[−50, −75, −88, −94, −97, −99, −100, −100]` — hội tụ về
**đúng −100**. Kiểm: `y = −100 → ⎣−200/2⎦ = −100` ✅.

| Chiều | Điểm hội tụ | Sai lệch DC |
|---|---|---|
| Bước nhảy **dương** `x > 0` | `x − 1` | **−1 LSB** |
| Bước nhảy **âm** `x < 0` | `x` | **0** |
| `x = 0` từ phía dương | `0` | 0 |
| `x = 0` từ phía **âm** | **−1** | **−1 LSB, vĩnh viễn** |

Hàng cuối là cái bẫy nguy hiểm nhất: nếu `y` từng xuống −1 và sau đó `x = 0` mãi mãi, thì
`⎣(0 + (−1))/2⎦ = ⎣−0,5⎦ = −1` — bộ lọc **không bao giờ trở về 0**. Với ứng dụng cảm biến
ánh sáng, điều này nghĩa là màn hình giữ một mức lệch nhỏ vĩnh viễn sau mỗi lần tối.

### 4.3 Hiện tượng **đứng yên** ở giá trị nhỏ

Bộ lọc chỉ nhích được khi `⎣(x − y)/2⎦ ≠ 0`, tức khi **`x − y ≥ 2`** (phía dương). Hệ quả:

| Ca | Diễn biến | Bằng chứng |
|---|---|---|
| `x = 1`, `y = 0` | `⎣1/2⎦ = 0` ⟹ **đứng yên vĩnh viễn ở 0** | golden `test_low_value_standing_still()`: `run([1]*12)` cho `[0]*12` |
| `x = 1`, `y = 99` (sau bước nhảy) | `⎣100/2⎦ = 50` rồi `⎣51/2⎦ = 25` … — vẫn giảm được vì `\|x−y\|` còn lớn | testbench dòng 45–46 |
| `x = 3`, `y = 0` | `⎣3/2⎦ = 1`, rồi `⎣4/2⎦ = 2`, rồi `⎣5/2⎦ = 2` ⟹ đứng yên ở 2 = `x−1` | suy từ công thức |

> 🔎 Charter mục 10 cảnh báo đúng chỗ này: *"Không phát hiện hiện tượng đứng yên vì chỉ test
> giá trị lớn."* Với `x = 100` thì bộ lọc hoạt động rất đẹp; với `x = 1` thì nó **không làm
> gì cả**. Đây là hệ quả của **độ phân giải hữu hạn**, không phải lỗi thiết kế — nhưng phải
> được đặc tả nói ra.

## 5. Tính chất bất biến (Invariants)

| ID | Phát biểu | Ghi chú |
|---|---|---|
| **INV-1** | `valid_out[n] = valid_in[n−1]` khi `rst_n = 1` — cờ ra là bản trễ một chu kỳ của cờ vào | Đã có trong `testbench/properties.sv`: `valid_out \|-> $past(valid_in)` (dạng một chiều) |
| **INV-2** | `y` chỉ đổi giá trị tại cạnh lên có `valid_in = 1` | `!valid_in \|=> $stable(y)` |
| **INV-3** | `sum_ext` luôn nằm trong `[−256, 254]` ⟹ **không bao giờ tràn** 9 bit | Golden `test_feedback_bound()` kiểm vét cạn 256 × 7 tổ hợp |
| **INV-4** | `y_shift[8] == y_shift[7]` luôn đúng ⟹ cắt `y_shift[7:0]` **không mất thông tin** | Hệ quả của INV-3: sau khi chia 2, kết quả nằm trong `[−128, 127]` |
| **INV-5** | `\|y[n] − x[n]\| ≤ \|y[n−1] − x[n]\|` — bộ lọc **không bao giờ vọt lố** (no overshoot) | Tính chất của bộ lọc bậc một cực dương |
| **INV-6** | Với `x` hằng, dãy `y[n]` **đơn điệu** (tăng hoặc giảm, không dao động) | Hệ quả của cực thực dương `z = 1/2` |
| **INV-7** | Sau reset, `y = 0` và `valid_out = 0` | dòng 25–27 RTL |
| **INV-8** | Số ô nhớ của trạng thái lọc = **8 bit** (`y_q`) — không phụ thuộc chiều dài lịch sử | Netlist: chỉ có `y[0..7]` và `valid_out` |

> `properties.sv` hiện chỉ có INV-1 và nằm sau `` `ifdef G06_SVA `` — **chưa được bật** trong
> lần chạy đã ghi log.

## 6. Ràng buộc cấu trúc bắt buộc

Tên đề chỉ định rõ **"IIR bậc một hệ số 1/2"**, nên RTL bắt buộc phải mô tả tường minh:

| Ràng buộc | RTL có thoả? | Bằng chứng |
|---|:-:|---|
| **Bậc một** — chỉ nhớ `y[n−1]`, không nhớ `x[n−1]` | ✅ | Chỉ có **một** thanh ghi trạng thái `y_q`; không có thanh ghi nào giữ `x` |
| **Hệ số 1/2** — hiện thực bằng **dịch bit**, không bằng bộ nhân | ✅ | `>>> 1`. Netlist **không có** cell nhân nào; 54 cell toàn cổng cơ bản |
| **Hồi tiếp (IIR)** — đầu ra quay lại đầu vào | ✅ | `y_ext = {y_q[7], y_q}` và `y_q <= y_shift[7:0]` — vòng kín |
| Hệ số **không** lập trình được | ✅ (đúng yêu cầu) | Charter mục 3: "hệ số lập trình được" là **ngoài phạm vi** |

## 7. Hàm truyền và tần số cắt (suy từ công thức, không phải số đo)

```
             1/2                              1
 H(z) = ─────────────      ⟹   cực tại z = ───   (thực, dương, trong vòng tròn đơn vị)
         1 − (1/2)·z⁻¹                        2
```

| Đại lượng | Suy ra |
|---|---|
| `H(1)` (DC gain) | `0,5 / 0,5 = 1` ⟹ **không** đổi biên độ ở DC (lý tưởng, chưa tính floor) |
| Ổn định? | Có — cực `0,5` nằm trong vòng tròn đơn vị |
| Tần số cắt −3 dB | Giải `0,25/(1,25 − cos ω) = 0,5` ⟹ `cos ω = 0,75` ⟹ `ω ≈ 0,7227 rad/mẫu` ⟹ **f_c ≈ 0,115 · f_s** |
| Hằng số thời gian | Sai số giảm ×1/2 mỗi mẫu ⟹ `τ = 1/ln2 ≈ 1,44 mẫu` |
| Thời gian ổn định tới 1 LSB từ bước nhảy 100 | `log₂(100) ≈ 6,6` ⟹ **7 mẫu**. Bảng §3 cho đúng **7 mẫu** |

> ⚠️ Đây là **suy diễn giải tích**, không phải số đo. Trong thực tế, phép floor làm hàm
> truyền trên **không còn tuyến tính**, nên `f_c ≈ 0,115 f_s` chỉ đúng với tín hiệu đủ lớn
> so với 1 LSB.

## 8. Điều kiện biên và hành vi không xác định

| Tình huống | Hành vi RTL | Được bảo đảm? |
|---|---|---|
| `x = −128` (biên âm) | `sum_ext` xuống tới −256, vẫn vừa 9 bit | ✅ INV-3. Có ca kiểm thử (TB dòng 49) — **và chính ca này lộ lỗi**, xem `known_issues.md` |
| `x = +127`, `y = +127` | `sum_ext = 254`, `y = 127` | ✅ |
| Tràn `sum_ext` | **Không thể xảy ra** — mở rộng dấu lên 9 bit trước khi cộng | ✅ INV-3, golden kiểm vét cạn |
| `valid_in = 0` kéo dài | `y` **giữ nguyên** — bộ lọc "đóng băng", không tự trôi | ✅ TB dòng 52–54 |
| Reset giữa dòng | `y` về 0 ngay; lịch sử mất | ⚠️ Không có cờ báo. Sau reset, `y` mất 7 mẫu để bắt lại bước nhảy |
| `x` chứa `X`/`Z` | `X` lan vào `y_q` và **ở lại vĩnh viễn** (vì có hồi tiếp!) | ❌ **Nguy hiểm hơn mạch không hồi tiếp** — một mẫu `X` làm hỏng mọi mẫu sau, tới khi reset |
| Diễn giải `x` là không dấu | Mẫu > 127 bị hiểu thành số âm | ❌ Khe hở đặc tả — xem cảnh báo đầu file |

> 🔎 Hàng "`X` lan vĩnh viễn" là đặc trưng của **mọi** mạch IIR và đáng nhấn mạnh: khác với
> FIR (G01), nơi một mẫu hỏng chỉ ảnh hưởng N mẫu kế, ở IIR một mẫu hỏng ảnh hưởng **toàn bộ
> tương lai**. Đó là cái giá của việc dùng ít bộ nhớ.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
