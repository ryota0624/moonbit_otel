// Tests for hex_to_bytes and char_to_int functions

///|
test "hex_to_bytes converts valid lowercase hex string" {
  let hex = "48656c6c6f" // "Hello" in hex
  let bytes = hex_to_bytes(hex)
  assert_false(bytes is None)
  let result = bytes.unwrap()
  assert_eq(result.length(), 5)
  assert_eq(result[0], b'H')
  assert_eq(result[1], b'e')
  assert_eq(result[2], b'l')
  assert_eq(result[3], b'l')
  assert_eq(result[4], b'o')
}

///|
test "hex_to_bytes converts valid uppercase hex string" {
  let hex = "48656C6C6F" // "Hello" in hex with uppercase
  let bytes = hex_to_bytes(hex)
  assert_false(bytes is None)
  let result = bytes.unwrap()
  assert_eq(result.length(), 5)
  assert_eq(result[0], b'H')
  assert_eq(result[1], b'e')
  assert_eq(result[2], b'l')
}

///|
test "hex_to_bytes converts mixed case hex string" {
  let hex = "aAbBcC"
  let bytes = hex_to_bytes(hex)
  assert_false(bytes is None)
  let result = bytes.unwrap()
  assert_eq(result.length(), 3)
  assert_eq(result[0].to_int(), 0xAA)
  assert_eq(result[1].to_int(), 0xBB)
  assert_eq(result[2].to_int(), 0xCC)
}

///|
test "hex_to_bytes converts 32-char trace ID" {
  let trace_id = "0123456789abcdef0123456789abcdef"
  let bytes = hex_to_bytes(trace_id)
  assert_false(bytes is None)
  let result = bytes.unwrap()
  assert_eq(result.length(), 16)
  assert_eq(result[0].to_int(), 0x01)
  assert_eq(result[1].to_int(), 0x23)
  assert_eq(result[15].to_int(), 0xef)
}

///|
test "hex_to_bytes converts 16-char span ID" {
  let span_id = "0123456789abcdef"
  let bytes = hex_to_bytes(span_id)
  assert_false(bytes is None)
  let result = bytes.unwrap()
  assert_eq(result.length(), 8)
  assert_eq(result[0].to_int(), 0x01)
  assert_eq(result[7].to_int(), 0xef)
}

///|
test "hex_to_bytes returns None for odd length string" {
  let hex = "abc" // Odd length
  let bytes = hex_to_bytes(hex)
  assert_true(bytes is None)
}

///|
test "hex_to_bytes returns None for invalid characters" {
  let hex = "abcg" // 'g' is not a valid hex digit
  let bytes = hex_to_bytes(hex)
  assert_true(bytes is None)
}

///|
test "hex_to_bytes returns None for string with spaces" {
  let hex = "ab cd"
  let bytes = hex_to_bytes(hex)
  assert_true(bytes is None)
}

///|
test "hex_to_bytes converts empty string" {
  let hex = ""
  let bytes = hex_to_bytes(hex)
  assert_false(bytes is None)
  let result = bytes.unwrap()
  assert_eq(result.length(), 0)
}

///|
test "hex_to_bytes converts all zeros" {
  let hex = "0000"
  let bytes = hex_to_bytes(hex)
  assert_false(bytes is None)
  let result = bytes.unwrap()
  assert_eq(result.length(), 2)
  assert_eq(result[0].to_int(), 0x00)
  assert_eq(result[1].to_int(), 0x00)
}

///|
test "hex_to_bytes converts all FFs" {
  let hex = "ffff"
  let bytes = hex_to_bytes(hex)
  assert_false(bytes is None)
  let result = bytes.unwrap()
  assert_eq(result.length(), 2)
  assert_eq(result[0].to_int(), 0xFF)
  assert_eq(result[1].to_int(), 0xFF)
}

///|
test "char_to_int converts digit characters" {
  assert_eq(char_to_int('0'), Some(0))
  assert_eq(char_to_int('5'), Some(5))
  assert_eq(char_to_int('9'), Some(9))
}

///|
test "char_to_int converts lowercase hex characters" {
  assert_eq(char_to_int('a'), Some(10))
  assert_eq(char_to_int('f'), Some(15))
}

///|
test "char_to_int converts uppercase hex characters" {
  assert_eq(char_to_int('A'), Some(10))
  assert_eq(char_to_int('F'), Some(15))
}

///|
test "char_to_int returns None for invalid characters" {
  assert_eq(char_to_int('g'), None)
  assert_eq(char_to_int('G'), None)
  assert_eq(char_to_int(' '), None)
  assert_eq(char_to_int('z'), None)
}
