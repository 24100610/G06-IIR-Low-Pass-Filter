# G06 · Ca biên và ca kiểm thử (Corner Cases)

> Tài liệu này **đọc testbench thật** (`05_VERIFICATION/testbench/g06_tb.sv`, 59 dòng) và
> **mô hình chuẩn thật** (`05_VERIFICATION/golden_model/reference_model.py`, 100 dòng).
>
> ⚠️ **Mô phỏng RTL KHÔNG chạy hết**: `simulation.log` ghi `FATAL … y mismatch: got=-52
> expected=-51` tại `Time: 126`. Phán xử đầy đủ ở `05_VERIFICATION/known_issues.md`. Mọi
> phát biểu về độ phủ dưới đây đều tính theo **thực tế đã chạy được**, không theo ý định.

---

## 1. Ca bắt buộc của Charter mục 8 — và **vì sao** chọn từng ca

Charter mục 8 yêu cầu: *đáp ứng bước nhảy (quan sát tiệm cận) · đầu vào hằng · kiểm hiện
tượng đứng yên do làm tròn ở giá trị nhỏ.*

| ID | Ca | **Lý do kỹ thuật** — nó tấn công lỗi nào | TB SV | Golden Python | Đã chạy được? |
|---|---|---|:-:|:-:|:-:|
| **CC-1** | **Đáp ứng bước nhảy** `x = 100` từ `y = 0`, 8 mẫu | Ca **duy nhất** thấy được quy luật tiệm cận: sai số 50→25→13→7→4→2→1→1, giảm một nửa mỗi mẫu. Nếu hệ số bị viết nhầm (ví dụ `>>> 2`) thì dãy này sai ngay mẫu đầu | ✅ dòng 35–42 | ✅ `test_step()` | ✅ **đã qua** |
| **CC-2** | **Đầu vào hằng** (cùng ca trên, đoạn đuôi) | Kiểm **điểm bất động**: `y` dừng ở **99**, không phải 100. Nếu thiếu mở rộng dấu, hoặc dùng `>>` thay `>>>`, giá trị đuôi sẽ khác | ✅ dòng 41–42 | ✅ `test_constant_even()` | ✅ **đã qua** |
| **CC-3** | **Đứng yên ở giá trị nhỏ** | Tấn công trực diện rủi ro Charter mục 10. Với `x = 1` và `y` nhỏ, `⎣(x−y)/2⎦ = 0` ⟹ bộ lọc **không nhích**. Đây là ca mà "chỉ test giá trị lớn" **không bao giờ** phát hiện được | ⚠️ **một phần** — TB dòng 45–46 đưa `x = 1` nhưng `y` đang ở **99**, nên bộ lọc vẫn nhích mạnh (99→50→25). **Ca đứng yên thật sự chưa chạy trên RTL** | ✅ `test_low_value_standing_still()`: `run([1]*12)` cho `[0]*12` | ⚠️ **chỉ ở mức mô hình** |

> 🔎 **Phát hiện đáng chú ý thứ nhất:** testbench **tưởng** mình kiểm ca đứng yên (hai dòng
> `send(8'sd1, …)` nằm ngay dưới chú thích `// Low-value standing still.`), nhưng thực ra
> nó đang kiểm **dốc xuống từ giá trị lớn**. Muốn thấy hiện tượng đứng yên thật, `y` phải
> **đã ở gần 0** trước khi đưa `x = 1` vào. Golden Python làm đúng; testbench thì không.
> Đây là đúng cái bẫy Charter mục 10 mô tả, và nó **đã sập** ngay trong hồ sơ này.

## 2. Ca tự xây dựng đã có

| ID | Ca | Vị trí | Lý do kỹ thuật |
|---|---|---|---|
| **CC-4** | **Ca biên âm cực đại** `x = −128` | TB dòng 49 | Đưa `sum_ext` xuống −103 và kiểm `>>> 1` trên số **âm lẻ** — chính chỗ `>>>` khác `/2`. Đây là ca **đắt giá nhất** trong cả testbench, và nó **lộ ra một lỗi**: giá trị kỳ vọng trong TB sai. Xem `known_issues.md` |
| **CC-5** | **Khe `valid_in` thấp** 2 chu kỳ | TB dòng 52–54 | Kiểm INV-2: bộ lọc **đóng băng**, không tự trôi khi không có mẫu mới. Với mạch có hồi tiếp, đây là ca quan trọng: nếu `y_q` được nạp vô điều kiện thì bộ lọc sẽ tự chạy về 0 khi không có dữ liệu | ⚠️ **chưa chạy** — nằm sau điểm `$fatal` |
| **CC-6** | Hằng **âm** `x = −100` | ❌ chỉ golden: `test_negative_constant()` | Hội tụ về **đúng −100** (khác phía dương hội tụ về `x−1`). Chứng minh **bất đối xứng** do floor |
| **CC-7** | Quét vét cạn biên `x ∈ {−128,−127,−1,0,1,126,127}` | ❌ chỉ golden: `test_boundaries()` | Bảo đảm không tràn 8 bit đầu ra |
| **CC-8** | Vét cạn **vòng hồi tiếp** 256 × 7 tổ hợp | ❌ chỉ golden: `test_feedback_bound()` | Chứng minh INV-3 (`sum_ext ∈ [−256, 254]`) một cách **vét cạn**, không phải lấy mẫu |
| **CC-9** | Ngẫu nhiên 10 000 cặp `(x, y)` | ❌ chỉ golden: `test_randomized()` | Kiểm `y == total // 2` trên mọi tổ hợp lấy mẫu ngẫu nhiên |

## 3. Phân loại ca theo tiêu chí kỹ thuật riêng của G06

Tiêu chí tự nhiên của một bộ lọc IIR là **vị trí của `(x, y)` trong mặt phẳng trạng thái**,
vì hành vi làm tròn phụ thuộc vào **dấu** và **độ lớn của hiệu `x − y`**:

Toàn bộ hành vi quy về **một** đại lượng: bước nhảy mỗi mẫu là `Δ = ⎣(x − y)/2⎦`.

```
                                   x − y
              ≤ −2        −1          0         +1         ≥ +2
            ┌──────────┬──────────┬──────────┬──────────┬──────────┐
     Δ =    │  ≤ −1    │   −1     │    0     │    0     │   ≥ +1   │
            │ dốc xuống│ giảm 1   │ bất động │ ĐỨNG YÊN │  dốc lên │
            │          │ rồi dừng │          │    ⚠     │          │
            ├──────────┼──────────┼──────────┼──────────┼──────────┤
 ca đã có   │ CC-1'    │    —     │  CC-2    │  CC-3    │  CC-1    │
 trên RTL   │ ✅       │  ❌      │  ✅      │  ❌      │  ✅      │
            ├──────────┼──────────┼──────────┼──────────┼──────────┤
 ca chỉ có  │ CC-6     │    —     │  CC-6    │  CC-3    │    —     │
 ở golden   │          │          │          │          │          │
            └──────────┴──────────┴──────────┴──────────┴──────────┘

  ⚠ CỘT "+1" LÀ TOÀN BỘ NỘI DUNG CỦA ĐỀ:
       ⎣+1/2⎦ = 0  ⟹  đứng yên          (đi LÊN thì dừng sớm 1 LSB)
       ⎣−1/2⎦ = −1 ⟹  vẫn giảm được     (đi XUỐNG thì tới đúng đích)
    ⟹ bộ lọc hội tụ về x−1 khi đi lên, về x khi đi xuống.
    ⟹ TRƯỜNG HỢP NGUY HIỂM NHẤT: y = −1, x = 0 ⟹ x−y = +1 ⟹ KẸT Ở −1 VĨNH VIỄN.
       Ca này CHƯA CÓ Ở BẤT KỲ ĐÂU — kể cả golden model.
```

| Lớp | Đặc trưng | Ca đại diện | Đã chạy trên RTL? |
|---|---|---|:-:|
| **L-A · dốc lớn** | `\|x − y\| ≫ 2`, bộ lọc hoạt động "bình thường" | CC-1, CC-4 | ✅ (CC-4 dừng giữa chừng) |
| **L-B · điểm bất động** | `x − y = 0` | CC-2 | ✅ |
| **L-C · đứng yên phía dương** | `x − y = +1` với `y` nhỏ | CC-3 | ❌ chỉ golden |
| **L-D · bất đối xứng âm** | `x − y = −1` ⟹ vẫn giảm được 1 | — | ❌ **chưa có ở đâu** |
| **L-E · kẹt ở −1** | `y = −1`, `x = 0` | — | ❌ **chưa có ở đâu** |
| **L-F · giao thức** | `valid_in`, reset | CC-5 | ❌ chưa chạy tới |

## 4. Ca **KHÔNG** áp dụng cho đề này — và vì sao

| Ca thường gặp | Vì sao **không** áp dụng cho G06 |
|---|---|
| **Tràn số (overflow)** | **Không thể xảy ra.** RTL mở rộng dấu lên 9 bit **trước** khi cộng (`{x[7],x}` và `{y_q[7],y_q}`), nên `sum_ext ∈ [−256, 254]` vừa khít 9 bit; sau `>>> 1` kết quả vào `[−128, 127]` vừa khít 8 bit. Golden `test_feedback_bound()` kiểm **vét cạn** điều này. Đây là một thiết kế **đúng bằng xây dựng** (correct by construction), không phải đúng nhờ test |
| Bão hoà (saturation) | Không cần, vì không tràn. Khác hẳn G04 (bộ tích luỹ có bão hoà), nơi tràn là bản chất bài toán |
| **Ổn định số học** (limit cycle biên độ lớn) | Charter mục 3 liệt **"ổn định số học"** vào **ngoài phạm vi**. Bộ lọc bậc một cực thực dương luôn ổn định; limit cycle duy nhất là điểm kẹt ở −1 (bậc 0) |
| **IIR bậc cao** | Charter mục 3: ngoài phạm vi |
| **Hệ số lập trình được** | Charter mục 3: ngoài phạm vi. Nếu có, `>>> 1` phải thành bộ nhân hoặc barrel shifter ⟹ đổi hẳn kiến trúc |
| Ca FSM trạng thái bất hợp lệ | Không có FSM. Xem `03_ARCHITECTURE/fsm.md` |
| Glitch tổ hợp trên đầu ra | `y` và `valid_out` đều là chân `Q` của `dfxtp_1` ⟹ glitch bị thanh ghi lọc; chỉ còn là vấn đề công suất |
| Ca nhiều kênh / nhiều clock domain | Khối đơn kênh, một miền clock |

## 5. Ca còn **THIẾU** — khoảng trống kiểm chứng

| ID | Ca thiếu | Vì sao cần | Chi phí |
|---|---|---|---|
| **CC-10** | **Ca đứng yên thật**: reset → `send(1,0)` × 12, kỳ vọng `y = 0` suốt | Charter mục 8 **bắt buộc** ca này. Hiện chỉ có ở golden Python, chưa chạy trên RTL. Đây là ca Charter mục 10 nói thẳng là chỗ hay tắc | 12 dòng `send()` |
| **CC-11** | **Kẹt ở −1**: đưa `y` về −1 rồi `send(0, −1)` × 10 | Ca **nguy hiểm nhất** và **chưa có ở bất kỳ đâu** — kể cả golden. `x − y = 0 − (−1) = +1` ⟹ `Δ = 0` ⟹ kẹt. Nó chứng minh bộ lọc có **sai lệch DC vĩnh viễn** sau mỗi lần đi xuống | 12 dòng |
| **CC-12** | **`x − y = −1`**: ví dụ `y = 5`, `x = 4` ⟹ `y` phải **giảm còn 4** rồi dừng | Cùng với CC-10 tạo thành cặp chứng minh **bất đối xứng** của phép floor: cùng độ lệch 1 LSB nhưng một chiều nhích được, chiều kia thì không | 4 dòng |
| **CC-13** | **Reset giữa dòng** sau khi `y` đã ổn định | `y` về 0 và mất 7 mẫu để bắt lại. Hành vi này chưa từng chạy | 5 dòng |
| **CC-14** | **Chuỗi ngẫu nhiên có scoreboard** trên RTL | Golden có `test_randomized()` 10 000 cặp nhưng **không chạy trên RTL** | ~20 dòng |
| **CC-15** | Bật `` `define G06_SVA `` | INV-1 trong `properties.sv` chưa từng được kiểm tự động | 1 cờ biên dịch |
| **CC-16** | Ca **`x` không dấu** (ví dụ `x = 200`) với kỳ vọng ghi rõ | Khe hở đặc tả ở đầu `functional_spec.md`: cổng khai báo không dấu, xử lý có dấu. Cần một ca chốt cách hiểu | 3 dòng |

### Độ phủ **thực tế** của lần chạy đã ghi log

```
  TB có 11 lệnh send()  →  chạy được 10  →  DỪNG ở lệnh thứ 11 ($fatal)
                                             ↓
                        ca CC-5 (khe valid_in) nằm SAU điểm dừng ⟹ CHƯA CHẠY
```

**Cách nói trung thực:** *"Mô phỏng RTL chạy được 10 trong 11 lệnh `send()` rồi dừng ở một
assertion. Đã kiểm: đáp ứng bước nhảy dương (8 mẫu), đầu vào hằng, dốc xuống từ giá trị lớn.
Chưa kiểm: ca biên âm, khe `valid_in`, ca đứng yên ở giá trị nhỏ, ca kẹt ở −1."*

## 6. Ca cần **bổ sung** khi chuyển sang gate-level / post-layout

| ID | Ca | Vì sao chỉ xuất hiện ở tầng sau | Bằng chứng cần |
|---|---|---|---|
| **GL-1** | Chạy lại toàn bộ TB (**sau khi vá**) trên `netlist.v` | Chứng minh tổng hợp bảo toàn chức năng. `test_matrix.csv`: `L4-GATE = CHUA CHAY` | Thư viện mô phỏng sky130 |
| **GL-2** | Kiểm **vòng hồi tiếp** ở mức gate với SDF | Vòng `y[i] → cộng → dịch → y[i]` là **đường quyết định tần số tối đa** (Charter mục 9). Chỉ mô phỏng có SDF mới thấy nó hỏng khi chu kỳ co lại | SDF sau P&R |
| **GL-3** | Ca **hold** trên vòng `_98_ → _98_` | `timing_report_min.txt` cho slack **0,47 ns** với clock lý tưởng. Đây là vòng ngắn nhất và nó **nằm trong** vòng hồi tiếp | Báo cáo CTS + SDF |
| **GL-4** | Ca công suất với VCD thật | Ước lượng hiện tại 6,04e-05 W (tuần tự 71,2 %) dùng hoạt động mặc định. Bộ lọc IIR có hoạt động chuyển mạch rất khác nhau giữa tín hiệu trơn và tín hiệu nhiễu | VCD từ GL-1 |
| **GL-5** | Ca `y_q` và `y` **sau khi bị hợp nhất** | Yosys đã gộp `y_q` vào `y` (netlist chỉ có 9 FF, không có `\y_q[…]`). Cần xác nhận fanout tăng lên không phá timing | Netlist + SDF |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
