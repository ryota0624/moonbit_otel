pub(all) struct AnyValue {
  mut value : AnyValue_Value
} derive(Eq, Show)
pub(all) enum AnyValue_Value {
  StringValue(String)
  BoolValue(Bool)
  IntValue(Int64)
  DoubleValue(Double)
  BytesValue(Bytes)
  NotSet
} derive(Eq, Show)
pub impl Default for AnyValue_Value with default() -> AnyValue_Value {
  NotSet
}
pub impl @json.FromJson for AnyValue_Value with from_json(json: Json, path: @json.JsonPath) -> AnyValue_Value raise {
  try { AnyValue_Value::StringValue(json |> @json.from_json(path~)) } catch {
    _ => ()
  } noraise {
    v => return v
  }
  try { AnyValue_Value::BoolValue(json |> @json.from_json(path~)) } catch {
    _ => ()
  } noraise {
    v => return v
  }
  try { AnyValue_Value::IntValue(json |> @json.from_json(path~)) } catch {
    _ => ()
  } noraise {
    v => return v
  }
  try { AnyValue_Value::DoubleValue(json |> @json.from_json(path~)) } catch {
    _ => ()
  } noraise {
    v => return v
  }
  try { AnyValue_Value::BytesValue(json |> @json.from_json(path~)) } catch {
    _ => ()
  } noraise {
    v => return v
  }
AnyValue_Value::NotSet
}
pub impl ToJson for AnyValue_Value with to_json(self : AnyValue_Value) -> Json {
  match self {
    AnyValue_Value::StringValue(v) => v.to_json()
    AnyValue_Value::BoolValue(v) => v.to_json()
    AnyValue_Value::IntValue(v) => v.to_json()
    AnyValue_Value::DoubleValue(v) => v.to_json()
    AnyValue_Value::BytesValue(v) => v.to_json()
    AnyValue_Value::NotSet => Json::null()
  }
}
pub impl @protobuf.Sized for AnyValue with size_of(self) {
  let mut size = 0U
  match self.value {
    StringValue(v) => { size += 1U + { let size = @protobuf.size_of(v); @protobuf.size_of(size) + size } }
    BoolValue(v) => { size += 1U + @protobuf.size_of(v) }
    IntValue(v) => { size += 1U + @protobuf.size_of(v) }
    DoubleValue(v) => { size += 1U + 8U }
    BytesValue(v) => { size += 1U + { let size = @protobuf.size_of(v); @protobuf.size_of(size) + size } }
    NotSet => ()
  }
  size
}
pub impl Default for AnyValue with default() -> AnyValue {
  AnyValue::{
    value : AnyValue_Value::NotSet,
  }
}
pub fn AnyValue::new(value?: AnyValue_Value = AnyValue_Value::NotSet) -> AnyValue {
  AnyValue::{
    value,
  }
}
pub impl @protobuf.Read for AnyValue with read_with_limit(reader : @protobuf.LimitedReader[&@protobuf.Reader]) -> AnyValue raise {
  let msg = AnyValue::default()
  try {
    for {
      match (reader |> @protobuf.read_tag()) {
        (1, _) => msg.value = reader |> @protobuf.read_string() |> AnyValue_Value::StringValue
        (2, _) => msg.value = reader |> @protobuf.read_bool() |> AnyValue_Value::BoolValue
        (3, _) => msg.value = reader |> @protobuf.read_int64() |> AnyValue_Value::IntValue
        (4, _) => msg.value = reader |> @protobuf.read_double() |> AnyValue_Value::DoubleValue
        (5, _) => msg.value = reader |> @protobuf.read_bytes() |> AnyValue_Value::BytesValue
       (_, wire) => reader |> @protobuf.read_unknown(wire)
      }
    }
  } catch {
    @protobuf.EndOfStream => ()
    err => raise err
  }
  msg
}
pub impl @protobuf.Write for AnyValue with write(self: AnyValue, writer : &@protobuf.Writer) -> Unit raise {
  match self.value {
    AnyValue_Value::StringValue(v) => {
      writer |> @protobuf.write_varint(10UL)
      writer |> @protobuf.write_string(v)

     }
    AnyValue_Value::BoolValue(v) => {
      writer |> @protobuf.write_varint(16UL)
      writer |> @protobuf.write_bool(v)

     }
    AnyValue_Value::IntValue(v) => {
      writer |> @protobuf.write_varint(24UL)
      writer |> @protobuf.write_int64(v)

     }
    AnyValue_Value::DoubleValue(v) => {
      writer |> @protobuf.write_varint(33UL)
      writer |> @protobuf.write_double(v)

     }
    AnyValue_Value::BytesValue(v) => {
      writer |> @protobuf.write_varint(42UL)
      writer |> @protobuf.write_bytes(v)

     }
    AnyValue_Value::NotSet => ()
  }
}
pub impl ToJson for AnyValue with to_json(self) {
  let json: Map[String, Json] = {}
  match self.value {
    NotSet => ()
    StringValue(v) => json["stringValue"] = v.to_json()
    BoolValue(v) => json["boolValue"] = v.to_json()
    IntValue(v) => json["intValue"] = v.to_json()
    DoubleValue(v) => json["doubleValue"] = v.to_json()
    BytesValue(v) => json["bytesValue"] = v.to_json()
  }
  Json::object(json)
}
pub impl @json.FromJson for AnyValue with from_json(json: Json, path: @json.JsonPath) -> AnyValue raise {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "Expected an object for AnyValue"))
  }
  let message = AnyValue::default()
  for key, value in obj {
    match (key, value) {
      ("stringValue", value) => message.value = @json.from_json(value, path~)
      ("boolValue", value) => message.value = @json.from_json(value, path~)
      ("intValue", value) => message.value = @json.from_json(value, path~)
      ("doubleValue", value) => message.value = @json.from_json(value, path~)
      ("bytesValue", value) => message.value = @json.from_json(value, path~)
      key => raise @json.JsonDecodeError((path, "Unknown field \{key}"))
    }
  }
  message
}
