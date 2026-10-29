def s8(v):
    v &= 0xff
    return v-256 if v & 0x80 else v

def u8(v):
    return v & 0xff

def arshift1(v):
    # Python // 2 is floor division, matching arithmetic right shift by one.
    return v // 2

def update(x, y_prev):
    x=s8(x)
    y_prev=s8(y_prev)
    total=x+y_prev
    y=arshift1(total)
    # Store/output as signed 8-bit two's complement.
    return s8(y), total

def run(xs, y0=0):
    y=y0
    out=[]
    for x in xs:
        y,total=update(x,y)
        out.append((y,total))
    return out

def test_zero():
    assert run([0]*8)==[(0,0)]*8

def test_constant_even():
    r=run([100]*8)
    assert r[-1][0]==99
    assert r[0][0]==50

def test_step():
    r=run([100]*8,y0=0)
    ys=[a for a,_ in r]
    assert ys==[50,75,87,93,96,98,99,99]

def test_low_value_standing_still():
    r=run([1]*12,y0=0)
    ys=[a for a,_ in r]
    assert ys==[0]*12

def test_negative_shift():
    assert arshift1(-5)==-3
    assert arshift1(-4)==-2
    assert arshift1(5)==2

def test_negative_constant():
    r=run([-100]*8,y0=0)
    ys=[a for a,_ in r]
    assert ys==[-50,-75,-88,-94,-97,-99,-100,-100]

def test_boundaries():
    for x in [-128,-127,-1,0,1,126,127]:
        y,_=update(x,0)
        assert -128 <= y <= 127

def test_feedback_bound():
    for x in range(-128,128):
        for y in (-128,-64,-1,0,1,64,127):
            yn,total=update(x,y)
            assert -256 <= total <= 254
            assert -128 <= yn <= 127

def test_valid_gap_model():
    xs=[100,100,100,100]
    valid=[1,0,1,0,1,1]
    y=0
    ys=[]
    for v in valid:
        if v:
            y,_=update(100,y)
            ys.append(y)
    assert ys==[50,75,87,93]

def test_randomized():
    import random
    random.seed(6)
    for _ in range(10000):
        x=random.randint(-128,127)
        y=random.randint(-128,127)
        yn,total=update(x,y)
        assert yn==total//2
        assert -128 <= yn <= 127

if __name__=="__main__":
    test_zero()
    test_constant_even()
    test_step()
    test_low_value_standing_still()
    test_negative_shift()
    test_negative_constant()
    test_boundaries()
    test_feedback_bound()
    test_valid_gap_model()
    test_randomized()
    print("G06 golden reference PASS")
