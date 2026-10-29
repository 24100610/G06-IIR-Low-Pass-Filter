# G06 · Sơ đồ hệ thống (System Diagram)

---

## 1. Bối cảnh ứng dụng — khối này nằm ở đâu

Charter mục 1: *"Khối làm trơn tín hiệu ánh sáng môi trường để chỉnh độ sáng màn hình mượt,
tốn ít bộ nhớ hơn lọc trung bình."*

```
  THẾ GIỚI ANALOG                      │          MIỀN SỐ (digital)
                                       │
 ┌───────────┐  ┌──────────┐  ┌────────┴──┐  ┌──────────────┐  ┌───────────────┐
 │ Cảm biến  │  │ Khuếch   │  │   ADC     │  │ ██ G06 ██    │  │ Bảng tra      │
 │ ánh sáng  │─▶│ đại +    │─▶│  8 bit    │─▶│ IIR bậc 1    │─▶│ gamma / đường │─▶ PWM
 │ (photo-   │  │ lọc      │  │ fs thấp   │  │ y=⎣(x+y)/2⎦ │  │ cong độ sáng  │   đèn nền
 │  diode)   │  │ anti-    │  │ (vài Hz…  │  └──────┬───────┘  └───────────────┘
 └───────────┘  │ alias    │  │  vài kHz) │         │
                └──────────┘  └─────┬─────┘         │
                                    │               │
                               ┌────┴─────┐         │
                               │ valid_in │─────────┘
                               │ (1 xung  │
                               │  /mẫu)   │
                               └──────────┘
```

**Phân loại:** G06 là khối **thuần số (digital)**, đồng bộ. Ranh giới analog/digital ở **ADC**.

**Vì sao ứng dụng này cần lọc:** cảm biến ánh sáng môi trường có nhiễu và có những đột biến
ngắn (bóng tay lướt qua, đèn flash). Nếu đưa thẳng vào điều khiển độ sáng, màn hình sẽ
**nhấp nháy**. Bộ lọc thông thấp biến đột biến thành thay đổi từ từ. Với `f_c ≈ 0,115 f_s`
(suy ở `functional_spec.md` §7) và hằng số thời gian ≈ 1,44 mẫu, một bước nhảy cần **7 mẫu**
để ổn định — đủ chậm để mắt không thấy giật, đủ nhanh để không thấy trễ.

## 2. Ranh giới khối — cái gì **trong**, cái gì **ngoài**

| Chức năng | Trong G06? | Nếu ngoài thì ai làm |
|---|:-:|---|
| Cộng `x` với `y[n−1]` (mở rộng dấu 9 bit) | ✅ | `sum_ext = x_ext + y_ext` |
| Chia 2 bằng dịch số học | ✅ | `y_shift = sum_ext >>> 1` |
| Giữ trạng thái `y[n−1]` | ✅ | `y_q`, 8 flip-flop |
| Sinh cờ `valid_out` | ✅ | 1 flip-flop |
| **Chọn hệ số lọc** | ❌ | Chốt cứng = 1/2. Charter mục 3: "hệ số lập trình được" **ngoài phạm vi** |
| **Bù sai lệch DC −1 LSB** | ❌ | Tầng ngoài, nếu ứng dụng cần. Xem `functional_spec.md` §4 |
| **Bảng tra gamma / đường cong độ sáng** | ❌ | Tầng ngoài |
| **Sinh PWM cho đèn nền** | ❌ | Khối khác (so D06) |
| Quyết định khi nào mẫu hợp lệ | ❌ | Cờ `data_ready` của ADC |
| Đồng bộ hoá liên miền clock | ❌ | Tầng ngoài |
| **Lọc bậc cao, chống limit cycle** | ❌ | Charter mục 3: ngoài phạm vi |

> **Nghĩa vụ hợp đồng của tầng ngoài, bốn điều:**
> 1. `valid_in` phải là **xung một chu kỳ** cho mỗi mẫu mới. Giữ mức cao 2 chu kỳ = lọc mẫu
>    đó **hai lần** ⟹ đáp ứng nhanh gấp đôi so với đặc tả.
> 2. Giữ `rst_n = 0` qua **ít nhất một** cạnh lên (reset **đồng bộ**).
> 3. **Chốt cách hiểu `x`**: có dấu bù 2 hay không dấu. RTL xử lý **có dấu**; cổng khai báo
>    **không dấu**. Xem cảnh báo đầu `functional_spec.md`.
> 4. Không đưa `X`/`Z` vào `x` — ở mạch IIR, một mẫu hỏng làm hỏng **toàn bộ tương lai**, chứ
>    không chỉ N mẫu như ở FIR.

## 3. So với G01 (lọc trung bình trượt 4 điểm) — vì sao Charter chọn IIR

Charter mục 2 câu 1 hỏi thẳng câu này. Số liệu lấy từ hai hồ sơ, **cùng một tổ hợp công cụ**
(Yosys 0.33 · OpenSTA 3.1.0 · `sky130_fd_sc_hd__tt_025C_1v80.lib`), nên so sánh được:

| Chỉ số | **G01** (FIR trung bình 4 điểm) | **G06** (IIR bậc 1) | Tỷ lệ |
|---|---:|---:|---:|
| Flip-flop | **58** | **9** | **6,4 ×** |
| Số cell | 260 | 54 | 4,8 × |
| Diện tích | 2623,7664 µm² | **482,9632 µm²** | **5,4 ×** |
| Độ trễ đường tới hạn | 4,56 ns | 3,75 ns | 1,2 × |
| Bộ nhớ khái niệm | **4 mẫu** = 32 bit | **1 giá trị** = 8 bit | 4 × |

> Charter mục 10 dự đoán *"ít hơn G01 tới hơn 3 lần"*. Số thật: **6,4 lần** về flip-flop,
> **5,4 lần** về diện tích — **vượt** dự đoán. Lý do: G01 không chỉ cần 4 thanh ghi mẫu mà
> còn cần thanh ghi tổng và các tầng trung gian; G06 chỉ cần **một** thanh ghi trạng thái.
>
> ⚠️ Cái giá đổi lại **không** nhỏ: G06 có đáp ứng xung **vô hạn**, nên một mẫu hỏng ảnh
> hưởng mãi mãi; G01 thì chỉ ảnh hưởng 4 mẫu. Và G06 có **sai lệch DC −1 LSB** do làm tròn,
> G01 thì không (nếu chia 4 bằng dịch 2 bit thì cũng có, nhưng không tích luỹ).

## 4. Vị trí trong một ô Tiny Tapeout 1×1

```
 ┌───────────────── ô Tiny Tapeout 1×1 (24 chân) ─────────────────┐
 │                                                                 │
 │   ui_in[7:0] ──▶┌───────────────────────────────────────┐       │
 │                 │  ⬜ LỚP VỎ tt_um_* — CHƯA TỒN TẠI      │       │
 │  uio_in[7:0] ◀─▶│  PHẢI ĐÁNH SỐ LẠI uio[0]:              │      │
 │                 │  Charter mục 4 gán uio[0] VỪA làm      │       │
 │       ena ─────▶│  "mẫu hợp lệ" (vào) VỪA làm            │       │
 │                 │  "kết quả hợp lệ" (ra) — XUNG ĐỘT      │       │
 │                 │   ┌────────────────────────────────┐  │       │
 │                 │   │ ✅ g06_iir_half (module lõi)    │  │      │
 │                 │   │    54 cell · 9 FF · 482,96 µm²  │  │      │
 │                 │   └────────────────────────────────┘  │       │
 │                 └───────────────────────────────────────┘       │
 │  uo_out[7:0] ◀──                                                │
 └─────────────────────────────────────────────────────────────────┘
```

Ngân sách chân **đủ thoải mái**: 18 bit dữ liệu / 24 chân, dư 6. Đây là đề **duy nhất** trong
ba đề G05/G06/G07 không vượt ngân sách. Việc cần làm chỉ là **đánh số lại**, ví dụ:

| Tín hiệu | Gán đề xuất | Chiều `uio_oe` |
|---|---|---|
| `x[7:0]` | `ui_in[7:0]` | — (chỉ vào) |
| `valid_in` | `uio_in[0]` | `uio_oe[0] = 0` |
| `y[7:0]` | `uo_out[7:0]` | — (chỉ ra) |
| `valid_out` | `uio_out[1]` ← **đổi từ [0] sang [1]** | `uio_oe[1] = 1` |

> ⚠️ Đây là **đề xuất**, **chưa được áp dụng**. Không có file nào trong hồ sơ chốt việc này.

## 5. Vòng đời RTL → GDSII — trạng thái **thật**

Lấy từ `06_GDSII/physical_report.md` §1. ✅ đã chạy · ⚠️ chạy nhưng có vấn đề · ⬜ chưa · ⬛ không áp dụng.

```
 ┌───────────────┐
 │ Charter G06   │  ✅
 └───────┬───────┘
 ┌───────▼───────┐
 │ Đặc tả        │  ✅  02_SPECIFICATION/
 └───────┬───────┘
 ┌───────▼───────┐
 │ RTL           │  ✅  g06_iir_half.sv (38 dòng)
 └───────┬───────┘
 ┌───────▼───────┐
 │ Mô hình chuẩn │  ✅  reference_model.py — PASS (10 test, gồm vét cạn vòng hồi tiếp)
 └───────┬───────┘
 ┌───────▼───────┐
 │ Mô phỏng RTL  │  ⚠️  RAN_WITH_ISSUES — DỪNG ở assertion tại Time 126
 │               │     → xem 05_VERIFICATION/known_issues.md
 └───────┬───────┘
 ┌───────▼───────┐
 │ Tổng hợp      │  ✅  Yosys 0.33 → 54 cell · 9 FF · 482,9632 µm²
 └───────┬───────┘
 ┌───────▼───────┐
 │ STA           │  ✅  OpenSTA 3.1.0 → 3,75 ns · slack 6,18 ns · WNS/TNS = 0,00
 └───────┬───────┘
 ┌───────▼───────┐
 │ Công suất     │  ✅  ước lượng 6,04e-05 W (tổ hợp 28,8 % · tuần tự 71,2 %)
 └───────┬───────┘
 ┌───────▼───────┐
 │ Mô phỏng gate │  ⬜  test_matrix.csv: L4-GATE = CHUA CHAY
 ├───────────────┤
 │ Floorplan …   │  ⬜  cần LibreLane + PDK sky130A
 │ GDSII         │  ⬜  (Charter mục 3: phần MỞ RỘNG, tự nguyện)
 └───────┬───────┘
 ┌───────▼───────┐
 │ Sign-off      │  ⬛  Charter mục 3: NGOÀI PHẠM VI
 │ Tape-out      │  ⬛
 │ Chế tạo · test│  ⬛
 └───────────────┘
```

> ❗ **Điểm quan trọng khi đọc sơ đồ này:** bước "Mô phỏng RTL" ⚠️ **không** làm hỏng các
> bước sau. Tổng hợp, STA và công suất đều chạy từ **RTL**, không từ testbench — nên 54 cell
> · 9 FF · 482,9632 µm² · 3,75 ns **vẫn nguyên giá trị**. Phán xử ở `known_issues.md` cho
> thấy lỗi nằm ở **testbench**, không ở RTL, nên các con số vật lý không bị ảnh hưởng.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
