# G06 · Vấn đề đã biết và phán xử lỗi (Known Issues)

## 0. Trạng thái: ✅ **ĐÃ ÁP DỤNG** — 2026-09-24

> **Giảng viên đã duyệt áp dụng bản vá.** **Phương án A** ở §6 (sửa một ký tự:
> `-8'sd51` → `-8'sd52`) **đã được ghi vào** `05_VERIFICATION/testbench/g06_tb.sv`, kèm một
> dòng chú thích giải thích số học. Nhật ký chi tiết: `08_ORIGINAL_SOURCE/PATCHLOG.md`.
>
> **Phần chẩn đoán §1–§11 giữ nguyên** — nó là tài liệu dạy học và vẫn mô tả đúng lỗi gốc.
> Mọi câu "chưa áp dụng" trong §6/§10 nay phải đọc theo mục §0 này.

| Bản vá §6 | Trạng thái | Ghi chú |
|---|:-:|---|
| **Phương án A** — sửa hằng số kỳ vọng ca biên âm | ✅ **Đã áp dụng** | = P-1 trong PATCHLOG |
| Phương án B — TB tự tính kỳ vọng bằng `ref_iir()` | ❌ **Không áp dụng** | Chính §6 cảnh báo nó **làm mất dự phòng đa dạng**; khuyến nghị của tài liệu là *"dùng A ngay"* |
| §7 — ca "đứng yên ở giá trị nhỏ" **thật sự** | 🔴 **Vẫn thiếu** | Đổi cấu trúc luồng testbench, vượt phạm vi "sửa tối thiểu" của lỗi đang xét |
| §8 — làm sạch cảnh báo Icarus (`9'(signed'(x))`) | ❌ **Không áp dụng** | Đụng RTL; cảnh báo là giới hạn công cụ **vô hại** |

**Kết quả xác minh bằng công cụ thật, sau khi vá:**

| Bước | Kết quả |
|---|---|
| Mô hình chuẩn Python | ✅ `G06 golden reference PASS`, mã thoát 0 (**không sửa**) |
| Biên dịch `iverilog -g2012` | ✅ Thành công (vẫn 2 cảnh báo `sorry:` vô hại) |
| Mô phỏng `vvp` | ✅ `G06 TB completed`, `$finish` tại `t = 146 ns` — **đúng bằng con số §6 đã dự đoán**; không còn `FATAL`/`mismatch` |
| Tổng hợp `yosys` + sky130hd | ✅ **54 cell / 9 FF / 482,9632 µm²** — **không đổi**, xác nhận điểm 5 của §6 |

⚠️ Vẫn **không** được phát biểu *"đã kiểm chứng đầy đủ chức năng"*: ca "đứng yên ở giá trị
nhỏ" mà Charter mục 8 bắt buộc **vẫn chưa chạy trên RTL** (xem §7).

---

**Trạng thái mô phỏng RTL:** ⚠️ **RAN_WITH_ISSUES** — chạy được 10/11 lệnh `send()` rồi dừng
ở một assertion.

> **Kết luận trước, lập luận sau:** lỗi nằm ở **TESTBENCH** — một giá trị kỳ vọng viết sai.
> RTL của thầy **đúng**. Mô hình chuẩn Python **đúng**. Bản vá là **một ký tự**.

---

## 1. Trích nguyên văn thông báo lỗi

Từ `05_VERIFICATION/simulation.log` (toàn bộ nội dung file):

```
FATAL: /tmp/.../runs/G06/work/g06_tb.sv:23: y mismatch: got=-52 expected=-51
       Time: 126  Scope: g06_tb.send
```

Từ `05_VERIFICATION/iverilog_compile.log` (toàn bộ nội dung file):

```
/tmp/.../runs/G06/work/g06_iir_half.sv:16: sorry: constant selects in always_* processes
are not currently supported (all bits will be included).
/tmp/.../runs/G06/work/g06_iir_half.sv:16: sorry: constant selects in always_* processes
are not currently supported (all bits will be included).
```

Sửa nguồn tối thiểu đã áp dụng trước khi chạy (ghi trong BRIEF): **không có** (`{}`).

## 2. Đọc thông báo: lỗi ở dòng nào, kiểm cái gì, tại thời điểm nào

`g06_tb.sv` dòng 20–25, bên trong task `send()`:

```systemverilog
@(posedge clk); #1;
assert(valid_out)
    else $fatal(1,"valid_out missing");              // dòng 21 — cờ
assert(y==expected)
    else $fatal(1,"y mismatch: got=%0d expected=%0d", // dòng 23 ← LỖI Ở ĐÂY
                $signed(y),$signed(expected));
```

| Assertion | Dòng | Kiểm | Kết quả tại `Time: 126` |
|---|---:|---|---|
| `valid_out` | 21 | Cờ ra của **DUT** | ✅ **qua** |
| `y == expected` | 23 | Giá trị ra của **DUT** so với **hằng số viết tay trong TB** | ❌ **sai** |

**Điểm mấu chốt:** `expected` **không** đến từ mô hình chuẩn. Nó là một **hằng số viết tay**
truyền vào task `send()`. Nghĩa là assertion này so sánh DUT với **niềm tin của người viết
testbench**, không so với một mô hình độc lập nào. Đây là dữ kiện quyết định cho phán xử ở §4.

## 3. Tái dựng chính xác vector gây lỗi

Mỗi lệnh `send()` tiêu thụ đúng một cạnh lên clock; `always #5 clk = ~clk` ⟹ cạnh lên thứ
`n` tại `t = 5 + 10(n−1)`; TB kiểm tại `+1 ns`.

| # | Cạnh lên | `t` kiểm | Dòng TB | `x` | `y` trước | `x + y` | `y` DUT | `expected` trong TB | |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|:-:|
| 1 | 3 | 26 | 35 | 100 | 0 | 100 | 50 | 50 | ✅ |
| 2 | 4 | 36 | 36 | 100 | 50 | 150 | 75 | 75 | ✅ |
| 3 | 5 | 46 | 37 | 100 | 75 | 175 | 87 | 87 | ✅ |
| 4 | 6 | 56 | 38 | 100 | 87 | 187 | 93 | 93 | ✅ |
| 5 | 7 | 66 | 39 | 100 | 93 | 193 | 96 | 96 | ✅ |
| 6 | 8 | 76 | 40 | 100 | 96 | 196 | 98 | 98 | ✅ |
| 7 | 9 | 86 | 41 | 100 | 98 | 198 | 99 | 99 | ✅ |
| 8 | 10 | 96 | 42 | 100 | 99 | 199 | 99 | 99 | ✅ |
| 9 | 11 | 106 | 45 | 1 | 99 | 100 | 50 | 50 | ✅ |
| 10 | 12 | 116 | 46 | 1 | 50 | 51 | 25 | 25 | ✅ |
| **11** | **13** | **126** | **49** | **−128** | **25** | **−103** | **−52** | **−51** | ❌ |

`Time: 126` trong log khớp **chính xác** với lệnh thứ 11 — `send(-8'sd128, -8'sd51)` ở dòng 49.

**Vì sao 10 vector đầu sống sót?** Vì `>>> 1` và "chia 2 làm tròn về 0" **chỉ khác nhau khi
kết quả âm và lẻ**. Mười tổng đầu đều là `100, 150, 175, 187, 193, 196, 198, 199, 100, 51` —
**toàn bộ đều dương**. Tổng `−103` là **giá trị âm lẻ đầu tiên** trong cả testbench, và nó
lộ lỗi ngay lập tức.

## 4. PHÁN XỬ: lỗi nằm ở **TESTBENCH** (`g06_tb.sv`, dòng 49)

| Ứng viên | Kết luận | Lập luận |
|---|:-:|---|
| **DUT** `g06_iir_half.sv` | ✅ **ĐÚNG** | Nó tính đúng thứ đặc tả yêu cầu: dịch phải **số học** một bit. `−103 >>> 1 = −52`. Xem §5 |
| **Mô hình chuẩn** `reference_model.py` | ✅ **ĐÚNG** | `arshift1(−103) = −103 // 2 = −52` — **khớp DUT**. File này chạy PASS (`python_reference_run.log`), và bản thân tác giả đã chú thích rõ trong mã: *"Python // 2 is floor division, matching arithmetic right shift by one"* |
| **Testbench** `g06_tb.sv` | ❌ **SAI** | Hằng số `-8'sd51` ở dòng 49 được tính bằng **làm tròn về 0** (`−103/2 = −51,5 → −51`), không phải bằng **làm tròn xuống** (`→ −52`). Xem §5 |
| Giới hạn công cụ (Icarus) | ⚠️ **có, nhưng không phải nguyên nhân** | Cảnh báo `sorry: constant selects…` chỉ nói Icarus đưa **tất cả** các bit vào danh sách nhạy của `always_comb`. Bảo thủ và **vô hại**. Xem §8 |

**Kết luận một câu:** *RTL của thầy đúng; mô hình chuẩn Python đúng và khớp RTL; chỉ có một
hằng số kỳ vọng trong testbench được tính bằng quy tắc làm tròn sai.*

### Bằng chứng biểu quyết 2 trên 3

| Mô hình | Tính `⎣−103/2⎦` thế nào | Kết quả |
|---|---|---:|
| DUT (SystemVerilog) | `sum_ext >>> 1` — dịch phải **số học** ⟹ làm tròn xuống | **−52** |
| Golden (Python) | `v // 2` — chia **sàn** ⟹ làm tròn xuống | **−52** |
| Testbench (hằng số viết tay) | `−103 / 2` kiểu C ⟹ làm tròn **về 0** | −51 |

Hai mô hình **độc lập hoàn toàn** (ngôn ngữ khác, tác giả khác, chạy trên công cụ khác) cùng
cho −52. Chỉ có hằng số viết tay khác. Đây là lập luận quyết định.

## 5. Vì sao testbench sai — lập luận từ mã

### 5.1 RTL làm gì

`04_IMPLEMENTATION/rtl/g06_iir_half.sv`, dòng 16–21:

```systemverilog
always_comb begin
    x_ext   = {x[7], x};          // mở rộng dấu 8 → 9 bit
    y_ext   = {y_q[7], y_q};
    sum_ext = x_ext + y_ext;      // cộng 9 bit CÓ DẤU
    y_shift = sum_ext >>> 1;      // ← DỊCH PHẢI SỐ HỌC
end
```

`sum_ext` và `y_shift` đều khai báo `logic signed [8:0]`, nên `>>>` là **arithmetic right
shift**: bit dấu được **nhân bản** vào vị trí trống.

```
  −103 ở 9 bit bù 2:   1 1001 1001
  >>> 1 (nhân bản MSB): 1 1100 1100  =  −52       ← ĐÂY LÀ KẾT QUẢ CỦA RTL
  Kiểm:  −52 × 2 = −104 ≤ −103 < −102 = −51 × 2 ✅ đúng là ⎣−103/2⎦
```

### 5.2 Vì sao `>>> 1` **không phải** "chia 2"

Đây là điểm dạy học trung tâm của cả đề, và Charter mục 2 câu 2 hỏi thẳng về nó:

| Biểu thức | `+103` | `−103` | Quy tắc |
|---|---:|---:|---|
| `>>> 1` (dịch số học) | 51 | **−52** | Làm tròn **XUỐNG** (về −∞) |
| `/ 2` trong C, Java, SystemVerilog | 51 | **−51** | Làm tròn **VỀ 0** |
| `// 2` trong Python | 51 | **−52** | Làm tròn xuống — **khớp `>>>`** |
| `int(-103/2)` trong Python | 51 | **−51** | Làm tròn về 0 — **KHÔNG khớp** |

Hai quy tắc này cho **cùng kết quả** khi số dương, và **khác nhau đúng 1** khi số âm và lẻ.
Người viết testbench gần như chắc chắn đã bấm máy tính `−103 / 2 = −51,5` rồi cắt phần thập
phân — thao tác đúng với số dương, sai với số âm.

### 5.3 Ba mô hình còn lại đều nhất quán

| Nguồn | Mã | Quy tắc |
|---|---|---|
| RTL | `sum_ext >>> 1` | làm tròn xuống |
| Golden Python | `def arshift1(v): return v // 2` kèm chú thích *"matching arithmetic right shift by one"* | làm tròn xuống |
| Golden Python — test hồi quy | `test_negative_shift(): assert arshift1(-5) == -3` | `−5/2 = −2,5` → **−3**, tức làm tròn xuống. Tác giả golden model đã **kiểm chính xác điểm này** |
| Golden Python — test hằng âm | `test_negative_constant()`: `run([-100]*8)` cho `[-50,-75,-88,-94,-97,-99,-100,-100]` | `−175/2 = −87,5` → **−88**, làm tròn xuống |

> 🔎 **Điểm đáng chú ý nhất:** mô hình chuẩn Python có hẳn một test riêng
> (`test_negative_shift`) chỉ để chốt quy tắc làm tròn, và nó **PASS**. Nghĩa là người viết
> golden model đã ý thức rõ về cái bẫy này. Người viết testbench SystemVerilog thì không —
> hoặc là hai người khác nhau, hoặc là cùng một người ở hai thời điểm khác nhau. Đây là lý
> do **dự phòng đa dạng (diverse redundancy)** có giá trị.

## 6. Bản vá tối thiểu

### Phương án A (khuyến nghị) — sửa **một ký tự** trong testbench

```diff
--- a/05_VERIFICATION/testbench/g06_tb.sv
+++ b/05_VERIFICATION/testbench/g06_tb.sv
@@ -48,7 +48,7 @@
         // Boundary negative case.
-        send(-8'sd128,-8'sd51);
+        send(-8'sd128,-8'sd52);
```

**Kiểm bằng tay trước khi chạy:** `x = −128`, `y_q = 25` ⟹ `sum_ext = −103` ⟹
`−103 >>> 1 = −52`. Giá trị mới khớp cả DUT lẫn golden model.

**Dự đoán sau khi vá:** testbench chạy tiếp tới phần khe `valid_in` (dòng 52–54), `valid_out`
phải bằng 0 ở đó (RTL dòng 29 đặt `valid_out <= 1'b0` mặc định), rồi `$display("G06 TB
completed")` và `$finish` tại `t = 146 ns`.

### Phương án B — để testbench **tự tính** kỳ vọng thay vì viết tay

```systemverilog
// Mô hình tham chiếu ngay trong TB, tách khỏi DUT
function automatic logic signed [7:0] ref_iir(input logic signed [7:0] xin,
                                              input logic signed [7:0] yprev);
    logic signed [8:0] s;
    begin
        s = {xin[7], xin} + {yprev[7], yprev};
        ref_iir = s >>> 1;          // dùng ĐÚNG toán tử mà đặc tả quy định
    end
endfunction
```

rồi `send(x)` tự so `y` với `ref_iir(x, y_model)`.

| So sánh | A | B |
|---|---|---|
| Kích thước bản vá | 1 ký tự | ~10 dòng |
| Chống được lỗi tương tự trong tương lai? | ❌ vẫn phải bấm máy tính cho mỗi ca mới | ✅ mọi ca mới tự đúng |
| Giữ được **tính độc lập** với DUT? | ✅ hoàn toàn | ⚠️ **rủi ro**: nếu `ref_iir` chép nguyên logic DUT thì testbench và DUT cùng sai nếu **đặc tả** bị hiểu sai |
| Khuyến nghị | **Dùng A ngay** để mô phỏng chạy hết | Dùng B **kết hợp** với so sánh chéo golden Python (scoreboard) |

> ❗ **Cảnh báo về phương án B**: nó làm mất một phần **dự phòng đa dạng**. Cách tốt nhất là
> giữ hằng số viết tay cho vài ca tiêu biểu (chúng diễn đạt **ý định**), **cộng thêm** một
> scoreboard so với golden Python cho chuỗi ngẫu nhiên. Xem `corner_cases.md` CC-14.

### Sau khi vá, cần chạy lại những gì

| # | Việc | Vì sao |
|---|---|---|
| 1 | `bash 04_IMPLEMENTATION/scripts/01_run_sim.sh` | Chạy hết 11 lệnh `send()` + ca khe `valid_in` |
| 2 | Cập nhật `05_VERIFICATION/test_matrix.csv` | TC-001/TC-002 và `L2-SIM` hiện ghi `XEM known_issues.md` / `RAN_WITH_ISSUES` |
| 3 | Cập nhật `verification_report.md`, `07_TRACEABILITY/limitations.md` §1 hàng 2, và `README.md` §1 | Ba file đang ghi trạng thái "chưa đạt" |
| 4 | Bổ sung các ca còn thiếu (`corner_cases.md` §5, đặc biệt CC-10 và CC-11) | Ca "đứng yên ở giá trị nhỏ" mà Charter mục 8 **bắt buộc** hiện **chưa chạy trên RTL** |
| 5 | **KHÔNG** cần chạy lại tổng hợp / STA / công suất | Bản vá chỉ đụng **testbench**, không đụng RTL ⟹ netlist và mọi số liệu vật lý **không đổi** |

Điểm 5 đáng nói khi bảo vệ: **toàn bộ số liệu 54 cell · 9 FF · 482,9632 µm² · 3,75 ns ·
6,04e-05 W vẫn nguyên giá trị**, vì chúng sinh ra từ RTL chứ không từ testbench.

## 7. Một quan sát **phụ** nhưng đáng ghi: testbench chưa kiểm cái nó tưởng đang kiểm

Ngoài lỗi ở §4, khi đọc testbench còn thấy một vấn đề **độc lập**, không gây `$fatal` nhưng
làm hụt độ phủ:

```systemverilog
// Low-value standing still.
send(8'sd1,8'sd50);
send(8'sd1,8'sd25);
```

Chú thích nói đây là ca **"đứng yên ở giá trị nhỏ"**, nhưng tại thời điểm đó `y_q = 99` — giá
trị **lớn**. Với `x = 1` và `y = 99`, hiệu `x − y = −98` rất lớn, nên bộ lọc **dốc xuống
mạnh** (99 → 50 → 25). Đây là ca **dốc xuống**, không phải ca đứng yên.

Ca đứng yên thật sự cần `y` đã ở **gần 0**:

```systemverilog
// Ca ĐỨNG YÊN thật: reset trước, rồi bơm x=1 liên tục
rst_n = 0; @(posedge clk); #1; rst_n = 1;
repeat (12) send(8'sd1, 8'sd0);     // y phải ĐỨNG YÊN ở 0 suốt 12 mẫu
```

Mô hình chuẩn Python **có** ca này và nó đúng (`test_low_value_standing_still()`:
`run([1]*12)` cho `[0]*12`). Testbench SystemVerilog thì **không**.

> 🔎 Charter mục 10 cảnh báo: *"Chỗ hay tắc: Không phát hiện hiện tượng đứng yên vì chỉ test
> giá trị lớn. Đề nói rõ 'ở giá trị nhỏ'."* — Cảnh báo này đã **ứng nghiệm ngay trong hồ sơ**,
> ở chính file testbench. Đây là bằng chứng sống cho thấy cái bẫy Charter mô tả là có thật.

## 8. Về cảnh báo của Icarus — giới hạn công cụ, không phải lỗi thiết kế

```
g06_iir_half.sv:16: sorry: constant selects in always_* processes are not currently
supported (all bits will be included).
```

| Câu hỏi | Trả lời |
|---|---|
| Dòng 16 là gì? | `always_comb begin` — cảnh báo trỏ vào **đầu khối**, không phải vào một phép cụ thể |
| Cái gì gây ra? | Hai phép **lấy bit hằng** bên trong khối: `x[7]` (dòng 17) và `y_q[7]` (dòng 18). Cảnh báo in **hai lần**, đúng bằng số phép |
| Icarus làm gì? | Không suy được danh sách nhạy chính xác, nên đưa **tất cả** các bit của `x` và `y_q` vào ⟹ **bảo thủ**, khối được tính lại nhiều hơn cần thiết |
| Có làm sai kết quả không? | **Không.** Với `always_comb`, danh sách nhạy rộng hơn chỉ tốn thời gian mô phỏng, giá trị tính ra vẫn đúng |
| Có liên quan tới lỗi ở §4 không? | **Không.** Lỗi ở §4 là một **hằng số kỳ vọng** viết sai trong testbench, nằm ở file khác, độc lập hoàn toàn |
| Yosys có cảnh báo tương tự không? | Không — `yosys.log` không có cảnh báo này. Đây là giới hạn **riêng của Icarus**, và nó đã tổng hợp ra netlist 54 cell bình thường |
| Cần làm gì? | Không bắt buộc. Nếu muốn log sạch: viết `x_ext = 9'(signed'(x));` thay cho `{x[7], x}` |

> Đây là ví dụ tốt để dạy cách đọc log: **một dòng `sorry:` trong log biên dịch không đồng
> nghĩa với "thiết kế sai"**. Phải phân biệt *giới hạn công cụ* với *lỗi thiết kế*, và phải
> lần theo assertion nào **thật sự** thất bại.

## 9. Giá trị dạy học của lỗi này

Đây là một **bẫy kinh điển** và rất đáng giữ lại trong hồ sơ.

| Bài học | Nội dung |
|---|---|
| **BH-1 · `>>> 1` ≠ chia 2** | Dịch phải số học làm tròn **xuống** (về −∞); chia trong C/SV làm tròn **về 0**. Chúng chỉ khác nhau khi tổng **âm và lẻ** — với dữ liệu phân bố đều thì vào khoảng **một phần tư** số tổ hợp. Đây chính là điều Charter mục 2 câu 2 hỏi |
| **BH-2 · Ca dương không bao giờ bắt được lỗi này** | 10 vector đầu đều cho tổng dương ⟹ đều qua. Chỉ vector **âm lẻ đầu tiên** mới lộ lỗi. Đây là lý do Charter mục 8 bắt buộc có **ca biên** |
| **BH-3 · Testbench cũng có thể sai** | Bản năng đầu tiên khi thấy mismatch là đổ lỗi cho DUT. Ở đây DUT **đúng**, và assertion kiểm nó cũng nằm ngay dòng đó — chỉ có hằng số so sánh là sai |
| **BH-4 · Hằng số viết tay là điểm yếu của testbench** | `send(x, expected)` bắt người viết tự tính `expected`. Mỗi lần tính tay là một cơ hội sai. Mô hình chuẩn thì không có vấn đề này vì nó **tính**, không **nhớ** |
| **BH-5 · Dự phòng đa dạng chỉ đích danh kẻ sai** | Có **ba** nguồn chân lý: RTL, golden Python, hằng số TB. Hai trong ba khớp nhau ⟹ cái thứ ba sai. Nếu chỉ có hai thì đã không biết tin ai |
| **BH-6 · Mô phỏng dừng sớm ⟹ độ phủ thật thấp hơn tưởng** | `$fatal` chặn lệnh `send()` thứ 11 và toàn bộ ca khe `valid_in`. Báo cáo "đã kiểm chứng đầy đủ" là **sai sự thật** |
| **BH-7 · Chú thích trong mã không phải bằng chứng** | Chú thích `// Low-value standing still.` ở dòng 44 mô tả một ca mà đoạn mã bên dưới **không thực hiện** (§7). Phải đọc **mã**, không đọc chú thích |
| **BH-8 · Một carry-in đáng giá bao nhiêu** | Toàn bộ vấn đề làm tròn có thể xoá bằng `(x + y + 1) >>> 1`, tốn **0 cell** vì chân `carry-in` vốn đã tồn tại. Xem `03_ARCHITECTURE/tradeoff.md` §4 — nhưng Charter **cố ý giữ** hiện tượng này để dạy |

## 10. Trạng thái bản vá — **CHƯA ÁP DỤNG**

> 🕐 **MỤC NÀY ĐÃ LỖI THỜI kể từ 2026-09-24 — xem §0 ở đầu tài liệu.** Giữ lại nguyên văn để
> thấy trạng thái tại thời điểm phán xử. Phương án A nay **đã áp dụng**.

> ⛔ **Bản vá ở §6 CHƯA được áp dụng vào bất kỳ file nào trong hồ sơ.**
>
> - `05_VERIFICATION/testbench/g06_tb.sv` **giữ nguyên bản gốc của thầy**, kể cả hằng số
>   `-8'sd51` ở dòng 49.
> - `04_IMPLEMENTATION/rtl/g06_iir_half.sv` **không cần sửa** — đã phán xử là đúng.
> - `05_VERIFICATION/golden_model/reference_model.py` **không cần sửa** — đã phán xử là đúng
>   và nó đã PASS.
>
> Mọi thay đổi cần **giảng viên duyệt trước khi sửa**. Tài liệu này chỉ đưa ra phán xử và đề
> xuất, không tự ý can thiệp vào mã nguồn gốc.

## 11. Ảnh hưởng tới kết luận của hồ sơ

| Khẳng định | Còn đứng vững? | Vì sao |
|---|:-:|---|
| G06 có **9 flip-flop**, đúng phân loại Tuần tự và đúng dự kiến Charter mục 10 (9–10) | ✅ | Từ `synth_stat.txt` và `power_report.txt`, không liên quan mô phỏng |
| 54 cell · 482,9632 µm² | ✅ | Từ Yosys, sinh từ **RTL** |
| Đường tới hạn `x[1] → _98_`, 3,75 ns, slack 6,18 ns | ✅ | Từ OpenSTA trên netlist |
| Công suất ước lượng 6,04e-05 W (tuần tự 71,2 %) | ✅ | Từ OpenSTA |
| Tiết kiệm 6,4× flip-flop so với G01 | ✅ | So hai `synth_stat.txt`, cùng tổ hợp công cụ |
| `y_q` được Yosys hợp nhất vào `y` | ✅ | Netlist không có wire `\y_q[…]`; chỉ 9 FF |
| RTL đúng với đặc tả | ⚠️ **có cơ sở mạnh nhưng chưa khép kín** | Golden Python độc lập cho **cùng** kết quả tại vector gây lỗi, và 10/11 vector trước đó đều khớp. Nhưng mô phỏng RTL **chưa chạy hết**, và chưa có scoreboard vét cạn |
| "Đã kiểm chứng đầy đủ chức năng" | ❌ **KHÔNG được phát biểu** | Mô phỏng dừng ở lệnh `send()` thứ 11/11; ca khe `valid_in` chưa chạy; ca "đứng yên ở giá trị nhỏ" mà Charter mục 8 **bắt buộc** chưa chạy trên RTL (§7) |
| "Đã kiểm ca biên âm" | ⚠️ **một nửa** | Ca `x = −128` **đã được đưa vào**, và nó **đã làm đúng việc của ca biên** — lộ ra một lỗi. Nhưng vì lỗi nằm ở giá trị kỳ vọng, ca này **chưa xác nhận** được hành vi DUT là đúng bằng mô phỏng (chỉ xác nhận được bằng đối chiếu golden model) |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24 · Truy vết: REQ-G06-010, REQ-G06-012, Charter mục 2, mục 6, mục 8, mục 10.*
