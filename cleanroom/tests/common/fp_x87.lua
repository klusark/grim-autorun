-- Floating point to the last bit: where the original (x87, its precision as the game set it) and ScummVM (SSE, doubles in
-- its C code) may round differently. Lua's numbers are floats on both; cr_log's "%.6f" hides a difference in the last bits,
-- so these log each number exactly: cr_fp_exact gives its 24-bit mantissa and power of two ("12582912p-23" is 1.5), from
-- multiplications by 2 and 0.5 only (exact on both). The places: the lexer, which builds a literal digit by digit
-- (ScummVM's llex.cpp in a double); tonumber and the coercion of strings (ScummVM: sscanf, then a float); tostring
-- ("%d" when the float is an integer, else "%g"); the math library (sin, cos... of degrees through a double on ScummVM,
-- x87's fsin and friends on the original); and the conversions of a float to an integer (format("%d"), strsub, strrep).

cr_fp_exact = function(v)
	if type(v) ~= "number" then
		return cr_word(v)
	end
	if v ~= v then
		return "nan"
	end
	if v == 0 then
		return "0"
	end
	local s = ""
	if v < 0 then
		s = "-"
		v = -v
	end
	if v * 0.5 == v then
		return s .. "inf"
	end
	local e = 0
	while v >= 16777216 do
		v = v * 0.5
		e = e + 1
	end
	while v < 8388608 do
		v = v * 2
		e = e - 1
	end
	return s .. format("%d", v) .. "p" .. e
end

cr_fp = function(key, v)
	cr_log(key, cr_fp_exact(v))
end

-- the exact helper itself, on values every float format has the same way (powers of two, small integers)
cr_t_fp_exact_self = function()
	cr_fp("one", 1)
	cr_fp("half", 0.5)
	cr_fp("three", 3)
	cr_fp("neg", -6)
	cr_fp("zero", 0)
	cr_fp("big", 16777216 * 4)
	cr_fp("small", 0.5 * 0.5 * 0.5 * 0.5 * 0.5 * 0.5 * 0.5 * 0.5)
end
cr_test("fp_exact_self", cr_t_fp_exact_self)

-- literals the lexer builds: a = 10 * a + digit, then the fraction digit * 0.1^k, then the exponent by squaring
cr_t_fp_literal_fraction = function()
	cr_fp("0.1", 0.1)
	cr_fp("0.2", 0.2)
	cr_fp("0.3", 0.3)
	cr_fp("0.7", 0.7)
	cr_fp("1.1", 1.1)
	cr_fp("2.675", 2.675)
	cr_fp("123.456", 123.456)
	cr_fp("9.999999", 9.999999)
	cr_fp("0.000001", 0.000001)
	cr_fp("1234567.8", 1234567.8)
	cr_fp("3.14159265358979", 3.14159265358979)
	cr_fp("0.123456789012345678", 0.123456789012345678)
	cr_fp("0.33333333333333333333", 0.33333333333333333333)
	cr_fp("0.99999999999", 0.99999999999)
end
cr_test("fp_literal_fraction", cr_t_fp_literal_fraction)

cr_t_fp_literal_integer = function()
	cr_fp("16777215", 16777215)
	cr_fp("16777217", 16777217)
	cr_fp("16777219", 16777219)
	cr_fp("33554433", 33554433)
	cr_fp("123456789", 123456789)
	cr_fp("2147483647", 2147483647)
	cr_fp("4294967297", 4294967297)
	cr_fp("12345678901234567890", 12345678901234567890)
	cr_fp("99999999999999999999999", 99999999999999999999999)
end
cr_test("fp_literal_integer", cr_t_fp_literal_integer)

cr_t_fp_literal_exponent = function()
	cr_fp("1e10", 1e10)
	cr_fp("1e30", 1e30)
	cr_fp("1e38", 1e38)
	cr_fp("3.4e38", 3.4e38)
	cr_fp("1e39", 1e39)
	cr_fp("1e-10", 1e-10)
	cr_fp("1e-30", 1e-30)
	cr_fp("1e-38", 1e-38)
	cr_fp("1e-40", 1e-40)
	cr_fp("1e-45", 1e-45)
	cr_fp("1e-50", 1e-50)
	cr_fp("2.5e5", 2.5e5)
	cr_fp("7e-3", 7e-3)
	cr_fp("1.5E+7", 1.5E+7)
	cr_fp("123.456e-7", 123.456e-7)
	cr_fp("0.0000001e7", 0.0000001e7)
end
cr_test("fp_literal_exponent", cr_t_fp_literal_exponent)

-- the same digits compiled at run time (dostring: the lexer again, on a string)
cr_t_fp_dostring = function()
	dostring("CR_FP_V = 0.1")
	cr_fp("0.1", CR_FP_V)
	dostring("CR_FP_V = 16777217")
	cr_fp("16777217", CR_FP_V)
	dostring("CR_FP_V = 1e-40")
	cr_fp("1e-40", CR_FP_V)
	dostring("CR_FP_V = 0.123456789012345678")
	cr_fp("long", CR_FP_V)
	CR_FP_V = nil
end
cr_test("fp_dostring", cr_t_fp_dostring)

-- strings made numbers: tonumber, and arithmetic on a string
cr_t_fp_tonumber = function()
	cr_fp("0.1", tonumber("0.1"))
	cr_fp("1.1", tonumber("1.1"))
	cr_fp("16777217", tonumber("16777217"))
	cr_fp("123456789", tonumber("123456789"))
	cr_fp("long", tonumber("0.123456789012345678"))
	cr_fp("1e38", tonumber("1e38"))
	cr_fp("1e39", tonumber("1e39"))
	cr_fp("1e-40", tonumber("1e-40"))
	cr_fp("1e-50", tonumber("1e-50"))
	cr_fp("halfway", tonumber("1.00000005960464477539"))
	cr_fp("above_half", tonumber("1.0000000596046448"))
	cr_fp("dot5", tonumber(".5"))
	cr_fp("5dot", tonumber("5."))
	cr_fp("plus", tonumber("+5"))
	cr_fp("neg_dot", tonumber("-.25"))
	cr_fp("spaces", tonumber("  2.5  "))
	cr_fp("exp_plus", tonumber("1e+5"))
end
cr_test("fp_tonumber", cr_t_fp_tonumber)

cr_t_fp_tonumber_odd = function()
	cr_fp("hex", tonumber("0x1A"))
	cr_fp("inf", tonumber("inf"))
	cr_fp("nan", tonumber("nan"))
	cr_fp("e_only", tonumber("1e"))
	cr_fp("trailing", tonumber("5 x"))
	cr_fp("two_dots", tonumber("1.2.3"))
	cr_fp("empty", tonumber(""))
	cr_fp("base2", tonumber("101.5", 2))
	cr_fp("base16", tonumber("ff", 16))
	cr_fp("base36", tonumber("zz", 36))
end
cr_scummvm_differs("fp_tonumber_odd", "ScummVM's tonumber is sscanf (lvm.cpp:41-52): it takes hex, inf and nan and refuses 1e; the original's own conversion gives nil, nil, nil and 1") cr_test("fp_tonumber_odd", cr_t_fp_tonumber_odd)

cr_t_fp_coerce = function()
	cr_fp("add", "0.1" + 0)
	cr_fp("mul", "1.1" * 3)
	cr_fp("sub", "16777217" - 0)
	cr_fp("div", "1" / "3")
	cr_fp("neg", -"2.675")
end
cr_test("fp_coerce", cr_t_fp_coerce)

-- tostring: "%d" when the float is an integer, else "%g" (6 digits)
cr_t_fp_tostring = function()
	cr_log("third", tostring(1 / 3))
	cr_log("two_thirds", tostring(2 / 3))
	cr_log("0.1", tostring(0.1))
	cr_log("123456.7", tostring(123456.7))
	cr_log("1234567.5", tostring(1234567.5))
	cr_log("16777216", tostring(16777216))
	cr_log("2^31", tostring(2147483648))
	cr_log("-2^31", tostring(-2147483648))
	cr_log("2^32", tostring(4294967296))
	cr_log("1e-5", tostring(0.00001))
	cr_log("0.0001", tostring(0.0001))
	cr_log("999999.5", tostring(999999.5))
	cr_log("neg_half", tostring(-0.5))
	cr_log("concat", 0.1 .. "|" .. 1 / 7 .. "|" .. 2.5)
end
cr_scummvm_differs("fp_tostring", "ScummVM's %g writes two exponent digits (1e+06), the original's MSVC printf three (1e+006)") cr_test("fp_tostring", cr_t_fp_tostring)

-- arithmetic the VM does in floats: each result rounded to a float on both, whatever the precision inside
cr_t_fp_arith = function()
	cr_fp("1/3", 1 / 3)
	cr_fp("2/3", 2 / 3)
	cr_fp("1/7", 1 / 7)
	cr_fp("10/3", 10 / 3)
	cr_fp("third_times_3", (1 / 3) * 3)
	cr_fp("0.1+0.2", 0.1 + 0.2)
	cr_fp("0.1*3", 0.1 * 3)
	cr_fp("big_plus_one", 16777216 + 1)
	cr_fp("big_plus_three", 16777216 + 3)
	cr_fp("cancel", (1e8 + 1) - 1e8)
	cr_fp("chain", 1.1 * 1.1 * 1.1 * 1.1 * 1.1 * 1.1 * 1.1 * 1.1)
	cr_fp("sum", 0.1 + 0.1 + 0.1 + 0.1 + 0.1 + 0.1 + 0.1 + 0.1 + 0.1 + 0.1)
end
cr_test("fp_arith", cr_t_fp_arith)

-- out of the float range and below its normal numbers: overflow to inf, denormals, underflow to 0
cr_t_fp_range = function()
	local big = 1e38
	cr_fp("overflow", big * 10)
	cr_fp("neg_overflow", -big * 10)
	cr_fp("inf_minus_inf", big * 10 - big * 10)
	local tiny = 1e-38
	cr_fp("denormal", tiny / 1000)
	cr_fp("denormal_back", tiny / 1000 * 1000)
	cr_fp("underflow", tiny * tiny)
	cr_fp("smallest", tiny / 1000 / 1000 / 10)
	cr_log("inf_cmp", big * 10 > big, big * 10 == big * 100)
end
cr_scummvm_differs("fp_range", "inf - inf: on the original a NaN compares equal to anything (x87 compares as MSVC compiled them), so cr_fp_exact gives 0; ScummVM: nan") cr_test("fp_range", cr_t_fp_range)

-- the math library: in degrees, through a double on ScummVM; the original's x87 instructions
cr_t_fp_trig = function()
	cr_fp("sin30", sin(30))
	cr_fp("sin45", sin(45))
	cr_fp("sin60", sin(60))
	cr_fp("sin1", sin(1))
	cr_fp("sin180", sin(180))
	cr_fp("sin360", sin(360))
	cr_fp("sin_big", sin(100000))
	cr_fp("sin_neg", sin(-37.5))
	cr_fp("cos60", cos(60))
	cr_fp("cos90", cos(90))
	cr_fp("cos270", cos(270))
	cr_fp("cos89.9", cos(89.9))
	cr_fp("tan45", tan(45))
	cr_fp("tan89", tan(89))
	cr_fp("tan90", tan(90))
	cr_fp("tan135", tan(135))
end
cr_scummvm_differs("fp_trig", "ScummVM turns degrees into radians with (float)M_PI (lmathlib.cpp:18, TORAD): sin(180) is -8.7e-8 and cos(60) 0.49999997; the original uses a double pi (sin(180) 1.2e-16)") cr_test("fp_trig", cr_t_fp_trig)

cr_t_fp_atrig = function()
	cr_fp("asin1", asin(1))
	cr_fp("asin0.5", asin(0.5))
	cr_fp("asin_small", asin(0.001))
	cr_fp("acos-1", acos(-1))
	cr_fp("acos0.5", acos(0.5))
	cr_fp("acos0.999", acos(0.999))
	cr_fp("atan1", atan(1))
	cr_fp("atan_big", atan(1e30))
	cr_fp("atan_small", atan(1e-5))
end
cr_scummvm_differs("fp_atrig", "the last bit: ScummVM's FROMRAD divides by (float)M_PI (lmathlib.cpp:17), the original by a double pi") cr_test("fp_atrig", cr_t_fp_atrig)

cr_t_fp_math = function()
	cr_fp("sqrt2", sqrt(2))
	cr_fp("sqrt0.5", sqrt(0.5))
	cr_fp("sqrt3", sqrt(3))
	cr_fp("sqrt_big", sqrt(1e38))
	cr_fp("sqrt_denormal", sqrt(1e-40))
	cr_fp("deg1", deg(1))
	cr_fp("rad1", rad(1))
	cr_fp("rad180", rad(180))
	cr_fp("deg_pi", deg(3.14159265358979))
	cr_fp("floor_neg", floor(-0.5))
	cr_fp("ceil_neg", ceil(-0.5))
	cr_fp("floor_big", floor(16777215.5))
	cr_fp("mod_frac", mod(5.5, 2))
	cr_fp("mod_neg", mod(-5.5, 2))
	cr_fp("mod_big", mod(1e10, 3))
	cr_fp("mod_tenth", mod(1, 0.1))
	cr_fp("abs", abs(-0.1))
end
cr_scummvm_differs("fp_math", "deg(1), the last bit: ScummVM multiplies by 180 / (float)M_PI (lmathlib.cpp:72), the original by a double pi") cr_test("fp_math", cr_t_fp_math)

cr_t_fp_pow = function()
	cr_fp("2^0.5", 2 ^ 0.5)
	cr_fp("10^-3", 10 ^ -3)
	cr_fp("1.1^10", 1.1 ^ 10)
	cr_fp("2^24", 2 ^ 24)
	cr_fp("2^-149", 2 ^ -149)
	cr_fp("e_ish", 2.718281828 ^ 2.5)
end
cr_test("fp_pow", cr_t_fp_pow)

-- a float made an integer: truncation (C's cast) or rounding (x87's fistp in the current rounding mode)
cr_t_fp_to_int = function()
	cr_log("d2.5", format("%d", 2.5))
	cr_log("d3.5", format("%d", 3.5))
	cr_log("d-2.5", format("%d", -2.5))
	cr_log("d2.9999999", format("%d", 2.9999999))
	cr_log("d-0.9", format("%d", -0.9))
	cr_log("d1e10", format("%d", 1e10))
	cr_log("d-1e10", format("%d", -1e10))
	cr_log("x255.9", format("%x", 255.9))
	cr_log("c65.9", format("%c", 65.9))
	cr_log("strsub", strsub("abcdefgh", 2.5, 5.5))
	cr_log("strsub_neg", strsub("abcdefgh", -2.5))
	cr_log("strrep", strrep("ab", 2.9))
	cr_log("strrep_neg", strrep("ab", -0.5))
end
cr_scummvm_differs("fp_to_int", "format(\"%d\", 1e10): the original converts to 64 bits and keeps the low 32 (1410065408), ScummVM's cast to int gives INT_MIN") cr_test("fp_to_int", cr_t_fp_to_int)

-- printf's rounding of the double it is given (the float widened)
cr_t_fp_format = function()
	cr_log("f2.675", format("%.2f", 2.675))
	cr_log("f0.125", format("%.2f", 0.125))
	cr_log("f0.375", format("%.2f", 0.375))
	cr_log("f1.005", format("%.2f", 1.005))
	cr_log("f_third", format("%.10f", 1 / 3))
	cr_log("f_tenth", format("%.12f", 0.1))
	cr_log("e_big", format("%.3e", 123456789))
	cr_log("g_small", format("%g", 0.0001234))
	cr_log("g_big", format("%g", 1e20))
	cr_log("g8", format("%.8g", 1 / 3))
	cr_log("f_half_even", format("%.0f", 2.5))
	cr_log("f_half_odd", format("%.0f", 3.5))
end
cr_scummvm_differs("fp_format", "printf: the original's MSVC rounds a tie of the decimal digits up (0.125 to 0.13, 2.5 to 3) and writes three exponent digits") cr_test("fp_format", cr_t_fp_format)

-- table keys are floats: two literals that make the same float are one key
cr_t_fp_table_keys = function()
	local t = { }
	t[16777216] = "a"
	t[16777217] = "b"
	t[0.1] = "c"
	t[tonumber("0.1")] = "d"
	t[1 / 3] = "e"
	cr_log("big", t[16777216])
	cr_log("tenth", t[0.1])
	cr_log("third", t[1 / 3], t[0.33333334])
	local n = 0
	local k = next(t, nil)
	while k do
		n = n + 1
		k = next(t, k)
	end
	cr_log("count", n)
end
cr_test("fp_table_keys", cr_t_fp_table_keys)

-- comparisons at the edge: equal after rounding, or one bit apart
cr_t_fp_compare = function()
	cr_log("tenth", 0.1 == tonumber("0.1"), 0.1 == 1 / 10)
	cr_log("third", 1 / 3 == 0.33333334, 1 / 3 == 0.3333333)
	cr_log("big", 16777217 == 16777216, 16777218 == 16777216)
	cr_log("sin30", sin(30) == 0.5, cos(60) == 0.5)
	cr_log("sqrt", sqrt(2) * sqrt(2) == 2, sqrt(4) == 2)
	cr_log("lt", 0.1 + 0.2 < 0.3, 0.1 + 0.2 > 0.3)
end
cr_scummvm_differs("fp_compare", "cos(60) == 0.5 is false on ScummVM ((float)M_PI in TORAD, lmathlib.cpp:18)") cr_test("fp_compare", cr_t_fp_compare)

-- invalid operations and a division by zero (NaN, inf): apart, in case the original's FPU traps them
cr_t_fp_invalid = function()
	cr_fp("asin_out", asin(1.5))
	cr_fp("sqrt_neg", sqrt(-1))
	cr_fp("neg_frac_pow", (-8) ^ (1 / 3))
end
cr_scummvm_differs("fp_invalid", "on the original a NaN compares equal to anything (x87 compares as MSVC compiled them), so cr_fp_exact gives 0; ScummVM: nan") cr_test("fp_invalid", cr_t_fp_invalid)

cr_t_fp_div_zero = function()
	cr_fp("one_by_zero", 1 / 0)
	cr_fp("neg_by_zero", -1 / 0)
	cr_fp("zero_pow_neg", 0 ^ -1)
	cr_fp("pow_overflow", 2 ^ 128)
	cr_fp("zero_by_zero", 0 / 0)
end
cr_scummvm_differs("fp_div_zero", "0 / 0: on the original a NaN compares equal to anything (x87 compares as MSVC compiled them), so cr_fp_exact gives 0; ScummVM: nan") cr_test("fp_div_zero", cr_t_fp_div_zero)
