# G06 — Bộ lọc thông thấp IIR bậc một hệ số 1/2 · Ghi chú thực hiện

> ⚠️ Mô phỏng RTL của đề này **dừng ở một assertion**. Phán xử đầy đủ:
> `05_VERIFICATION/known_issues.md`. Kết luận ngắn: **lỗi nằm ở testbench**, RTL đúng.

## 1. Bài toán này thực chất là gì

Đề yêu cầu một bộ lọc thông thấp, nhưng điều đáng học không nằm ở chữ "lọc". Nó nằm ở chỗ
**đây là đề đầu tiên trong nhóm G có vòng hồi tiếp**, và vòng đó đổi toàn bộ cách suy nghĩ về
thiết kế.

Với một bộ lọc FIR (G01: trung bình trượt 4 điểm), đầu ra là hàm của **bốn mẫu gần nhất**.
Muốn biết `y[n]` chỉ cần nhìn một cửa sổ hữu hạn về quá khứ. Với IIR, `y[n]` phụ thuộc vào
`y[n−1]`, mà `y[n−1]` lại phụ thuộc `y[n−2]`… — **toàn bộ lịch sử** được nén vào một con số
8 bit. Đó là lý do G06 chỉ cần **9 flip-flop** trong khi G01 cần **58**: tỷ lệ **6,4 lần**,
đo được từ hai `synth_stat.txt`.

Bối cảnh (Charter mục 1): làm trơn tín hiệu cảm biến ánh sáng để chỉnh độ sáng màn hình.
Cảm biến ánh sáng có nhiễu và có đột biến ngắn (bóng tay, đèn flash); đưa thẳng vào điều
khiển độ sáng thì màn hình **nhấp nháy**. Bộ lọc biến đột biến thành thay đổi từ từ.

Nhưng cái giá của sự rẻ đó là hai thứ mà Charter mục 2 hỏi thẳng: **vấn đề làm tròn** khi
dịch phải số có dấu, và hiện tượng **đứng yên** ở giá trị nhỏ. Hai thứ này mới là nội dung
thật của đề.

## 2. Bản chất kỹ thuật — cơ chế hoạt động

### 2.1 Vì sao hệ số 1/2 lại đặc biệt rẻ

```
   y[n] = ⎣ (x[n] + y[n−1]) / 2 ⎦
```

Phép chia cho 2 hiện thực bằng `>>> 1`, mà **dịch theo hằng số không tốn cổng logic nào** —
nó chỉ là **cách đấu dây khác đi**: `y_shift[i] = sum_ext[i+1]`. Bằng chứng: trong 54 cell
của netlist **không có cell dịch nào**, và không có bộ nhân nào. Toàn bộ 45 cell tổ hợp là
**một bộ cộng 9 bit** cộng vài cổng mux giữ.

Đổi hệ số thành `0,3` thì cần một bộ nhân 8×8 (≥ 60 cell) hoặc nhiều tầng shift-add. Đó là
lý do Charter chốt hệ số `1/2` và liệt "hệ số lập trình được" vào ngoài phạm vi.

### 2.2 Vòng hồi tiếp là thứ giới hạn tần số

Đây là cơ chế quan trọng nhất và là nội dung Charter mục 9 yêu cầu:

```
  y[n] phải ỔN ĐỊNH HOÀN TOÀN trước cạnh lên kế tiếp,
  vì chính nó là đầu vào tính y[n+1].

  T_clk  ≥  t_ckq(y[0])  +  t_cộng_9bit  +  t_mux_giữ  +  t_setup(y[7])  +  t_skew
```

Không thể pipeline. Chèn một thanh ghi vào giữa vòng thì `y[n]` sẽ dùng `y[n−2]` thay vì
`y[n−1]` ⟹ **hàm truyền đổi**, không còn là bộ lọc đã đặc tả. Đây là điểm khác cơ bản với
FIR, nơi có thể chèn thanh ghi ở bất kỳ đâu mà chỉ tăng độ trễ chứ không đổi hàm truyền.

Trong bộ cộng, nút thắt là **chuỗi carry nối tiếp**: `c[i+1]` cần `c[i]` đã ổn định. Bằng
chứng cấu trúc đọc thẳng từ STA — slack theo từng bit của `y` **giảm đơn điệu**:

```
  y[0] 8,51 → y[1] 8,29 → y[2] 7,94 → y[3] 7,41 → y[4] 7,03 → y[5] 6,69 → y[6] 6,31 → y[7] 6,18 ns
```

Nếu tool đã dựng carry-lookahead thì các số này sẽ gần bằng nhau. Chúng giảm đều ⟹ **ripple-carry**.

### 2.3 `>>> 1` làm tròn XUỐNG, và đó là gốc của mọi hiện tượng lạ

Dịch phải **số học** nhân bản bit dấu, nên nó tương đương chia 2 **rồi làm tròn về −∞**:

```
  −103 (9 bit):  1 1001 1001
  >>> 1:         1 1100 1100  =  −52     (KHÔNG phải −51)
```

Từ một dòng này suy ra được cả ba hiện tượng mà đề quan tâm. Gọi `Δ = ⎣(x − y)/2⎦` là bước
nhảy mỗi mẫu:

| `x − y` | `Δ` | Hệ quả |
|---:|---:|---|
| `≥ +2` | `≥ +1` | bộ lọc đi lên bình thường |
| `+1` | **0** | **ĐỨNG YÊN** — không nhích được |
| `0` | 0 | điểm bất động |
| `−1` | **−1** | vẫn giảm được 1 |
| `≤ −2` | `≤ −1` | đi xuống bình thường |

Cột `+1` so với cột `−1` là **bất đối xứng**, và nó sinh ra:

1. **Đáp ứng bước nhảy dương dừng ở `x − 1`**, không đạt `x`. Với `x = 100`: dãy 50, 75, 87,
   93, 96, 98, 99, **99** — kẹt ở 99.
2. **Bước nhảy âm thì đạt đúng `x`**. Với `x = −100`: −50, −75, −88, −94, −97, −99, **−100**.
3. **Đứng yên ở giá trị nhỏ**: `x = 1`, `y = 0` ⟹ `Δ = 0` ⟹ bộ lọc **không làm gì cả**, mãi
   mãi. Golden model xác nhận: `run([1]*12)` cho `[0]*12`.
4. **Bẫy nguy hiểm nhất, chưa ai kiểm**: `y = −1`, `x = 0` ⟹ `x − y = +1` ⟹ `Δ = 0` ⟹ bộ lọc
   **kẹt ở −1 vĩnh viễn**. Sau mỗi lần tín hiệu đi xuống, nó để lại một sai lệch DC −1 LSB
   không bao giờ tự sạch.

## 3. Đọc mã nguồn: RTL làm gì, từng dòng quan trọng

Toàn bộ thiết kế là 38 dòng. Hai đoạn quyết định tất cả.

**Đoạn 1 — datapath (dòng 16–21), năm dòng mà ba dòng tốn 0 cell:**

```systemverilog
always_comb begin
    x_ext   = {x[7], x};        // mở rộng dấu 8→9: ĐẤU DÂY, 0 cell
    y_ext   = {y_q[7], y_q};    // ĐẤU DÂY, 0 cell
    sum_ext = x_ext + y_ext;    // ← TOÀN BỘ 45 cell tổ hợp nằm ở ĐÂY
    y_shift = sum_ext >>> 1;    // ĐẤU DÂY, 0 cell
end
```

Mở rộng dấu lên 9 bit **trước** khi cộng là chi tiết bảo đảm **không bao giờ tràn**: `x` và
`y_q` đều thuộc `[−128, 127]`, tổng thuộc `[−256, 254]`, vừa khít 9 bit; sau `>>> 1` kết quả
về `[−128, 127]`, vừa khít 8 bit. Golden model kiểm điều này **vét cạn** chứ không lấy mẫu
(`test_feedback_bound()`). Đây là thiết kế **đúng bằng xây dựng** — không cần logic bão hoà,
không cần cờ tràn, và không tồn tại ca kiểm thử nào làm nó tràn.

**Đoạn 2 — hai lệnh gán giống hệt nhau (dòng 30–34):**

```systemverilog
if (valid_in) begin
    y_q       <= y_shift[7:0];   // trạng thái nội bộ
    y         <= y_shift[7:0];   // cổng ra — CÙNG nguồn, CÙNG enable, CÙNG reset
    valid_out <= 1'b1;
end
```

Đọc RTL bằng tay ta đếm **17** flip-flop (8 + 8 + 1). Netlist chỉ có **9**. Yosys đã **hợp
nhất `y_q` vào `y`** vì hai thanh ghi giống nhau về mọi mặt. Bằng chứng: netlist **không có**
wire `\y_q[…]` nào; chín `dfxtp_1` là `y[0..7]` và `valid_out`.

Hệ quả cần biết: ở mức RTL, `y_q` là trạng thái **nội bộ** và `y` là **cổng ra**; ở mức
netlist chúng là **cùng một dây**. Vòng hồi tiếp thật sự chạy **qua chân ra `y`**.

Một chi tiết nữa: `always_ff @(posedge clk)` **không** có `or negedge rst_n` ⟹ reset **đồng
bộ**. Bằng chứng mạnh hơn ở netlist: cả 9 flip-flop là `dfxtp_1` — loại **không có** chân
reset. Ở mạch IIR điều này quan trọng hơn bình thường: nếu `y_q` khởi động ở `X`, giá trị đó
quay vòng mãi mãi và **không bao giờ tự sạch**.

## 4. Vì sao chọn kiến trúc này

| Quyết định | Lý do | Bằng chứng |
|---|---|---|
| IIR thay vì FIR | Bộ nhớ O(1) thay vì O(N) | 9 FF so với 58 FF của G01 — **6,4 lần** |
| Hệ số `2^−1` | Hiện thực bằng đấu dây, **0 cell** | Netlist không có cell dịch nào |
| Ripple-carry | Yosys chọn mặc định; với slack **6,18 ns / 10 ns** thì không cần nhanh hơn | Slack giảm đơn điệu theo bit |
| Mở rộng dấu 9 bit | Không tràn **bằng xây dựng**, thay vì xử lý tràn bằng logic bão hoà | `test_feedback_bound()` vét cạn |
| Dùng `>>>` (floor) thay vì làm tròn | **Có chủ ý** — Charter mục 2 câu 2 và mục 10 lấy hiện tượng này làm nội dung dạy | Charter |

## 5. Cách thực hiện — lộ trình 8 bước từ đặc tả tới GDSII

| # | Bước | Trạng thái | Bằng chứng |
|---|---|:-:|---|
| 1 | Suy công thức và bảng hành vi từ Charter | ✅ | `functional_spec.md` §3 |
| 2 | Viết mô hình chuẩn Python độc lập | ✅ **PASS** (10 test, có vét cạn vòng hồi tiếp) | `python_reference_run.log` |
| 3 | Viết RTL bám ràng buộc "bậc một, hệ số 1/2, không bộ nhân" | ✅ | `g06_iir_half.sv`, 38 dòng |
| 4 | Viết testbench tự kiểm | ⚠️ **RAN_WITH_ISSUES** — dừng ở lệnh `send()` thứ 11 | `simulation.log`; phán xử ở `known_issues.md` |
| 5 | Tổng hợp ra standard cell sky130 | ✅ | 54 cell · 9 FF · 482,9632 µm² |
| 6 | STA với SDC (10 ns, IO delay 1 ns) | ✅ | 3,75 ns · slack 6,18 ns · WNS/TNS 0,00 |
| 7 | Ước lượng công suất | ✅ | 6,04e-05 W (tuần tự 71,2 %) |
| 8 | Place & route → DRC/LVS → GDSII | ⬜ **chưa chạy** | cần LibreLane + PDK sky130A |

Bước 4 **không** làm hỏng bước 5–7: tổng hợp, STA và công suất đều chạy từ **RTL**, không từ
testbench. Và phán xử cho thấy lỗi nằm ở testbench, nên mọi số liệu vật lý giữ nguyên giá trị.

## 6. Số liệu thật đã đo được và cách đọc chúng

| Số | Giá trị | **Chứng minh** điều gì | **KHÔNG** chứng minh điều gì |
|---|---:|---|---|
| Số cell | 54 | Thiết kế tổng hợp được; **nhỏ hơn nhiều** ước lượng Charter (180–260) vì đây là module lõi trần | Không nói gì về chức năng |
| Flip-flop | **9** | Đúng dự kiến Charter mục 10 (9–10) ⟹ chỉ nhớ `y[n−1]` + 1 cờ. **Và** `y_q` đã bị hợp nhất vào `y` | Không chứng minh 9 là tối thiểu tuyệt đối (bỏ `valid_out` thì còn 8) |
| Diện tích | 482,9632 µm² | Vừa một ô 1×1, còn rất nhiều chỗ trống | Chưa gồm dây, chưa gồm lớp vỏ `tt_um_*` |
| Thanh ghi / tổ hợp | 180,17 µm² (37,3 %) / 302,79 µm² (62,7 %) | Ở G06 phần **tổ hợp** chiếm đa số — ngược với G05 (42,9 % / 57,1 %) và G07 | Tỷ lệ này tính từ `dfxtp_1 = 20,0192 µm²` trong Liberty, không phải từ báo cáo riêng |
| Đường tới hạn | `x[1] → y[7]`, 3,75 ns | Nút thắt là **chuỗi carry của bộ cộng**: 5 `maj3_1` = 1,95 ns = **71 %** của 2,75 ns độ trễ cell | **Không** nghĩa là "chạy được ở 266 MHz". Gồm 1,00 ns IO delay **giả định**, chưa có dây, 1 góc PVT |
| Slack setup | 6,18 ns | Còn dư nhiều với chu kỳ giả định 10 ns | Sẽ co lại sau P&R và ở góc `ss` |
| Slack hold | 0,47 ns | Không vi phạm hold ở mức sau tổng hợp | Tính với **clock lý tưởng, skew = 0** |
| Công suất | 6,04e-05 W (tuần tự **71,2 %**) | Dù chỉ 9 FF, chúng vẫn là nhóm tốn nhất | **Ước lượng** với hoạt động mặc định, không từ VCD |
| So với G01 | 6,4× ít FF · 5,4× ít diện tích | Vượt dự đoán Charter mục 10 ("hơn 3 lần") | Hợp lệ vì **cùng** tổ hợp công cụ; không được so chéo với đề chạy môi trường khác |
| Mô phỏng RTL | ⚠️ dừng ở lệnh 11/11 | Mười vector đầu **đều khớp** DUT ↔ TB ↔ mô hình | **Không** chứng minh chức năng đầy đủ. Ca khe `valid_in` và ca "đứng yên" chưa chạy |

## 7. Trả lời các câu hỏi kỹ thuật của Charter (mục 2)

**(1) IIR bậc một chỉ cần nhớ `y[n−1]` — so với G01 (nhớ 4 mẫu) thì tiết kiệm bao nhiêu ô nhớ?**

Đo được, cùng tổ hợp công cụ: G01 có **58** flip-flop / 260 cell / 2623,7664 µm²; G06 có
**9** flip-flop / 54 cell / 482,9632 µm². Tỷ lệ: **6,4 lần** về flip-flop, **4,8 lần** về
cell, **5,4 lần** về diện tích. Tiết kiệm tuyệt đối: **2140,80 µm²**. Charter mục 10 dự đoán
"hơn 3 lần" — số thật **vượt** dự đoán, vì G01 không chỉ cần 4 thanh ghi mẫu mà còn cần
thanh ghi tổng và các tầng trung gian.

**(2) Dịch phải số có dấu gây vấn đề làm tròn gì, và hiện tượng "đứng yên" ở giá trị nhỏ là gì?**

`>>> 1` làm tròn **xuống** (về −∞), khác với `/2` vốn làm tròn **về 0**; hai quy tắc chỉ khác
nhau khi kết quả **âm và lẻ**. Hệ quả: bước nhảy dương hội tụ về `x − 1` (thiếu 1 LSB), bước
nhảy âm hội tụ về đúng `x`. "Đứng yên" là khi `x − y = +1`: `⎣1/2⎦ = 0` nên bộ lọc **không
nhích được** — với `x = 1`, `y = 0` thì `y` đứng yên ở 0 vĩnh viễn (golden:
`test_low_value_standing_still()`). Trường hợp nặng nhất: `y = −1`, `x = 0` ⟹ kẹt ở −1 mãi
mãi, tạo sai lệch DC không tự sạch.

Bằng chứng sống trong chính hồ sơ này: lỗi mô phỏng `got=-52 expected=-51` **chính là** cái
bẫy làm tròn này, và nó xuất hiện ở **giá trị âm lẻ đầu tiên** của cả testbench.

**(3) Đáp ứng bước nhảy tiệm cận theo quy luật nào — quan sát trên waveform?**

Sai số giảm **một nửa mỗi mẫu**: với `x = 100`, sai số đi 50 → 25 → 13 → 7 → 4 → 2 → 1 → 1
(waveform ở `03_ARCHITECTURE/timing_diagram.md` §3, cạnh lên 3 tới 10). Đây là quy luật **mũ**
với hằng số thời gian `τ = 1/ln 2 ≈ 1,44` mẫu. Thời gian đạt 1 LSB: `log₂(100) ≈ 6,6` ⟹
**7 mẫu** — khớp chính xác với quan sát. Hàm truyền `H(z) = 0,5/(1 − 0,5·z⁻¹)`, cực tại
`z = 0,5`, tần số cắt −3 dB `f_c ≈ 0,115·f_s`.

Chú ý sai số dừng ở **1** chứ không về 0 — đó là §4.1 ở trên.

## 8. Trả lời câu phân tích riêng (Charter mục 9)

> *"Bộ lọc IIR có vòng hồi tiếp, nên đường tới hạn đi từ thanh ghi qua logic rồi quay lại
> chính thanh ghi đó. Chỉ rõ vòng này trong báo cáo STA và giải thích vì sao nó giới hạn tần
> số tối đa."*

**Phát hiện đáng chú ý nhất của cả đề:** `timing_report_max.txt` **không in ra vòng hồi tiếp**.
Cả 10 đường trong báo cáo đều là `x[1] → FF` (8 đường) hoặc `FF → y[…]` (2 đường). Không có
đường nào có startpoint **và** endpoint đều là flip-flop.

**Vì sao:** script dùng `report_checks -path_delay max -group_path_count 10`, mà OpenSTA mặc
định `-endpoint_path_count 1` — **chỉ in đường tệ nhất cho mỗi endpoint**. Với endpoint `_98_`
(= `y[7]`) có hai đường cạnh tranh:

| Đường | Xuất phát tại | Ghi chú |
|---|---|---|
| ① `x[1] → cộng → y[7]` | `t = 1,00 ns` | 1,00 ns là `input external delay`, một **giả định SDC**, không phải silicon |
| ② `y[0] → cộng → y[7]` — **vòng hồi tiếp** | `t ≈ 0,29 ns` (`clk→Q`) | bị ① che vì ① tệ hơn ~0,7 ns |

**Bằng chứng vòng hồi tiếp vẫn tồn tại:** `timing_report_min.txt` có **cả 5/5** đường dạng
`_9x_ → _9x_` — cùng một flip-flop vừa là startpoint vừa là endpoint. Đó chính là định nghĩa
của vòng hồi tiếp, chỉ hiện ra ở phía hold:

```
  _98_/CLK ──0,29──▶ _98_/Q ──0,06──▶ _87_/Y ──0,06──▶ _89_/Y ──▶ _98_/D   (arrival 0,41 ns)
```

**Vì sao vòng giới hạn tần số:** `y[n]` phải ổn định hoàn toàn trước cạnh lên kế tiếp vì
chính nó là đầu vào tính `y[n+1]`. Không thể pipeline mà không đổi hàm truyền. Cách duy nhất
rút ngắn là làm bộ cộng nhanh hơn (carry-lookahead thay ripple-carry) — xem `tradeoff.md` §3.

**Việc cần làm để khép kín** (chưa chạy):

```tcl
report_checks -path_delay max -group_path_count 30 -endpoint_path_count 5
# hoặc chỉ đích danh:
report_checks -from [get_pins _91_/CLK] -to [get_pins _98_/D] -path_delay max
```

## 9. Những chỗ sinh viên hay sai và cách phát hiện

| # | Sai lầm | Hậu quả | **Phát hiện bằng bằng chứng nào** |
|---|---|---|---|
| 1 | Tính kỳ vọng bằng `−103/2 = −51` (làm tròn về 0) | Testbench báo lỗi trong khi DUT đúng | **Đã xảy ra thật** — `simulation.log`: `got=-52 expected=-51`. Đối chiếu golden Python (`arshift1(-103) = -52`) là cách phán xử |
| 2 | Dùng `>>` (dịch logic) thay `>>>` | Số âm biến thành số dương rất lớn | Ca `x = −128` sẽ cho kết quả dương. Ca biên bắt được ngay |
| 3 | Quên mở rộng dấu trước khi cộng | Tràn 8 bit: `100 + 99 = 199` thành `−57` | Ca bước nhảy dương sẽ sai ngay mẫu thứ 8 |
| 4 | Kiểm ca "đứng yên" khi `y` đang **lớn** | Ca không kiểm cái nó tưởng đang kiểm | **Đã xảy ra thật** — `g06_tb.sv` dòng 44–46, xem `known_issues.md` §7. Phát hiện bằng cách tính `x − y` tại thời điểm đó: `1 − 99 = −98`, không phải giá trị nhỏ |
| 5 | Nạp `y_q` vô điều kiện (bỏ `if (valid_in)`) | Bộ lọc **tự chạy** khi không có mẫu mới, trôi về 0 hoặc −1 | Ca khe `valid_in` (TB dòng 52–54) — nhưng ca này **chưa chạy** vì `$fatal` chặn trước |
| 6 | Tưởng `>>> 1` cần một bộ dịch | Ước lượng diện tích sai | Netlist: **0 cell dịch** trong 54 cell. Dịch theo hằng số là đấu dây |
| 7 | Tưởng đếm được 17 FF từ RTL | Nhầm khi đối chiếu với Charter mục 10 | `synth_stat.txt` cho **9**. Yosys hợp nhất `y_q` vào `y` vì cùng D/enable/reset |
| 8 | Cho `valid_in` là **mức** thay vì **xung** | Bộ lọc nhanh gấp k lần đặc tả ⟹ `f_c` sai | **Rất khó thấy** — waveform trông "hợp lý", chỉ đếm chu kỳ mới phát hiện. Ca này **chưa có** |
| 9 | Kết luận "đường tới hạn là `x[1] → y[7]`, vậy vòng hồi tiếp không quan trọng" | Trả lời sai Charter mục 9 | Đọc `timing_report_min.txt`: **5/5** đường đều là `_9x_ → _9x_`. Vòng tồn tại, chỉ bị che ở báo cáo setup |
| 10 | Tưởng `X` trong `x` chỉ ảnh hưởng một mẫu | Ở IIR, `X` lan **vĩnh viễn** qua vòng hồi tiếp | Chạy mô phỏng với một mẫu `8'hxx` rồi quan sát `y` ở 50 chu kỳ sau |

## 10. Câu hỏi mentor nên đặt khi bảo vệ

| # | Câu hỏi | Đáp án mong đợi |
|---|---|---|
| 1 | Mô phỏng báo `got=-52 expected=-51`. Ai sai — DUT, golden model, hay testbench? | **Testbench.** DUT cho −52 (`>>> 1` làm tròn xuống); golden Python cho −52 (`// 2`). Hai mô hình độc lập khớp nhau; chỉ hằng số viết tay trong TB sai |
| 2 | Vì sao lỗi chỉ lộ ra ở mẫu thứ 11? | Vì `>>>` và `/2` chỉ khác nhau khi tổng **âm và lẻ**. Mười tổng đầu đều dương. `−103` là giá trị âm lẻ **đầu tiên** |
| 3 | RTL có 17 lệnh gán thanh ghi nhưng netlist chỉ có 9 FF. Giải thích | Yosys hợp nhất `y_q` vào `y` — cùng `D`, cùng enable, cùng reset. Netlist không có wire `\y_q[…]` |
| 4 | Charter mục 9 bảo chỉ vòng hồi tiếp trong báo cáo STA. Chỉ đi | Báo cáo **setup** không in nó (mỗi endpoint chỉ in đường tệ nhất, mà đường từ cổng vào có thêm 1,00 ns IO delay). Báo cáo **hold** in đủ: 5/5 đường đều `_9x_ → _9x_` |
| 5 | Vì sao không pipeline bộ lọc để chạy nhanh hơn? | Vì đích của đường **chính là** nguồn của nó. Chèn thanh ghi ⟹ `y[n]` dùng `y[n−2]` ⟹ đổi hàm truyền. Đây là đặc tính chung của mọi IIR |
| 6 | Đáp ứng bước nhảy `x = 100` dừng ở 99. Lỗi hay đúng? | **Đúng theo đặc tả.** Điểm bất động của `y = ⎣(100+y)/2⎦` là 99. Hệ quả của làm tròn xuống, không phải lỗi |
| 7 | Cho `x = 1` từ trạng thái reset thì `y` bằng bao nhiêu sau 100 mẫu? | **0.** `⎣1/2⎦ = 0` ⟹ đứng yên vĩnh viễn. Đây là hiện tượng Charter mục 2 câu 2 hỏi |
| 8 | Có cách nào xoá hiện tượng đứng yên mà không tốn diện tích? | Có: `(x + y + 1) >>> 1` — đặt `carry-in = 1` cho bộ cộng, chân vốn đã tồn tại ⟹ **0 cell thêm**. Nhưng chỉ lật bất đối xứng sang phía âm, không xoá hẳn |
| 9 | Vì sao startpoint là `x[1]` chứ không phải `x[0]`? | Vì `sum_ext[0]` bị `>>> 1` **vứt bỏ**, không tới flip-flop nào; và carry tầng 0 (`x[0] AND y[0]`) không có carry-in nên nhanh hơn tầng đầy đủ |
| 10 | Slack của `y[0]` là 8,51 ns, của `y[7]` là 6,18 ns. Điều này nói lên cấu trúc gì? | **Ripple-carry**. Slack giảm **đơn điệu** theo bit là chữ ký của chuỗi carry nối tiếp. Carry-lookahead sẽ cho slack gần bằng nhau |
| 11 | Mô phỏng chưa chạy hết. Vậy 54 cell · 3,75 ns còn đáng tin không? | **Có.** Tổng hợp và STA chạy từ **RTL**, không từ testbench. Và phán xử cho thấy RTL đúng |
| 12 | Hồ sơ đã thoả Charter mục 4 chưa? | **Chưa.** Chưa có lớp vỏ `tt_um_*`, nên "lỗi ánh xạ `uio[0]` vừa vào vừa ra" mà Charter yêu cầu sửa **chưa được sửa ở đâu cả**. Ngân sách chân thì đủ (18/24) |

## 11. Giới hạn: đã chứng minh được gì, chưa chứng minh được gì

**Đã chứng minh:**
- Kiến trúc đúng ràng buộc đề: **bậc một** (một thanh ghi trạng thái), **hệ số 1/2** (dịch
  bit, 0 cell, không bộ nhân), **có hồi tiếp** — bằng chứng đọc từ RTL và netlist.
- **Không bao giờ tràn** — chứng minh bằng xây dựng (mở rộng dấu 9 bit) và kiểm vét cạn ở
  golden model.
- Tiết kiệm **6,4 lần** flip-flop và **5,4 lần** diện tích so với G01, cùng tổ hợp công cụ.
- Vòng hồi tiếp tồn tại và được STA nhìn thấy — bằng chứng ở `timing_report_min.txt` (5/5
  đường `_9x_ → _9x_`).
- Số liệu cấu trúc và thời gian thật ở mức **sau tổng hợp**: 54 cell · 9 FF · 482,9632 µm² ·
  3,75 ns · slack 6,18 ns · 6,04e-05 W.
- Lỗi mô phỏng đã được **phán xử**: nằm ở testbench, có bản vá một ký tự, RTL không cần sửa.

**Chưa chứng minh:**
- Chức năng RTL đầy đủ — mô phỏng **dừng ở lệnh `send()` thứ 11/11**; ca khe `valid_in` chưa
  chạy; ca "đứng yên ở giá trị nhỏ" mà Charter mục 8 **bắt buộc** chưa chạy trên RTL.
- **Độ trễ của chính vòng hồi tiếp** — báo cáo STA hiện tại chưa in ra con số đó.
- Netlist tương đương chức năng với RTL — chưa mô phỏng gate-level.
- Độ trễ thật sau routing, biên an toàn qua các góc PVT, công suất từ VCD thật.
- Tuân thủ Charter mục 4 — chưa có lớp vỏ `tt_um_*`, chưa chốt đánh số lại `uio[0]`.
- Cách hiểu `x`/`y` là có dấu hay không dấu — **chưa được chốt ở giao diện**.

**Không được khẳng định** (Charter mục 3): sign-off, tape-out, chế tạo, kiểm tra sau chế tạo,
"chạy được ở XXX MHz", "đã tối ưu netlist", "đã kiểm chứng đầy đủ chức năng".

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
