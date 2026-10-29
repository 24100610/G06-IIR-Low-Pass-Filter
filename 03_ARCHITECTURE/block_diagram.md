# G06 · Sơ đồ khối bên trong (Block Diagram)

> Vẽ theo **đúng** `04_IMPLEMENTATION/rtl/g06_iir_half.sv` (38 dòng), đối chiếu với
> `06_GDSII/synthesis/netlist.v`.

---

## 1. Sơ đồ khối — đúng cấu trúc RTL

```
                     ┌──────────── VÒNG HỒI TIẾP (IIR) ─────────────────┐
                     │                                                  │
                     ▼                                                  │
   x[7:0] ══════╗    │  y_q[7:0]                                        │
                ║    │      ║                                           │
         ┌──────╨────╨──────╨───────┐                                   │
         │ MỞ RỘNG DẤU  8 → 9 bit   │                                   │
         │ x_ext = {x[7], x}        │   ← RTL dòng 17                   │
         │ y_ext = {y_q[7], y_q}    │   ← RTL dòng 18                   │
         └──────┬──────────┬────────┘                                   │
          x_ext ║   y_ext  ║                                            │
                ▼          ▼                                            │
         ┌─────────────────────────────────────────┐                    │
         │  BỘ CỘNG 9 BIT  (chuỗi carry nối tiếp)  │  ← RTL dòng 19     │
         │  sum_ext = x_ext + y_ext                │                    │
         │  ┌───┐ ┌───┐ ┌───┐       ┌───┐ ┌───┐   │                    │
         │  │FA0│▶│FA1│▶│FA2│▶ … ▶ │FA7│▶│FA8│   │                    │
         │  └───┘ └───┘ └───┘       └───┘ └───┘   │                    │
         │    c1    c2    c3          c8    c9     │                    │
         └────────────────┬────────────────────────┘                    │
                          ║ sum_ext[8:0]                                │
                          ▼                                             │
         ┌─────────────────────────────────────────┐                    │
         │  DỊCH PHẢI SỐ HỌC 1 BIT                 │  ← RTL dòng 20     │
         │  y_shift = sum_ext >>> 1                │                    │
         │  ⟹ CHỈ LÀ ĐẤU DÂY — KHÔNG TỐN CELL NÀO │                    │
         │     y_shift[i] = sum_ext[i+1], i=0..7   │                    │
         │     y_shift[8] = sum_ext[8] (giữ dấu)   │                    │
         └────────────────┬────────────────────────┘                    │
                          ║ y_shift[7:0]                                │
                          ▼                                             │
                   ┌─────────────┐  en = valid_in                       │
                   │  MUX GIỮ    │◀─────────────────────┐               │
                   └──────┬──────┘                      │               │
                          ▼                             │               │
                   ┌─────────────────┐                  │               │
   valid_in ──────▶│  y REG  8 FF    │══▶ y[7:0] ═══════╪═══════════════┘
                   │  (= y_q, đã hợp │    (cổng ra)     │
                   │   nhất bởi Yosys)│                 │
                   └─────────────────┘                  │
                                                        │
   valid_in ──────▶┌─────────────────┐                  │
                   │ valid_out  1 FF │──▶ valid_out     │
                   └─────────────────┘                  │
   rst_n ─────────────────────────────────────────────▶ (gộp vào logic D, reset ĐỒNG BỘ)
   clk ───────────────────────────────────────────────▶
```

## 2. Bảng ánh xạ cấu trúc RTL → phần cứng sinh ra

| Dòng RTL | Cấu trúc RTL | Phần cứng sinh ra | Bằng chứng netlist |
|---:|---|---|---|
| 10 | `logic signed [7:0] y_q;` | **0 cell riêng** — bị hợp nhất với `y` | Netlist **không có** wire `\y_q[…]`; chỉ có `y[0..7]` |
| 11–14 | `sum_ext`, `x_ext`, `y_ext`, `y_shift` (9 bit) | Dây và logic tổ hợp, không thanh ghi | 45 cell tổ hợp |
| 17 | `x_ext = {x[7], x}` | **0 cell** — chỉ là đấu dây; `x[7]` được nối vào hai chỗ | Fanout của `x[7]` tăng |
| 18 | `y_ext = {y_q[7], y_q}` | **0 cell** — đấu dây | như trên |
| 19 | `sum_ext = x_ext + y_ext` | **Bộ cộng 9 bit ripple-carry**: 5 `maj3_1` (hàm carry) + 6 `xnor2_1` + 5 `xor2_1` + các cổng gộp | `maj3_1 × 5`, `xnor2_1 × 6`, `xor2_1 × 5` trong `synth_stat.txt` |
| 20 | `y_shift = sum_ext >>> 1` | **0 cell** — dịch bằng **hằng số** chỉ là đổi cách đấu dây. Đây là lý do "hệ số 1/2" rẻ hơn mọi hệ số khác | Không có cell dịch nào trong netlist |
| 23 | `always_ff @(posedge clk)` | 9 `dfxtp_1` dùng chung `clk` | mọi FF có `.CLK(clk)` |
| 24–27 | `if (!rst_n)` | **Reset đồng bộ** ⟹ gộp vào logic `D` | Netlist dùng **`dfxtp_1`** (không chân reset), không phải `dfrtp_1` |
| 30 | `if (valid_in)` | **Mux giữ** trên đường `D` của cả 9 FF | `mux2i_1 × 1` + `a21oi_1`/`o21ai_0` |
| 31–32 | `y_q <= y_shift[7:0];` **và** `y <= y_shift[7:0];` | **Hợp nhất thành MỘT thanh ghi 8 bit** — hai lệnh gán cùng nguồn, cùng enable, cùng giá trị reset | 9 FF thay vì 17. Xem §3 |
| 29, 33 | `valid_out` | 1 `dfxtp_1` | `_90_` → `.Q(valid_out)` |

### Đối chiếu số lượng flip-flop

| Nguồn | Số FF | Ghi chú |
|---|---:|---|
| Đọc RTL bằng tay | 8 (`y_q`) + 8 (`y`) + 1 (`valid_out`) = **17** | đếm hai thanh ghi riêng |
| Netlist thật | **9** | `synth_stat.txt`: `dfxtp_1 × 9` |
| Chênh lệch | **8** | Yosys **hợp nhất `y_q` vào `y`** |
| Charter mục 10 dự kiến | 9–10 | ✅ **khớp chính xác** |

> 🔎 **Vì sao Yosys hợp nhất được?** `y_q` và `y` có **cùng** biểu thức `D` (`y_shift[7:0]`),
> **cùng** điều kiện enable (`valid_in`), **cùng** giá trị reset (`'0`) và **cùng** clock.
> Hai thanh ghi giống hệt nhau về mọi mặt ⟹ một cái là bản sao thừa. Đây là tối ưu
> `opt_merge`/`opt_dff` kinh điển.
>
> **Hệ quả cần biết:** ở mức RTL, `y_q` là trạng thái **nội bộ** và `y` là **cổng ra**; ở mức
> netlist, chúng là **cùng một dây**. Nghĩa là vòng hồi tiếp thật sự chạy **qua chân ra `y`**,
> và fanout của mỗi bit `y[i]` bằng **tổng** fanout của hai tín hiệu RTL. So sánh với G05,
> nơi tác giả cố tình **không** để tool hợp nhất (vì `min_q` và `min_out` có enable khác nhau).

## 3. Khối con nào nằm trên **đường tới hạn**

Đối chiếu `06_GDSII/sta/timing_report_max.txt`, đường xấu nhất:

```
 x[1]  (t = 1,00 ns — toàn bộ là input external delay GIẢ ĐỊNH)
   └─▶ _49_  xnor2_1   +0,17 → 1,17 ns   ← tạo tổng riêng phần bit 1
       └─▶ _53_  o21ai_0  +0,15 → 1,32 ns  ← logic carry bit 1
           └─▶ _58_  maj3_1  +0,40 → 1,71 ns  ┐
               └─▶ _63_ maj3_1 +0,39 → 2,10 ns │
                   └─▶ _69_ maj3_1 +0,39 → 2,49 ns ├ CHUỖI CARRY
                       └─▶ _75_ maj3_1 +0,39 → 2,89 ns │ của BỘ CỘNG 9 BIT
                           └─▶ _82_ maj3_1 +0,38 → 3,27 ns ┘
                               └─▶ _88_ or3_1  +0,34 → 3,61 ns
                                   └─▶ _89_ a21boi_0 +0,14 → 3,75 ns
                                       └─▶ _98_/D  dfxtp_1 = y[7]
```

| Khối con | Trên đường tới hạn? | Đóng góp |
|---|:-:|---|
| **Chuỗi carry của bộ cộng 9 bit** | ✅ **có** | 5 × `maj3_1` = **1,95 ns** / 2,75 ns độ trễ cell thật = **71 %** |
| Logic tổng riêng phần (`xnor2`, `o21ai`) | ✅ có | 0,32 ns |
| Gộp carry cuối + mux giữ (`or3`, `a21boi`) | ✅ có | 0,48 ns |
| **Bộ dịch `>>> 1`** | ❌ **không** — nó là **dây** | **0,00 ns** |
| **Mở rộng dấu** | ❌ không — cũng là dây | 0,00 ns |
| Logic `valid_out` | ❌ không | đường 2 cell, slack lớn |

> 🔎 **Ba điều đáng nói khi đọc báo cáo này:**
>
> 1. **Đích là `y[7]`, bit CAO nhất.** Hợp lý: `y[7] = sum_ext[8]` là bit cao nhất của tổng,
>    tức bit phải chờ **toàn bộ** chuỗi carry. Ngược lại `y[0] = sum_ext[1]` chỉ chờ 1 tầng —
>    và đúng vậy, `_91_` (= `y[0]`) có slack 8,51 ns, cao nhất trong 8 bit.
> 2. **Bộ dịch không tốn gì.** Đây là lý do đề chọn hệ số **1/2**: mọi hệ số dạng `2^−k`
>    hiện thực bằng đấu dây. Hệ số `0,3` sẽ cần bộ nhân ⟹ đổi hẳn quy mô thiết kế.
> 3. **Chỉ có 5 `maj3_1`, nhưng bộ cộng 9 bit cần 8 tầng carry.** `abc` đã gộp 2–3 tầng vào
>    `o21ai_0`, `or3_1`, `a21boi_0`. **Đếm cell ≠ đếm tầng logic.**

## 4. Vòng hồi tiếp — vì sao nó **không** xuất hiện trong báo cáo setup

Charter mục 9 yêu cầu chỉ rõ vòng hồi tiếp trong báo cáo STA. Sự thật đáng chú ý:

**`timing_report_max.txt` KHÔNG chứa đường reg→reg nào.** Cả 10 đường đều là `x[1] → FF`
(8 đường) hoặc `FF → y[…]` (2 đường). Không có đường nào bắt đầu **và** kết thúc ở flip-flop.

**Vì sao?** Script STA (`04_IMPLEMENTATION/scripts/03_run_sta.tcl`) dùng:

```tcl
report_checks -path_delay max -group_path_count 10 …
```

OpenSTA mặc định in **một đường duy nhất cho mỗi endpoint** (`-endpoint_path_count 1`). Với
mỗi flip-flop `_91_ … _98_`, có **hai** đường tới nó:

| Đường tới `_98_` (= `y[7]`) | Xuất phát | Gánh nặng |
|---|---|---|
| ① `x[1] → cộng → y[7]` | cổng vào | **+1,00 ns** `input external delay` (giả định SDC) |
| ② `y[0] → cộng → y[7]` — **VÒNG HỒI TIẾP** | flip-flop | `clk→Q` ≈ 0,29 ns |

Đường ① có gánh nặng 1,00 ns còn đường ② chỉ 0,29 ns, nên **① luôn tệ hơn** và ② bị **che**.

**Bằng chứng vòng hồi tiếp vẫn tồn tại:** `timing_report_min.txt` (đường hold) có **cả 5
đường** đều dạng `_9x_ → _9x_` — **cùng một flip-flop vừa là startpoint vừa là endpoint**.
Đó chính là vòng hồi tiếp, chỉ hiện ra ở phía hold:

```
  _98_/CLK ──0,29──▶ _98_/Q ──0,06──▶ _87_/Y (o21ai_0) ──0,06──▶ _89_/Y (a21boi_0) ──▶ _98_/D
  arrival 0,41 ns · required −0,06 ns (library hold time) · slack 0,47 ns
```

**Cách bắt OpenSTA in ra vòng hồi tiếp phía setup** (chưa chạy, đề xuất để bổ sung):

```tcl
# (a) in nhiều đường cho mỗi endpoint
report_checks -path_delay max -group_path_count 30 -endpoint_path_count 5

# (b) hoặc chỉ đích danh vòng hồi tiếp
report_checks -from [get_pins _91_/CLK] -to [get_pins _98_/D] -path_delay max
```

Phân tích đầy đủ ở `datapath.md` §4 và ở `implementation-notes_G06.md` §8.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
