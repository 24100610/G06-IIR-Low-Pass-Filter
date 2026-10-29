# G06 · Đường dữ liệu (Datapath)

---

## 1. Đặc điểm datapath của G06: **một vòng kín, không có nhánh nào khác**

G06 là ví dụ sạch nhất trong cả họ đề về một datapath **hồi tiếp**. Không có mux chọn chế độ,
không có bộ đếm, không có nhánh phụ thuộc dữ liệu. Chỉ có **một vòng**:

```
   ┌──────────────────── VÒNG KÍN: ĐÂY LÀ TOÀN BỘ THIẾT KẾ ───────────────────┐
   │                                                                           │
   │    y[7:0] ──▶ mở rộng dấu ──▶ ┌──────┐                                    │
   │    (trạng thái)     (dây)     │ CỘNG │──▶ sum_ext[8:0] ──▶ >>>1 ──▶ MUX ──┘
   │                               │ 9 bit│                     (dây)    GIỮ
   │    x[7:0] ──▶ mở rộng dấu ──▶ └──────┘                              (en=valid_in)
   │    (dữ liệu vào)    (dây)
   │
   └── Độ trễ vòng = độ trễ của BỘ CỘNG + MUX GIỮ.  Không có gì khác.
```

Hệ quả then chốt, và là câu trả lời cho Charter mục 9: **tần số tối đa của G06 bị giới hạn
bởi chính vòng này**, vì kết quả `y[n]` phải **ổn định hoàn toàn** trước cạnh lên tiếp theo
để làm đầu vào cho `y[n+1]`. Không có cách nào "giấu" độ trễ này bằng pipeline, trừ khi đổi
thuật toán (xem `tradeoff.md` §5).

## 2. Bảng các đường dữ liệu

| Đường | Bit | Từ | Đến | Bản chất | Tốn cell? |
|---|---:|---|---|---|:-:|
| `x[7:0]` | 8 | cổng vào | bộ cộng | Dữ liệu vào | — |
| `x_ext[8:0]` | 9 | `{x[7], x}` | bộ cộng | **Mở rộng dấu** — chỉ đấu dây | **0** |
| `y_q[7:0]` = `y[7:0]` | 8 | REG (chính là cổng ra) | bộ cộng | **Trạng thái hồi tiếp** — vế thứ hai | — |
| `y_ext[8:0]` | 9 | `{y_q[7], y_q}` | bộ cộng | Mở rộng dấu | **0** |
| `sum_ext[8:0]` | 9 | bộ cộng | bộ dịch | **Tổng, 9 bit — không bao giờ tràn** (INV-3) | 45 cell tổ hợp |
| `carry[8:1]` | 8 | nội bộ bộ cộng | tầng kế tiếp | **Đường nối tiếp — nguồn gốc độ trễ** | `maj3_1 × 5` |
| `y_shift[8:0]` | 9 | `sum_ext >>> 1` | mux giữ | **Chỉ đổi cách đấu dây**: `y_shift[i] = sum_ext[i+1]` | **0** |
| `y_shift[7:0]` | 8 | cắt bit | REG `y` | Cắt **không mất thông tin** (INV-4) | 0 |
| `valid_in` | 1 | cổng vào | enable của 9 FF | **Điều khiển**, fanout 9 | mux giữ |

> 🔎 **Ba đường tốn 0 cell** (`x_ext`, `y_ext`, `y_shift`) chiếm một nửa số dòng RTL nhưng
> **không** sinh ra phần cứng nào. Đây là bài học đáng dạy: trong RTL, "mở rộng dấu" và
> "dịch theo hằng số" là **cách đọc dây khác đi**, không phải phép tính. Sinh viên hay tưởng
> `>>> 1` tốn một bộ dịch — netlist chứng minh ngược lại: không có cell dịch nào trong 54 cell.

## 3. Đồ thị phụ thuộc và độ sâu logic

```
 mức 0    x[0], y[0]  ──────────────────────────┐
              │                                  │
 mức 1    c1 = maj(x[0], y[0], 0)                ├──▶ sum[0] ──▶ (BỊ VỨT BỎ bởi >>>1)
              │                                  │
 mức 2    c2 = maj(x[1], y[1], c1)  ─────────────┼──▶ sum[1] ──▶ y_shift[0] ──▶ y[0]
              │                                  │                              ↑ NÔNG NHẤT
 mức 3    c3 ─┼──▶ sum[2] ──▶ y_shift[1] ──▶ y[1]
              │
 mức 4    c4 ─┼──▶ sum[3] ─▶ y[2]
 mức 5    c5 ─┼──▶ sum[4] ─▶ y[3]
 mức 6    c6 ─┼──▶ sum[5] ─▶ y[4]
 mức 7    c7 ─┼──▶ sum[6] ─▶ y[5]
 mức 8    c8 ─┼──▶ sum[7] ─▶ y[6]
              │
 mức 9    c9 ─┴──▶ sum[8] ──▶ y_shift[7] ──▶ y[7]   ← SÂU NHẤT
                   (= x[7] ^ y[7] ^ c8, bit mở rộng dấu)
```

| Đầu ra | Độ sâu lý thuyết | Slack thật (STA) | Khớp? |
|---|---|---:|:-:|
| `y[0]` (= `sum_ext[1]`) | 2 tầng carry | **8,51 ns** — cao nhất | ✅ |
| `y[1]` | 3 tầng | 8,29 ns | ✅ |
| `y[2]` | 4 tầng | 7,94 ns | ✅ |
| `y[3]` | 5 tầng | 7,41 ns | ✅ |
| `y[4]` | 6 tầng | 7,03 ns | ✅ |
| `y[5]` | 7 tầng | 6,69 ns | ✅ |
| `y[6]` | 8 tầng | 6,31 ns | ✅ |
| `y[7]` (= `sum_ext[8]`) | **9 tầng** | **6,18 ns** — thấp nhất | ✅ |

> Bảng slack **đơn điệu giảm** theo đúng thứ tự bit — đây là chữ ký không thể nhầm của một
> **chuỗi carry nối tiếp (ripple-carry)**. Nếu Yosys đã dựng carry-lookahead, slack của các
> bit sẽ **bằng nhau** gần như hoàn toàn. Đây là bằng chứng cấu trúc đọc trực tiếp từ STA,
> không cần mở netlist.

**Dự đoán trước khi mở STA:** đường tới hạn phải là
`bit thấp của x hoặc y → 8 tầng carry → y[7]`. Đích **chắc chắn** là `y[7]`.

## 4. Đối chiếu với STA thật — và **vì sao vòng hồi tiếp không hiện ra**

### 4.1 Đường được báo cáo

| Hạng mục | Giá trị thật |
|---|---|
| Startpoint | **`x[1]`** — không phải `x[0]` |
| Endpoint | `_98_` = **`y[7]`** ✅ đúng dự đoán |
| Data arrival | **3,75 ns** (gồm **1,00 ns** `input external delay` giả định) |
| Độ trễ cell thật | 3,75 − 1,00 = **2,75 ns** |
| Slack | **6,18 ns** (chu kỳ giả định 10 ns) |
| Số cell | 10, trong đó **5 `maj3_1`** = 1,95 ns = **71 %** |
| WNS / TNS | 0,00 / 0,00 |

**Vì sao startpoint là `x[1]` chứ không phải `x[0]`?** Vì `sum_ext[0]` bị `>>> 1` **vứt bỏ**
— nó không đi tới flip-flop nào. Đường từ `x[0]` chỉ ảnh hưởng qua `c1`, mà `c1 = x[0] AND
y[0]` (carry từ tầng 0, không có carry-in). Yosys tối ưu tầng này thành một cổng đơn giản
hơn tầng đầy đủ, nên nó **nhanh hơn** tầng bắt đầu từ `x[1]`. Đây là chi tiết nhỏ nhưng nó
cho thấy tool đã **thật sự** tối ưu chứ không dịch máy móc.

### 4.2 Vòng hồi tiếp — Charter mục 9

> Charter mục 9: *"Bộ lọc IIR có vòng hồi tiếp, nên đường tới hạn đi từ thanh ghi qua logic
> rồi quay lại chính thanh ghi đó. Chỉ rõ vòng này trong báo cáo STA và giải thích vì sao nó
> giới hạn tần số tối đa."*

**Sự thật cần nói thẳng: `timing_report_max.txt` KHÔNG in ra vòng này.** Cả 10 đường trong
báo cáo đều là in→reg (8 đường) hoặc reg→out (2 đường). Không có đường reg→reg nào.

| Vì sao bị che | Giải thích |
|---|---|
| Lệnh dùng | `report_checks -path_delay max -group_path_count 10`. OpenSTA mặc định `-endpoint_path_count 1` ⟹ **chỉ in đường TỆ NHẤT cho mỗi endpoint** |
| Hai đường cạnh tranh cùng endpoint `_98_` | ① `x[1] → cộng → y[7]`, khởi đầu tại `t = 1,00 ns` (input external delay **giả định** trong SDC) · ② `y[0] → cộng → y[7]` (**vòng hồi tiếp**), khởi đầu tại `t ≈ 0,29 ns` (`clk→Q`) |
| Kết quả | Đường ① tệ hơn ~0,7 ns ⟹ **thắng** chỗ in ⟹ vòng hồi tiếp không xuất hiện |

**Bằng chứng vòng hồi tiếp CÓ tồn tại** — `timing_report_min.txt`, cả **5/5** đường:

| Startpoint | Endpoint | Slack hold |
|---|---|---:|
| `_98_` (`y[7]`) | **`_98_`** (`y[7]`) | 0,47 ns |
| `_91_` (`y[0]`) | **`_91_`** | 0,49 ns |
| `_97_` (`y[6]`) | **`_97_`** | 0,52 ns |
| `_92_` (`y[1]`) | **`_92_`** | 0,52 ns |
| `_93_` (`y[2]`) | **`_93_`** | 0,52 ns |

Startpoint **bằng** endpoint — đó là định nghĩa của vòng hồi tiếp. Chi tiết đường `_98_`:

```
  _98_/CLK ──0,29──▶ _98_/Q ──0,06──▶ _87_/Y (o21ai_0) ──0,06──▶ _89_/Y (a21boi_0) ──▶ _98_/D
```

Đây là nhánh **ngắn nhất** của vòng (`y[7]` quay về `y[7]` qua mux giữ, không qua chuỗi
carry). Nhánh **dài nhất** của vòng là `y[0] → 8 tầng carry → y[7]`, và đó mới là thứ giới
hạn tần số.

### 4.3 Vì sao vòng hồi tiếp giới hạn tần số tối đa

```
  T_clk  ≥  t_ckq(y[0])  +  t_logic(cộng 9 bit + mux giữ)  +  t_setup(y[7])  +  t_skew
            ≈ 0,29 ns    +   ≈ 2,4 ns (ước lượng*)         +   0,08 ns      +  ?
```

\* Ước lượng: đường in→reg có 2,75 ns độ trễ cell từ chân `x[1]`; vòng hồi tiếp đi vào cùng
chuỗi carry từ `y[0]` nên **cùng cỡ**. Con số chính xác **chưa có** vì báo cáo chưa in ra.

| Vì sao **không thể** rút ngắn bằng pipeline | Giải thích |
|---|---|
| Pipeline cắt đường dài bằng cách chèn thanh ghi | Nhưng ở đây, **đích của đường chính là nguồn của nó**. Chèn thanh ghi vào giữa vòng ⟹ `y[n]` sẽ dùng `y[n−2]` thay vì `y[n−1]` ⟹ **đổi hàm truyền**, không còn là bộ lọc đã đặc tả |
| Đây là tính chất chung của mọi IIR | Mạch FIR (G01) **có thể** pipeline tuỳ ý vì không có vòng. Đây là đánh đổi cơ bản: IIR rẻ về diện tích, nhưng **bị khoá** về tần số |
| Cách duy nhất rút ngắn vòng | Thay ripple-carry bằng carry-lookahead / carry-select trong bộ cộng — **giảm độ trễ, không đổi hàm truyền**. Xem `tradeoff.md` §3 |

> ⚠️ **Việc cần làm để khép kín câu trả lời Charter mục 9:** chạy lại STA với
> `report_checks -path_delay max -group_path_count 30 -endpoint_path_count 5` hoặc
> `report_checks -from [get_pins _91_/CLK] -to [get_pins _98_/D] -path_delay max`
> để có **số thật** của vòng hồi tiếp. Việc này **chưa làm**.

## 5. Vì sao `sum_ext` phải là 9 bit — chứng minh không tràn

| Bước | Lập luận |
|---|---|
| Miền của `x` | `[−128, +127]` (8 bit bù 2) |
| Miền của `y_q` | `[−128, +127]` |
| Tổng **chưa mở rộng** | `[−256, +254]` — **vượt 8 bit** |
| Mở rộng dấu lên 9 bit | Miền 9 bit = `[−256, +255]` ⟹ **chứa đủ** `[−256, +254]` |
| Sau `>>> 1` | `[−128, +127]` ⟹ **vừa khít 8 bit** |
| Cắt `y_shift[7:0]` | INV-4: `y_shift[8] == y_shift[7]` ⟹ **không mất thông tin** |

Golden model kiểm điều này **vét cạn** chứ không lấy mẫu (`test_feedback_bound()`: 256 giá
trị `x` × 7 giá trị `y` biên, khẳng định `−256 ≤ total ≤ 254` và `−128 ≤ y ≤ 127`).

> 🔎 Đây là một thiết kế **đúng bằng xây dựng** (correct by construction): không cần logic
> bão hoà, không cần cờ tràn, và **không có ca kiểm thử nào có thể làm nó tràn**. So sánh với
> G04 (tích luỹ có bão hoà), nơi tràn là bản chất bài toán và phải xử lý tường minh.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
