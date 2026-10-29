# G06 · Nhật ký vá (PATCHLOG)

**Ngày vá:** 2026-09-24 · **Người duyệt:** giảng viên đã duyệt áp dụng toàn bộ bản vá

Tham chiếu chẩn đoán: `05_VERIFICATION/known_issues.md` (giữ nguyên, không sửa phần phán xử).

## 1. Tóm tắt

| # | File | Loại lỗi | Mô tả một dòng | Ảnh hưởng số liệu |
|---|---|---|---|---|
| P-1 | `05_VERIFICATION/testbench/g06_tb.sv` | Lỗi testbench | Hằng số kỳ vọng ở ca biên âm tính bằng **làm tròn về 0** (`−51`) trong khi RTL và mô hình chuẩn dùng **dịch phải số học = làm tròn xuống** (`−52`) | **Không** — chỉ đụng testbench |

Không có dòng RTL nào bị sửa. `04_IMPLEMENTATION/rtl/g06_iir_half.sv` **giữ nguyên bản gốc**,
đúng như phán xử §4 của `known_issues.md`.

Đây là bản vá đúng **một ký tự** (`1` → `2`), cộng thêm một dòng chú thích giải thích số học
để lỗi không tái diễn khi ai đó thêm vector mới.

## 2. Chi tiết từng bản vá

### P-1 — sửa hằng số kỳ vọng ở ca biên âm

**File:** `05_VERIFICATION/testbench/g06_tb.sv` · **Dòng:** 49 (bản gốc) ·
**Phán xử:** lỗi ở **testbench** (Phương án A của `known_issues.md` §6)

**Trước:**
```systemverilog
        // Boundary negative case.
        send(-8'sd128,-8'sd51);
```

**Sau:**
```systemverilog
        // Boundary negative case.
        // sum = -128 + 25 = -103 ; -103 >>> 1 = -52 (lam tron XUONG, khong phai ve 0)
        send(-8'sd128,-8'sd52);
```

**Vì sao:** tại lệnh `send` thứ 11, `y_q = 25` và `x = −128` ⟹ `sum_ext = −103`. RTL tính
`sum_ext >>> 1` — **dịch phải số học**, nhân bản bit dấu ⟹ `⌊−103/2⌋ = −52`. Mô hình chuẩn
Python tính `v // 2` (chia sàn) ⟹ cũng `−52`. Chỉ hằng số viết tay trong testbench dùng quy
tắc `−103 / 2 = −51,5 → −51` (làm tròn **về 0**, kiểu C/SystemVerilog `/`).

Hai quy tắc chỉ khác nhau khi tổng **âm và lẻ**; mười vector trước đó đều cho tổng dương
(`100, 150, 175, 187, 193, 196, 198, 199, 100, 51`) nên đều qua. `−103` là tổng âm lẻ **đầu
tiên** trong cả testbench.

Biểu quyết 2 trên 3 (RTL và golden model độc lập cùng cho `−52`, chỉ hằng số viết tay khác)
là căn cứ quyết định để kết luận testbench sai, chứ không phải DUT.

**Hệ quả:** mô phỏng chạy hết cả 11 lệnh `send` **và** ca khe `valid_in` (dòng 52–54) — hai
phần trước đây bị `$fatal` chặn. Không ảnh hưởng netlist, vì bản vá không đụng RTL.

Dòng chú thích được thêm vào để lần sau ai viết vector âm mới sẽ thấy ngay quy tắc làm tròn
phải dùng — đây chính là bài học **BH-1** và **BH-4** của `known_issues.md` §9.

## 3. Kết quả xác minh sau khi vá

| Bước | Trước khi vá | Sau khi vá |
|---|---|---|
| Mô hình chuẩn Python | `G06 golden reference PASS`, mã thoát 0 | `G06 golden reference PASS`, mã thoát 0 (**không sửa file này**) |
| Biên dịch (iverilog 12.0) | Thành công, kèm 2 cảnh báo `sorry: constant selects…` | Thành công, **vẫn 2 cảnh báo đó** (giới hạn công cụ, vô hại — `known_issues.md` §8; cố ý không sửa RTL) |
| Mô phỏng | ❌ `FATAL: g06_tb.sv:23: y mismatch: got=-52 expected=-51`, `Time: 126` | ✅ `G06 TB completed`, `$finish` tại `t = 146 ns` — **không** `ERROR`/`FATAL`/`mismatch`. Trùng khớp với dự đoán ở `known_issues.md` §6 (*"`$finish` tại `t = 146 ns`"*) |
| Tổng hợp (yosys + sky130hd) | 54 cell / 9 FF / 482,9632 µm² | **54 cell / 9 FF / 482,9632 µm²** — *không đổi*, đúng như dự kiến vì RTL không bị sửa |

FF là `sky130_fd_sc_hd__dfxtp_1` × 9. Số wire: 51.

⟹ Khẳng định ở `known_issues.md` §6 điểm 5 được **xác nhận bằng đo đạc**: toàn bộ số liệu vật
lý của G06 giữ nguyên giá trị sau bản vá.

Lệnh đã chạy để xác minh:

```bash
D=.../out/G06_Bo_loc_thong_thap_IIR_bac_mot_he_so_1_2
T=$(mktemp -d)
LIB=.../sky130hd.lib

python3 $D/05_VERIFICATION/golden_model/reference_model.py

iverilog -g2012 -o $T/sim.vvp \
   $D/04_IMPLEMENTATION/rtl/*.sv \
   $D/05_VERIFICATION/testbench/*.sv
cd $T && vvp sim.vvp | tail -20

yosys -Q -p "read_verilog -sv $D/04_IMPLEMENTATION/rtl/*.sv; \
   hierarchy -check -top g06_iir_half; proc; opt; fsm; opt; memory; opt; techmap; opt; \
   dfflibmap -liberty $LIB; abc -liberty $LIB; setundef -zero; splitnets; opt_clean -purge; \
   stat -liberty $LIB"
```

(G06 **không** có `05_VERIFICATION/golden_model/*.sv`, chỉ có mô hình chuẩn Python.)

## 4. Cách quay lui

```bash
cp 08_ORIGINAL_SOURCE/rtl/*            04_IMPLEMENTATION/rtl/
cp 08_ORIGINAL_SOURCE/golden_model/*   05_VERIFICATION/golden_model/
cp 08_ORIGINAL_SOURCE/testbench/*      05_VERIFICATION/testbench/
```

## 5. Việc còn lại

| Việc | Trạng thái | Lý do / ghi chú |
|---|---|---|
| **Phương án B** — cho testbench tự tính kỳ vọng bằng `ref_iir()` | ❌ **Không áp dụng** | Chính `known_issues.md` §6 cảnh báo phương án B **làm mất dự phòng đa dạng**: nếu `ref_iir` chép nguyên logic DUT thì testbench và DUT cùng sai khi đặc tả bị hiểu sai. Khuyến nghị của tài liệu là *"dùng A ngay"*, và dùng B chỉ khi **kèm** scoreboard đối chiếu golden Python. Hằng số viết tay diễn đạt **ý định** của người kiểm, đó là giá trị cần giữ |
| Ca **"đứng yên ở giá trị nhỏ"** thật sự (`known_issues.md` §7) | 🔴 **Vẫn thiếu** | Chú thích `// Low-value standing still.` ở dòng 44 mô tả một ca mà đoạn mã bên dưới **không** thực hiện: lúc đó `y_q = 99` nên đây là ca **dốc xuống**, không phải đứng yên. Ca thật cần `rst_n` giữa chừng rồi bơm `x = 1` liên tục — thêm nó **đổi cấu trúc luồng testbench**, không còn là "sửa tối thiểu" của lỗi đang xét, nên để lại cho lần bổ sung độ phủ riêng. Mô hình chuẩn Python **đã có** ca này và PASS (`test_low_value_standing_still`), nên rủi ro chức năng thấp — nhưng ở **mức RTL thì vẫn chưa kiểm**. Charter mục 8 **bắt buộc** ca này ⟹ **REQ-G06-012 chưa khép kín** |
| Ca CC-10, CC-11 trong `02_SPECIFICATION/corner_cases.md` §5 | 🔴 **Vẫn thiếu** | Cùng lý do trên |
| Làm sạch cảnh báo Icarus (`9'(signed'(x))` thay cho `{x[7], x}`) | ❌ **Không áp dụng** | Đụng RTL, mà cảnh báo là **giới hạn công cụ vô hại** (`known_issues.md` §8): danh sách nhạy rộng **hơn** mức cần ⟹ kết quả vẫn đúng. Sửa mã đang đúng chỉ để dọn log sẽ buộc chạy lại toàn bộ tầng 06 mà không được gì |

**Phát biểu được phép dùng sau bản vá này:** *"Mô phỏng RTL G06 chạy hết và PASS."*
**Phát biểu KHÔNG được dùng:** *"Đã kiểm chứng đầy đủ chức năng"* — ca "đứng yên ở giá trị
nhỏ" mà Charter mục 8 bắt buộc vẫn chưa chạy trên RTL.

## 6. Áp dụng lại (2026-09-24)

**Lý do:** một bước sinh tài liệu tự động (`generate2.py`) đã chép mã nguồn cũ từ
`runs/<mã>/work/` **đè lên** `04_IMPLEMENTATION/rtl/`, `05_VERIFICATION/golden_model/` và
`05_VERIFICATION/testbench/`, làm mất toàn bộ bản vá trong ba thư mục đó. Lỗi của bộ sinh đã
được sửa. Bản vá được **áp dụng lại nguyên văn** theo §2 của chính tài liệu này.

**Đã áp dụng lại:** 1 / 1 bản vá — **P-1** (`05_VERIFICATION/testbench/g06_tb.sv`:
`send(-8'sd128,-8'sd51)` → `send(-8'sd128,-8'sd52)`, kèm dòng chú thích giải thích quy tắc
làm tròn xuống). Không có chênh lệch nào so với bản vá ghi ở §2. RTL vẫn **giữ nguyên bản
gốc**, đúng như §1.

**Kết quả xác minh lần này** (công cụ thật: Python 3, iverilog 12.0, Yosys 0.33 + sky130hd):

| Bước | Đo được lần này | Khớp §3? |
|---|---|:-:|
| Mô hình chuẩn Python | `G06 golden reference PASS`, mã thoát 0 | ✅ |
| Biên dịch | Thành công (mã thoát 0), **2 cảnh báo** `sorry: constant selects…` | ✅ |
| Mô phỏng | `G06 TB completed`, `$finish` tại **`t = 146`** — không `ERROR`/`FATAL`/`mismatch` | ✅ |
| Tổng hợp | **54 cell · 9 FF (`dfxtp_1` × 9) · 482,9632 µm² · 51 wire** | ✅ |

⟹ **Toàn bộ số liệu trùng khớp §3.** Bổ sung: netlist xuất bằng `write_verilog -noattr`
có **0 dòng `reg`/`always`** (netlist thuần cấu trúc).

Các mục ở §5 (việc còn lại) **không đổi** — đợt khôi phục này chỉ áp dụng lại đúng P-1,
không thêm bớt gì.
