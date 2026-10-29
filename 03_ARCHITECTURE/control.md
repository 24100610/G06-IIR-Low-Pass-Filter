# G06 · Phần điều khiển (Control)

---

## 1. G06 có phần điều khiển **tối giản nhất có thể** — đúng hai tín hiệu

G06 là mạch tuần tự, nhưng phần điều khiển của nó chỉ gồm **hai** tín hiệu vào, **không có
bộ đếm, không có trạng thái điều khiển, không có bắt tay hai chiều**. Đây là mạch tuần tự
đơn giản nhất còn có thể gọi là "có điều khiển".

```
 ┌──────────── PHẦN ĐIỀU KHIỂN (toàn bộ) ────────────┐
 │                                                    │
 │   rst_n ──────────┐                                │
 │                   │ (ưu tiên cao nhất, đồng bộ)    │
 │   valid_in ───────┼────────┬──────────────────┐    │
 │                   │        │                  │    │
 └───────────────────┼────────┼──────────────────┼────┘
                     │        │                  │
                     ▼        ▼                  ▼
            ┌────────────┐ ┌──────────┐  ┌──────────────┐
            │ xoá 9 FF   │ │ enable   │  │ D của FF     │
            │ về 0       │ │ 8 FF `y` │  │ valid_out    │
            └────────────┘ └──────────┘  └──────────────┘
                DATAPATH      DATAPATH      (= valid_in trễ 1 nhịp)
```

**Không có** những thứ sau, và mỗi cái "không có" đều có lý do:

| Không có | Vì sao không cần |
|---|---|
| Bộ đếm | Bộ lọc IIR **không có khái niệm cửa sổ**. Mỗi mẫu được xử lý độc lập, không cần biết đang ở mẫu thứ mấy. So với G05 (cần `count_q[2:0]` để biết khi nào cửa sổ đóng) |
| Trạng thái điều khiển / FSM | Chỉ có **một** hành động: cập nhật. Không có nhánh nào |
| Tín hiệu `ready` ra ngoài | Khối **luôn sẵn sàng** — nó xử lý xong trong đúng một chu kỳ |
| Cờ báo lỗi / tràn | Không thể tràn (xem `datapath.md` §5) |
| Bộ nạp nhiều pha | Ngân sách chân đủ (18/24), không cần nạp hai nhịp |

## 2. Bảng tín hiệu điều khiển và tác dụng

| Tín hiệu | Nguồn | Rộng | Tác dụng lên datapath | Dòng RTL |
|---|---|---:|---|---:|
| `rst_n` | cổng vào | 1 | **Đồng bộ**, ưu tiên cao nhất: `y_q ← 0`, `y ← 0`, `valid_out ← 0` | 24–27 |
| `valid_in` | cổng vào | 1 | **Enable** cho 8 FF của `y`; **đồng thời** là giá trị `D` của `valid_out` | 30 |
| (không có tín hiệu điều khiển nội bộ nào) | — | — | — | — |

### Bảng chân lý đầy đủ

| `rst_n` | `valid_in` | `y` kế tiếp | `valid_out` kế tiếp | Hành động |
|:-:|:-:|---|:-:|---|
| 0 | × | **0** | 0 | Reset đồng bộ |
| 1 | 0 | **giữ** | 0 | Đóng băng bộ lọc |
| 1 | 1 | `⎣(x + y)/2⎦` | **1** | Cập nhật một mẫu |

Bảng này có **đúng ba hàng**. Đó là toàn bộ đặc tả điều khiển của G06.

## 3. Quan hệ điều khiển ↔ datapath: hai vai trò của `valid_in`

`valid_in` làm **hai việc khác nhau** trong cùng một chu kỳ, và điều này đáng chú ý:

```systemverilog
end else begin
    valid_out <= 1'b0;          // ① giá trị MẶC ĐỊNH
    if (valid_in) begin
        y_q      <= y_shift[7:0];   // ② ENABLE của thanh ghi dữ liệu
        y        <= y_shift[7:0];
        valid_out <= 1'b1;          // ③ DỮ LIỆU của thanh ghi cờ (đè lên ①)
    end
end
```

| Vai | Tác dụng | Hiện thực phần cứng |
|---|---|---|
| ② **Enable** | Chọn giữa `y_shift` và giá trị cũ của `y` | **Mux 2:1 trên đường `D`** của 8 FF. Thư viện `sky130_fd_sc_hd` **không có** flip-flop kèm chân enable, nên tool bắt buộc phải dựng mux |
| ③ **Dữ liệu** | `valid_out` chỉ đơn giản là `valid_in` trễ một nhịp | Nối thẳng `valid_in → D` của FF `_90_`. **Không** có enable — `valid_out` được nạp **mỗi** chu kỳ |

> 🔎 **Điểm tinh tế:** hai dòng ① và ③ cùng nhau làm cho `valid_out` trở thành **bản sao trễ
> một chu kỳ** của `valid_in`, **không** phụ thuộc trạng thái gì. Kết quả: `valid_out` là một
> thanh ghi **không có enable**, trong khi 8 FF của `y` **có** enable. Điều này giải thích
> vì sao netlist có `mux2i_1 × 1` chứ không phải `× 9`: `abc` chia sẻ logic mux giữa các bit.

### Bằng chứng netlist cho "mux giữ"

Đường hold ngắn nhất (`timing_report_min.txt`) đi qua đúng mux này:

```
  _98_/Q ──▶ _87_/Y (o21ai_0) ──▶ _89_/Y (a21boi_0) ──▶ _98_/D
             ▲                     ▲
             └─ đây là mux giữ: khi valid_in=0, D nhận lại Q
```

Nếu RTL viết `y <= y_shift[7:0];` **vô điều kiện** (bỏ `if (valid_in)`), hai cell này biến
mất, đường hold còn `_98_/Q → _98_/D` trực tiếp — nhưng bộ lọc sẽ **tự chạy** cả khi không
có mẫu mới, trôi dần về 0 (hoặc về −1). Đó là lỗi nghiêm trọng, và ca CC-5 trong
`corner_cases.md` được thiết kế để bắt nó.

## 4. Vì sao reset **đồng bộ** lại quan trọng hơn bình thường ở mạch IIR

| Khía cạnh | Giải thích |
|---|---|
| Bằng chứng reset đồng bộ | Netlist dùng `dfxtp_1` × 9 — loại **không có** chân reset. Nhánh `!rst_n` bị gộp vào logic `D` |
| Vì sao quan trọng hơn ở IIR | Ở mạch không hồi tiếp, reset hỏng chỉ ảnh hưởng vài chu kỳ đầu. Ở IIR, nếu `y_q` khởi động ở giá trị **không xác định** (`X`), giá trị đó **quay vòng mãi mãi** qua bộ cộng và **không bao giờ tự sạch** |
| Nghĩa vụ tầng ngoài | Giữ `rst_n = 0` qua **ít nhất một** cạnh lên. Xung reset bất đồng bộ ngắn hơn một chu kỳ **sẽ bị bỏ qua** |
| Testbench có làm đúng không? | ✅ `repeat(2) @(posedge clk); rst_n = 1;` — hai cạnh lên với `rst_n = 0` |
| Giá trị reset có ý nghĩa gì? | `y ← 0` = "bộ lọc coi như tín hiệu đang ở mức 0". Sau reset, bộ lọc cần **7 mẫu** để bắt kịp một bước nhảy tới 100 (bảng ở `functional_spec.md` §3) |

## 5. Chi phí phần điều khiển — gần như bằng 0

| Thành phần | Số cell | Diện tích | % tổng |
|---|---:|---:|---:|
| Flip-flop `valid_out` | 1 × `dfxtp_1` | 20,0192 µm² | 4,1 % |
| Logic mux giữ (ước lượng: `mux2i_1 × 1` + phần `a21oi_1`/`o21ai_0` dùng chung) | ~3–5 cell | ~20–30 µm² | ~5 % |
| **Tổng điều khiển** | **~5 cell** | **~45 µm²** | **~9 %** |
| Datapath (bộ cộng + 8 FF `y`) | ~49 cell | ~438 µm² | ~91 % |

> So sánh với G05 (`count_q` 3 FF + 2 bộ giải mã ≈ 4 % diện tích) và G07 (`count_q` 3 FF +
> logic ưu tiên **trên đường tới hạn**): G06 là đề có phần điều khiển **rẻ nhất và ít ảnh
> hưởng timing nhất** trong ba đề. Toàn bộ 3,75 ns đường tới hạn là **datapath thuần**.

## 6. Nghĩa vụ của tầng ngoài

| Nghĩa vụ | Vì sao G06 không tự làm | Hậu quả nếu vi phạm |
|---|---|---|
| `valid_in` là **xung một chu kỳ** mỗi mẫu | Khối không có cách nào biết `x` đã đổi hay chưa | Mẫu bị lọc nhiều lần ⟹ bộ lọc nhanh gấp k lần đặc tả ⟹ `f_c` sai |
| Giữ `rst_n = 0` qua ≥ 1 cạnh lên | Reset **đồng bộ** | `y_q` giữ `X` và lan vĩnh viễn |
| Chốt cách hiểu `x`: có dấu hay không dấu | Cổng khai báo không dấu, xử lý có dấu | Mẫu > 127 bị hiểu là số âm |
| Không đưa `X`/`Z` vào `x` khi `valid_in = 1` | Không có logic lọc `X` | `X` **không bao giờ tự sạch** ở mạch IIR |
| Bù sai lệch DC −1 LSB nếu ứng dụng cần | Charter không yêu cầu bù | Độ sáng màn hình lệch 1/256 — thường chấp nhận được |
| Đọc `y` chỉ khi `valid_out = 1` (hoặc chấp nhận giá trị giữ) | `y` giữ giá trị cũ giữa các mẫu | Thường vô hại vì `y` **luôn** là kết quả hợp lệ gần nhất |

> ⚠️ Nghĩa vụ đầu tiên là bẫy tích hợp kinh điển và **ở G06 nó nguy hiểm hơn ở G05**: tại
> G05, `valid_in` giữ mức cao làm cửa sổ đóng sớm — dễ thấy. Tại G06 nó chỉ làm bộ lọc
> **nhanh hơn**, mà "nhanh hơn" thì **nhìn waveform không phân biệt được với đúng** trừ khi
> đếm chu kỳ. Ca kiểm thử cho điều này **chưa có**.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
