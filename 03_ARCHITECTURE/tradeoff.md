# G06 · Phân tích đánh đổi (Trade-off)

---

## 1. Số liệu nền — mọi so sánh dưới đây quy chiếu về đây

| Chỉ số | Giá trị thật | Nguồn |
|---|---:|---|
| Số cell | **54** | `synth_stat.txt` |
| Flip-flop | **9** | như trên |
| Diện tích | **482,9632 µm²** | như trên |
| Diện tích 1 `dfxtp_1` | **20,0192 µm²** | `sky130_fd_sc_hd__tt_025C_1v80.lib` (chính file Liberty dùng trong flow) |
| ⟹ Diện tích thanh ghi | 9 × 20,0192 = **180,1728 µm²** = **37,3 %** | tính từ hai dòng trên |
| ⟹ Diện tích tổ hợp | 482,9632 − 180,1728 = **302,7904 µm²** = **62,7 %** (45 cell) | như trên |
| Đường tới hạn | `x[1] → y[7]`, **3,75 ns** (gồm 1,00 ns IO delay giả định) | `timing_report_max.txt` |
| Công suất ước lượng | 6,04e-05 W — tuần tự **71,2 %**, tổ hợp 28,8 % | `power_report.txt` |
| Charter ước lượng quy mô | ~180–260 cell | Charter metadata |

> Thiết kế thật **54 cell**, tức **chỉ bằng 30 %** cận dưới Charter ước lượng (180). Lý do:
> Charter ước lượng cho một khối có lớp vỏ Tiny Tapeout và có thể có logic bù/bão hoà; RTL
> hiện tại là **module lõi trần** với đúng một bộ cộng.

## 2. So sánh với hai kiến trúc thay thế

| Tiêu chí | **① IIR bậc 1, hệ số 1/2** (đã chọn) | ② FIR trung bình trượt 4 điểm (= **G01 thật**) | ③ IIR hệ số tuỳ ý (ví dụ α = 0,3) |
|---|---|---|---|
| Bộ nhớ trạng thái | **8 bit** (1 giá trị) | 32 bit (4 mẫu) + thanh ghi tổng | 8 bit |
| Flip-flop | **9** (đo) | **58** (đo, hồ sơ G01) | ≥ 9, thêm thanh ghi hệ số nếu lập trình được |
| Số cell | **54** (đo) | **260** (đo) | ≫ 54 — cần **bộ nhân** hoặc nhiều tầng shift-add |
| Diện tích | **482,9632 µm²** (đo) | **2623,7664 µm²** (đo) | ước lượng ≥ 1500 µm² (một bộ nhân 8×8 đã ≥ 60 cell) |
| Đường tới hạn | 3,75 ns (đo) | 4,56 ns (đo) | lớn hơn — bộ nhân sâu hơn bộ cộng |
| Chi phí của hệ số | **0 cell** — `>>> 1` là đấu dây | 0 cell (chia 4 = `>>> 2`) | **cao** — đây là cả vấn đề |
| Đáp ứng xung | **Vô hạn** — 1 mẫu hỏng ảnh hưởng mãi mãi | **Hữu hạn 4 mẫu** — tự sạch | Vô hạn |
| Pipeline được không? | **KHÔNG** (vòng hồi tiếp) | **CÓ**, tuỳ ý | Không |
| Sai lệch DC | **−1 LSB** (do `⎣·⎦`) | −1,5 LSB trung bình (do `>>> 2`), **không tích luỹ** | tuỳ cách làm tròn |
| Khi nào nên dùng | Cần rẻ, chấp nhận đuôi vô hạn — **đúng bối cảnh G06** | Cần đáp ứng hữu hạn, cần pipeline, cần pha tuyến tính | Cần đặt `f_c` chính xác |

### Trả lời Charter mục 2 câu 1 bằng số

> *"IIR bậc một chỉ cần nhớ y[n−1] — so với G01 (nhớ 4 mẫu) thì tiết kiệm bao nhiêu ô nhớ?"*

| So sánh | G01 | G06 | Tỷ lệ |
|---|---:|---:|---:|
| Flip-flop | 58 | **9** | **6,4 ×** |
| Số cell | 260 | **54** | 4,8 × |
| Diện tích | 2623,7664 µm² | **482,9632 µm²** | **5,4 ×** |
| Diện tích tiết kiệm được | | **2140,80 µm²** | |

Charter mục 10 dự đoán *"ít hơn G01 tới hơn 3 lần"*. Số thật **vượt dự đoán**: 6,4× về
flip-flop, 5,4× về diện tích.

> ⚠️ **Điều kiện để so sánh này hợp lệ:** hai hồ sơ chạy **cùng** tổ hợp công cụ (Yosys 0.33
> · OpenSTA 3.1.0 · `sky130_fd_sc_hd__tt_025C_1v80.lib`) — xem `parameters.md` §2 của cả hai
> hồ sơ. Nếu khác môi trường thì **không được** so chéo.

## 3. Đánh đổi bên trong bộ cộng: ripple-carry vs carry-lookahead

Vì vòng hồi tiếp **không pipeline được** (xem `datapath.md` §4.3), cách duy nhất tăng tần số
là rút ngắn **bản thân bộ cộng**.

| Phương án | Độ sâu carry | Ước lượng độ trễ | Ước lượng diện tích | Ghi chú |
|---|---|---|---|---|
| **Ripple-carry** (Yosys chọn) | 9 tầng | **2,75 ns** (đo: 5 `maj3_1` = 1,95 ns + 0,80 ns logic khác) | **302,79 µm²** tổ hợp (đo) | Chữ ký: slack **đơn điệu giảm** từ `y[0]` = 8,51 ns xuống `y[7]` = 6,18 ns |
| Carry-lookahead 9 bit | ~3–4 tầng | ước lượng ~1,2–1,5 ns | ước lượng +50…100 % tổ hợp ⟹ **+150…300 µm²** | Chưa chạy. Phải ép Yosys bằng `techmap` hoặc viết tường minh |
| Carry-select 2×4+1 bit | ~5 tầng | ước lượng ~1,8 ns | ước lượng +80 % tổ hợp | Chưa chạy |

> ⚠️ **Ranh giới trung thực:** cột "ripple-carry" là **số đo**; hai cột còn lại là **ước
> lượng theo tỷ lệ**, không có kết quả chạy tool. Muốn có số thật phải viết RTL rồi chạy lại
> Yosys — **chưa làm**.
>
> Và phải nói thêm: với slack hiện tại **6,18 ns / 10 ns**, việc tối ưu bộ cộng là **không
> cần thiết**. Ghi ở đây chỉ để trả lời câu "nếu cần nhanh hơn thì làm gì".

## 4. Đánh đổi quan trọng nhất của đề: **phép làm tròn**

Đây là chỗ đáng bàn nhất, vì nó cho thấy một sửa đổi **gần như miễn phí** giải quyết được
**cả hai** khuyết điểm đã nêu ở `functional_spec.md` §4.

### 4.1 Ba cách làm tròn và hệ quả

| Cách | Công thức | Chi phí phần cứng thêm | Điểm hội tụ với `x = 100` | `y = −1`, `x = 0` |
|---|---|---|---|---|
| **A. Floor** (hiện tại) | `(x + y) >>> 1` | — (chuẩn) | **99** ❌ thiếu 1 | **kẹt ở −1** ❌ |
| **B. Round-half-up** | `(x + y + 1) >>> 1` | **≈ 0 cell** — chỉ cần đặt `carry-in = 1` cho bộ cộng, chân vốn đang nối 0 | **100** ✅ đúng | **về 0** ✅ |
| C. Round-half-to-even | phức tạp hơn | +vài cell (cần biết bit LSB của kết quả) | 100 ✅ | về 0 ✅ |

Kiểm phương án B bằng tay:

```
  x = 100:  y=99  → ⎣(100+99+1)/2⎦ = ⎣100⎦   = 100  ✅ đạt đúng x
            y=100 → ⎣(100+100+1)/2⎦= ⎣100,5⎦ = 100  ✅ bất động
  x = 0:    y=−1  → ⎣(0−1+1)/2⎦    = ⎣0⎦     = 0    ✅ thoát bẫy −1
  x = 1:    y=0   → ⎣(1+0+1)/2⎦    = ⎣1⎦     = 1    ✅ HẾT đứng yên ở giá trị nhỏ
```

> 🔎 **Phát hiện đáng chú ý:** cộng thêm 1 trước khi dịch **không tốn cell nào** ở một bộ
> cộng ripple-carry, vì chân `carry-in` của tầng 0 vốn đã tồn tại và đang nối `0`. Đổi nó
> thành `1` là **miễn phí về diện tích**. Đổi lại, cả ba vấn đề (sai lệch DC dương, kẹt ở
> −1, đứng yên ở giá trị nhỏ) đều biến mất.
>
> **Nhưng bất đối xứng chỉ bị LẬT, không bị xoá:** với `x = −1`, `y = 0` thì
> `⎣(−1+0+1)/2⎦ = 0` ⟹ nay **phía âm** đứng yên. Muốn hết hẳn phải dùng phương án C.

### 4.2 Vì sao **không** đề xuất áp dụng ngay

| Lý do | Giải thích |
|---|---|
| **Charter chọn `>>>` có chủ ý** | Charter mục 2 câu 2 hỏi thẳng: *"Dịch phải số có dấu gây vấn đề làm tròn gì, và hiện tượng 'đứng yên' ở giá trị nhỏ là gì?"* — hiện tượng này là **nội dung dạy học**, không phải lỗi cần vá |
| Charter mục 10 xác nhận | *"Chỗ hay tắc: Không phát hiện hiện tượng đứng yên vì chỉ test giá trị lớn."* Nếu vá đi thì không còn gì để phát hiện |
| Quy tắc hồ sơ | Không tự sửa RTL của thầy |

**Kết luận:** phương án B được ghi lại ở đây như **kiến thức**, không phải **đề xuất thay
đổi**. Nếu sau này khối được dùng thật trong sản phẩm, đây là chỗ đầu tiên nên xem lại.

## 5. Đánh đổi độ chính xác: thêm bit phân số vào trạng thái

Một cách khác hoá giải "đứng yên", tốn tiền hơn nhưng đúng đắn về mặt DSP:

| Phương án | `y_q` rộng | FF thêm | Diện tích thêm | Ngưỡng đứng yên |
|---|---:|---:|---:|---|
| Hiện tại | 8 bit | — | — | `\|x − y\| ≤ 1` LSB |
| +2 bit phân số | 10 bit | +2 | **+40,04 µm²** (+8,3 %) | `≤ 1/4` LSB |
| +4 bit phân số | 12 bit | +4 | **+80,08 µm²** (+16,6 %) | `≤ 1/16` LSB |
| +8 bit phân số | 16 bit | +8 | **+160,15 µm²** (+33,2 %) | `≤ 1/256` LSB |

Trong đó `y` xuất ra ngoài vẫn là 8 bit (chỉ lấy phần nguyên), nên **giao diện không đổi**.
Chi phí thêm là FF **và** bộ cộng rộng hơn (thêm ~2 cell/bit).

> So sánh hai cách: **cộng thêm 1 trước khi dịch** (§4) tốn **0 µm²** và xoá được hiện tượng
> đứng yên **một chiều**; **thêm bit phân số** tốn 40–160 µm² nhưng xoá được **cả hai chiều**
> và giảm nhiễu lượng tử. Nếu chỉ được chọn một, phương án §4 có tỷ lệ lợi/chi phí tốt hơn
> nhiều — đây là một ví dụ đẹp về "một bit carry-in đáng giá bao nhiêu".

## 6. Đánh đổi công suất

| Quan sát | Số | Hệ quả |
|---|---|---|
| Tuần tự chiếm **71,2 %** công suất (4,30e-05 W / 6,04e-05 W) | `power_report.txt` | Dù chỉ có 9 FF, chúng vẫn là nhóm tốn nhất |
| Tổ hợp **28,8 %** (1,74e-05 W) — cao hơn G05 (17,9 %) | so hai `power_report.txt` | Vì G06 có tỷ lệ cell tổ hợp/FF cao hơn: 45/9 = 5,0 so với 166/36 = 4,6, **và** bộ cộng chuyển mạch nhiều hơn logic chọn |
| Hoạt động chuyển mạch phụ thuộc mạnh vào tín hiệu | — | Tín hiệu **trơn** (đã lọc) làm `y` đổi ít bit mỗi mẫu ⟹ công suất thấp. Tín hiệu **nhiễu** làm carry lan xa ⟹ công suất cao. Con số hiện tại dùng **hoạt động mặc định**, không phải VCD thật |

## 7. Những đánh đổi **KHÔNG được phép** trong đề này

| Việc | Vì sao cấm | Nguồn |
|---|---|---|
| Đổi sang **IIR bậc cao** | Charter mục 3: ngoài phạm vi | Charter mục 3 |
| Làm **hệ số lập trình được** | Charter mục 3: ngoài phạm vi | Charter mục 3 |
| Thêm logic **ổn định số học** (chống limit cycle) | Charter mục 3: ngoài phạm vi | Charter mục 3 |
| **Sửa RTL** để bỏ hiện tượng đứng yên | Hiện tượng này là **nội dung dạy học** của đề (Charter mục 2 câu 2, mục 10) | Charter |
| Tự **tối ưu netlist bằng tay** | Ngoài phạm vi với mọi đề | Charter mục 3 |
| **Sửa RTL của thầy** để khớp Charter mục 4 | Hồ sơ này chỉ phân tích và cảnh báo | Quy tắc hồ sơ |
| Nói "G06 chạy được ở 266 MHz" | 3,75 ns gồm IO delay giả định, chưa có dây, 1 góc PVT, **và chưa gồm đường vòng hồi tiếp** | `timing.md` §3 |

## 8. Tóm tắt một câu

> Kiến trúc IIR bậc một hệ số 1/2 của G06 là **lựa chọn cực rẻ**: **6,4 lần ít flip-flop** và
> **5,4 lần ít diện tích** so với FIR 4 điểm của G01, vì hệ số `2^−1` hiện thực bằng **đấu
> dây (0 cell)** và trạng thái chỉ cần **một** giá trị; cái giá phải trả là đáp ứng xung **vô
> hạn**, **không pipeline được** vì vòng hồi tiếp, và **sai lệch DC −1 LSB** do phép floor —
> khuyết điểm cuối này có thể xoá **gần như miễn phí** bằng cách đặt `carry-in = 1`, nhưng
> Charter cố ý giữ lại để dạy.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
