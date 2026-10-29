# G06 · Máy trạng thái (FSM)

---

## 1. G06 **không có FSM** — và đây là mục có nội dung, không phải mục bỏ trống

G06 là mạch **tuần tự** (có 9 flip-flop) nhưng **không có máy trạng thái điều khiển**. Hai
khái niệm này khác nhau, và phân biệt được chúng là một phần nội dung dạy học của đề.

| Khái niệm | G06 có? | Bằng chứng |
|---|:-:|---|
| Ô nhớ đồng bộ (mạch tuần tự) | ✅ | 9 × `dfxtp_1` trong `synth_stat.txt`; công suất nhóm Sequential = **71,2 %** |
| `always_ff` | ✅ | RTL dòng 23 |
| **Biến trạng thái điều khiển** | ❌ | Không có `typedef enum`, không có biến tên `state`, không có `case` |
| **Nhánh phụ thuộc trạng thái** | ❌ | Chỉ có `if (!rst_n)` và `if (valid_in)` — cả hai phụ thuộc **đầu vào**, không phụ thuộc trạng thái |
| Bộ đếm điều khiển | ❌ | Khác G05 (`count_q[2:0]`) và G07 (`count_q`) |
| Trạng thái bất hợp lệ | ❌ (không tồn tại khái niệm) | — |

## 2. Vì sao mạch tuần tự này **không** cần FSM

Bản chất: **trạng thái trong G06 là DỮ LIỆU, không phải ĐIỀU KHIỂN.**

```
  ┌──────────────────────────────────────────────────────────────────┐
  │  Hai loại "trạng thái" hoàn toàn khác nhau trong thiết kế số      │
  ├──────────────────────────┬───────────────────────────────────────┤
  │  TRẠNG THÁI ĐIỀU KHIỂN   │  TRẠNG THÁI DỮ LIỆU                   │
  │  (control state)         │  (data state)                         │
  ├──────────────────────────┼───────────────────────────────────────┤
  │ • quyết định mạch LÀM GÌ │ • là GIÁ TRỊ mà mạch đang giữ         │
  │ • ít giá trị, có tên     │ • nhiều giá trị, không có tên          │
  │ • đi vào chân SELECT     │ • đi vào chân DỮ LIỆU của bộ tính      │
  │   của mux / decoder      │                                       │
  │ • ví dụ: count_q của G05 │ • ví dụ: y_q của G06                  │
  │   (chọn seed / publish)  │   (là toán hạng của phép cộng)        │
  └──────────────────────────┴───────────────────────────────────────┘
```

`y_q` có **256** giá trị có thể, nhưng **mọi giá trị đều dẫn tới cùng một hành động**: cộng
với `x`, dịch, ghi lại. Không có giá trị nào của `y_q` làm mạch đổi hành vi. Vì vậy vẽ "đồ
thị trạng thái" của `y_q` sẽ cho một đồ thị 256 nút mà **không mang thông tin thiết kế nào** —
nó chỉ là bảng nhân của phép `⎣(x+y)/2⎦`.

**Bằng chứng từ mã, ba dòng:**

```systemverilog
if (valid_in) begin
    y_q      <= y_shift[7:0];   // ← không có điều kiện nào nhắc tới GIÁ TRỊ của y_q
    y        <= y_shift[7:0];
```

So sánh với G05, nơi giá trị của trạng thái **có** quyết định hành vi:

```systemverilog
if (count_q == 3'd0) …          // ← GIÁ TRỊ của count_q chọn nhánh  ⟹ đó là FSM
```

## 3. Nhưng G06 **có** một "máy trạng thái" ở nghĩa hệ động lực

Ở nghĩa toán học, `y[n+1] = f(y[n], x[n])` **là** một hệ động lực rời rạc, và nó có những
tính chất đáng vẽ — chỉ là nó không thuộc loại vẽ bằng bong bóng và mũi tên. Đồ thị đáng vẽ
là **đồ thị điểm bất động** với `x` cố định:

```
   x = 100 cố định, trục y:

   0 ──▶ 50 ──▶ 75 ──▶ 87 ──▶ 93 ──▶ 96 ──▶ 98 ──▶ 99 ──┐
                                                          │ hút vào
                                                       ┌──┘
                                                      99 ⟲  ĐIỂM BẤT ĐỘNG
                                                          (⎣199/2⎦ = 99)
   127 ──▶ 113 ──▶ 106 ──▶ 103 ──▶ 101 ──▶ 100 ──▶ 100 ⟲  ← từ TRÊN xuống thì dừng ở 100!

   ⟹ với x = 100 có HAI điểm bất động: 99 (hút từ dưới) và 100 (hút từ trên).
      Đây chính là bất đối xứng của phép ⎣·⎦, xem functional_spec.md §4.
```

```
   x = 0 cố định:

   +127 ──▶ 63 ──▶ 31 ──▶ 15 ──▶ 7 ──▶ 3 ──▶ 1 ──▶ 0 ⟲    (về đúng 0)
   −128 ──▶ −64 ──▶ −32 ──▶ −16 ──▶ −8 ──▶ −4 ──▶ −2 ──▶ −1 ⟲  ← KẸT Ở −1!
                                                               (⎣−1/2⎦ = −1)
```

| Quan sát | Hệ quả thiết kế |
|---|---|
| Tập điểm bất động với `x` cho trước là `{x−1, x}` (phía dương) | Bộ lọc có **sai lệch DC ±1 LSB** tuỳ chiều tiếp cận |
| Với `x = 0`, điểm bất động là `{−1, 0}` | Sau bất kỳ lần đi xuống nào, `y` **kẹt ở −1 vĩnh viễn** |
| Không có chu trình dài hơn 1 (limit cycle bậc cao) | Bộ lọc bậc một với cực thực dương **không dao động**. Charter mục 3 để "ổn định số học" ngoài phạm vi — ở đây may mắn là không có vấn đề gì |
| Hội tụ trong ≤ 8 bước từ bất kỳ đâu | Vì mỗi bước giảm sai số ít nhất một nửa, và miền rộng 256 ⟹ `log₂256 = 8` |

> 🔎 Đây là nội dung đáng dạy: **"không có FSM" không có nghĩa là "không có gì để phân tích
> về trạng thái"**. Chỉ là công cụ phân tích khác: thay vì bảng chuyển trạng thái, ta dùng
> **điểm bất động và miền hút**.

## 4. Khi nào FSM sẽ xuất hiện ở đề này

| Mở rộng giả định | FSM có cần không? | Số trạng thái |
|---|:-:|---|
| Hệ số **lập trình được** (1/2, 1/4, 1/8) | ❌ vẫn không cần FSM — chỉ cần một thanh ghi hệ số và barrel shifter | — |
| **Nạp hệ số qua hai nhịp** (vì thiếu chân) | ✅ **có** | 2–3 trạng thái: `LOAD_HI`, `LOAD_LO`, `RUN` |
| **Chế độ khởi động nhanh** (mẫu đầu nạp thẳng `y = x` để bỏ 7 chu kỳ quá độ) | ✅ **có** | 2 trạng thái: `FIRST`, `STEADY` — y hệt cơ chế seed của G05 |
| IIR **bậc hai** dùng chung một bộ cộng (chia sẻ tài nguyên) | ✅ **có** | 2 trạng thái: `PASS1`, `PASS2` |
| Thêm bắt tay `ready`/`valid` hai chiều | ✅ **có** | 2 trạng thái: `IDLE`, `BUSY` |

Cả 5 dòng trên đều **ngoài phạm vi** theo Charter mục 3 ("IIR bậc cao, hệ số lập trình được").
Ghi ở đây chỉ để trả lời câu "vì sao đề này không có FSM" bằng cách chỉ ra **cái gì sẽ tạo
ra FSM**.

> **Quy tắc rút ra, áp dụng được cho mọi đề:** FSM xuất hiện khi mạch phải **làm những việc
> khác nhau ở những thời điểm khác nhau**. G06 luôn làm **đúng một việc** ⟹ không có FSM.
> G05 làm ba việc (seed / tích luỹ / công bố) ⟹ có FSM dạng bộ đếm. G07 làm hai việc cạnh
> tranh (cập nhật đỉnh / suy giảm) ⟹ có logic ưu tiên **và** bộ đếm.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
