# G06 · Giản đồ thời gian (Timing Diagram)

---

## 1. Điều phải nói trước mọi giản đồ

Waveform dưới đây dựng lại từ **chính** `05_VERIFICATION/testbench/g06_tb.sv` (59 dòng) và
ngữ nghĩa của `g06_iir_half.sv`, đối chiếu với `05_VERIFICATION/simulation.log`.

> ⚠️ **Mô phỏng KHÔNG chạy hết.** `simulation.log` ghi:
> ```
> FATAL: …/g06_tb.sv:23: y mismatch: got=-52 expected=-51
>        Time: 126  Scope: g06_tb.send
> ```
> Waveform dưới đây vẽ tới **đúng** thời điểm đó và chỉ ra chỗ dừng. Phán xử ở
> `05_VERIFICATION/known_issues.md` — kết luận trước: **lỗi nằm ở testbench, không ở RTL**.

> ❗ Đây là mô phỏng **hành vi (behavioural, zero-delay)**. Mọi tín hiệu đổi mức **đúng tại**
> cạnh lên clock. Giản đồ **không** minh hoạ được: `clk→Q` = 0,29 ns của `dfxtp_1`, 2,75 ns
> lan truyền qua chuỗi carry 9 bit, glitch khi 8 bit `x` đổi lệch nhau, hay setup/hold. Muốn
> thấy phải mô phỏng **gate-level** trên `netlist.v` — bước này **chưa chạy**.

**Quy ước đánh số:** `always #5 clk = ~clk` ⟹ chu kỳ 10 ns, cạnh lên thứ `n` tại
`t = 5 + 10(n−1)` ns. Testbench lấy mẫu tại cạnh lên **+1 ns**.

## 2. Bản đồ toàn bộ lần chạy

| Cạnh lên | `t` (ns) | Dòng TB | `x` | `y` thật | `y` TB kỳ vọng | Kết quả |
|---:|---:|---:|---:|---:|---:|:-:|
| 1–2 | 5, 15 | 30–32 | 0 | 0 (reset) | — | — |
| 3 | 25 | 35 | 100 | **50** | 50 | ✅ |
| 4 | 35 | 36 | 100 | **75** | 75 | ✅ |
| 5 | 45 | 37 | 100 | **87** | 87 | ✅ |
| 6 | 55 | 38 | 100 | **93** | 93 | ✅ |
| 7 | 65 | 39 | 100 | **96** | 96 | ✅ |
| 8 | 75 | 40 | 100 | **98** | 98 | ✅ |
| 9 | 85 | 41 | 100 | **99** | 99 | ✅ |
| 10 | 95 | 42 | 100 | **99** | 99 | ✅ |
| 11 | 105 | 45 | 1 | **50** | 50 | ✅ |
| 12 | 115 | 46 | 1 | **25** | 25 | ✅ |
| **13** | **125** | **49** | **−128** | **−52** | **−51** | ❌ **`$fatal` tại t = 126** |
| 14–15 | 135, 145 | 52–54 | — | — | — | ⬜ **chưa chạy tới** |

**Kiểm tra số học:** cạnh lên 13 tại `t = 5 + 10 × 12 = 125`, cộng `#1` = **126 ns**. Khớp
chính xác `Time: 126` trong `simulation.log`. Mỗi lệnh `send()` tiêu thụ **đúng một** cạnh lên.

## 3. Giao dịch điển hình — đáp ứng bước nhảy `x = 100` (cạnh lên 1 → 11)

```
 cạnh lên  │  1  │  2  │  3  │  4  │  5  │  6  │  7  │  8  │  9  │ 10  │ 11  │
 t (ns)    5    15    25    35    45    55    65    75    85    95   105   115
           ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐   ┌─┐
 clk   ────┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └──
           ▲     ▲     ▲     ▲     ▲     ▲     ▲     ▲     ▲     ▲     ▲
                   ┌──────────────────────────────────────────────────────
 rst_n ────────────┘  (=0 qua cạnh 1 và 2, lên 1 tại t=15)
       (=0)
                   ┌──────────────────────────────────────────────────────
 valid_in ─────────┘  (=1 liền mạch — mỗi send() nhả 1 ns rồi bật lại ngay)

 x     ═══ 0 ═════╪════════════ 100 (BƯỚC NHẢY) ═══════════════════╪══ 1 ══
                   ▲ bước nhảy đặt tại t=15, mẫu đầu lấy ở cạnh 3

 y_q   ══ x ═╪══0══╪══0══╪══50══╪══75══╪══87══╪══93══╪══96══╪══98══╪══99══╪═99═╪═50═
 y     ══ x ═╪══0══╪══0══╪══50══╪══75══╪══87══╪══93══╪══96══╪══98══╪══99══╪═99═╪═50═
                          ▲      ▲      ▲      ▲      ▲      ▲      ▲      ▲
 sai số    ─  ─   100    50     25     13      7      4      2      1      1
 (100−y)                  └──╱2──┴──╱2──┴──╱2──┴──╱2──┴──╱2──┴──╱2──┴─ ĐỨNG
                          MỖI MẪU SAI SỐ GIẢM MỘT NỬA              YÊN ▲
                                                                        │
                       ĐIỂM BẤT ĐỘNG: ⎣(100+99)/2⎦ = ⎣99,5⎦ = 99 ──────┘
                                                 ┌───────────────────────────
 valid_out ──────────(=0)───────────────────────┘  (=1 từ cạnh 3, trễ đúng 1 nhịp
                                                    so với valid_in — INV-1)
```

### Đọc gì từ giản đồ này

| Quan sát | Ý nghĩa |
|---|---|
| Sai số 50 → 25 → 13 → 7 → 4 → 2 → 1 | **Giảm một nửa mỗi mẫu** ⟹ quy luật tiệm cận mũ. Hằng số thời gian `τ = 1/ln2 ≈ 1,44` mẫu. Đây là câu trả lời Charter mục 2 câu 3 |
| 13 chứ không phải 12,5 | Phép `⎣·⎦` làm sai số **lệch xuống** ở mọi bước: `⎣25/2⎦ = 12` nhưng `100 − 87 = 13`. Sự lệch tích luỹ chính là nguồn gốc sai lệch DC |
| Cạnh 9 và 10 **cùng cho 99** | **Điểm bất động**. Bộ lọc dừng ở `x − 1`, không bao giờ đạt `x = 100` |
| `y_q` và `y` **giống hệt nhau** ở mọi chu kỳ | Đây là lý do Yosys hợp nhất hai thanh ghi. Ở netlist chúng là **cùng một dây** |
| `valid_out` trễ `valid_in` đúng 1 nhịp | INV-1. Lưu ý `valid_out` được nạp **mỗi** chu kỳ (không có enable), khác với `y` |
| 7 mẫu để đạt 1 LSB | Khớp với `log₂(100) ≈ 6,6` ⟹ 7 mẫu. Suy diễn ở `functional_spec.md` §7 |

## 4. Vòng hồi tiếp trên waveform — cái mà mạch không hồi tiếp không có

```
 cạnh lên       │   7     │   8     │   9     │
 t (ns)        65        75        85
                ▲         ▲         ▲
   x        ═══════════ 100 ═══════════════════
                │         │         │
   y_q(cũ)  ═══ 93 ══════╪═══ 96 ══╪═══ 98 ══
                │  ╲      │  ╲      │  ╲
                │   ╲ cộng│   ╲     │   ╲
                │    ▼    │    ▼    │    ▼
   sum_ext  ═══ 193 ══════╪══ 196 ══╪══ 198 ══
                │    │    │    │    │    │
                │   >>>1  │   >>>1  │   >>>1
                │    ▼    │    ▼    │    ▼
   y(mới)   ═══ 96 ══════╪═══ 98 ══╪═══ 99 ══
                     ╰────────┐╰────────┐╰──── quay lại làm y_q của chu kỳ sau
                              ▼         ▼
                       ĐÂY LÀ VÒNG HỒI TIẾP:
                       giá trị ra của chu kỳ n LÀ đầu vào của chu kỳ n+1.
                       ⟹ không thể pipeline mà không đổi hàm truyền.
                       ⟹ T_clk ≥ t_ckq + t_cộng9bit + t_mux + t_setup
```

So sánh với G01 (FIR, không hồi tiếp): ở đó, mỗi đầu ra chỉ phụ thuộc 4 mẫu vào gần nhất,
nên có thể chèn thanh ghi ở bất kỳ đâu trong cây cộng mà **không đổi** hàm truyền — chỉ tăng
độ trễ. Ở G06 điều đó **không thể**.

## 5. Chỗ mô phỏng **dừng** — cạnh lên 13

```
 cạnh lên       │   11    │   12    │   13    │        14   (CHƯA CHẠY)
 t (ns)        105       115       125                135
                ▲         ▲         ▲
   x        ═══ 1 ═══════╪═══ 1 ═══╪══ −128 ═╪═  (8'h80)
   y_q(cũ)  ═══ 99 ══════╪══ 50 ═══╪═══ 25 ══╪═
   sum_ext  ═══ 100 ═════╪══ 51 ═══╪══ −103 ═╪═   ← mở rộng dấu 9 bit: −128 + 25
   y(mới)   ═══ 50 ══════╪══ 25 ═══╪══ −52 ══╪═
                                       ▲▲▲
                                       │││ RTL cho  −52  = ⎣−103/2⎦  (dịch SỐ HỌC)
                                       │││ TB  kỳ vọng −51  = −103/2 làm tròn VỀ 0
                                       │││
   ───────────────────────────────────▶ $fatal tại t = 126 ◀────────────────────
                                       "y mismatch: got=-52 expected=-51"

   ⟹ Mô hình chuẩn Python cũng cho −52 (arshift1(-103) = -103 // 2 = -52).
      HAI trên BA mô hình độc lập nói −52.  Xem known_issues.md để có phán xử đầy đủ.
```

> 🔎 **Vì sao lỗi chỉ lộ ra ở mẫu thứ 11?** Mười mẫu đầu đều cho `sum_ext` **dương** hoặc
> **chẵn**, mà `>>> 1` và `/2` chỉ khác nhau khi kết quả **âm và lẻ**. `x = −128` với
> `y_q = 25` là **giá trị đầu tiên** trong cả testbench thoả điều kiện đó. Đây là lý do
> Charter mục 8 bắt buộc có **ca biên** — và cũng là bằng chứng ca biên **làm đúng việc của nó**.

## 6. Ba thứ waveform hành vi này **không** cho thấy

| Không thấy được | Vì sao | Số thật có ở đâu |
|---|---|---|
| Độ trễ `clk→Q` và lan truyền carry | Mô phỏng zero-delay | `timing_report_max.txt`: 2,75 ns cell delay, trong đó 1,95 ns là 5 `maj3_1`; `timing_report_min.txt`: `clk→Q` = 0,29 ns |
| Chuỗi carry **lan dần** từ bit 0 lên bit 8 | RTL cho `sum_ext` ngay lập tức. Thực tế `y[0]` ổn định trước `y[7]` khoảng 2 ns | Slack theo bit: `y[0]` = 8,51 ns → `y[7]` = 6,18 ns, giảm **đơn điệu** |
| Vi phạm setup trên **vòng hồi tiếp** | Cần mô hình độ trễ | Báo cáo hiện tại **chưa in** đường reg→reg. Xem `datapath.md` §4.2 |

> ❗ Không được kết luận "G06 chạy được ở 266 MHz" từ 3,75 ns. Con số đó gồm 1,00 ns IO delay
> **giả định**, chưa có ký sinh dây, mới một góc PVT, và **chưa** tính đường vòng hồi tiếp
> vốn là thứ thật sự giới hạn tần số.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
