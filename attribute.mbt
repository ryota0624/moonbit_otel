// AttributeValue represents a value that can be stored as a Resource attribute

///|
pub(all) enum AttributeValue {
  // TODO: support more types
  String(String)
  Int(Int)
  Bool(Bool)
  Double(Double)
} derive(Eq, Show)

///|
impl ToJson for AttributeValue with to_json(self : AttributeValue) -> Json {
  match self {
    AttributeValue::String(s) =>
      Json::object({ "stringValue": Json::string(s) })
    AttributeValue::Int(i) =>
      Json::object({ "intValue": Json::number(i.to_double()) })
    AttributeValue::Bool(b) => Json::object({ "boolValue": Json::boolean(b) })
    AttributeValue::Double(d) =>
      Json::object({ "doubleValue": Json::number(d) })
  }
}

///|
pub fn AttributeValue::to_protobuf(
  self : AttributeValue,
) -> @otel_common.AnyValue {
  match self {
    AttributeValue::String(s) =>
      @otel_common.AnyValue::{
        value: @otel_common.AnyValue_Value::StringValue(s),
      }
    AttributeValue::Int(i) =>
      @otel_common.AnyValue::{
        value: @otel_common.AnyValue_Value::IntValue(i.to_int64()),
      }
    AttributeValue::Bool(b) =>
      @otel_common.AnyValue::{
        value: @otel_common.AnyValue_Value::BoolValue(b),
      }
    AttributeValue::Double(d) =>
      @otel_common.AnyValue::{
        value: @otel_common.AnyValue_Value::DoubleValue(d),
      }
  }
}

// Attributes: AttributeValue の Map をカプセル化した構造体
// 内部で Map を保有し、外部からの直接操作を制限する

///|
pub struct Attributes {
  map : Map[String, AttributeValue]
}

///|
impl ToJson for Attributes with to_json(self : Attributes) -> Json {
  self.map
  .iterator()
  .map(fn(kv) {
    let key = kv.0
    let value = kv.1
    Json::object({ "key": Json::string(key), "value": value.to_json() })
  })
  .to_json()
}

///|
pub impl Default for Attributes with default() -> Attributes {
  Attributes::new()
}

///|
pub fn Attributes::new() -> Attributes {
  { map: Map::new() }
}

///|
pub fn Attributes::empty() -> Attributes {
  Attributes::new()
}

///|
pub fn Attributes::copy(self : Attributes) -> Attributes {
  let new_map = self.map.copy()
  { map: new_map }
}

///|
pub fn Attributes::set(
  self : Attributes,
  key : String,
  value : AttributeValue,
) -> Attributes {
  let new_map = self.map.copy()
  new_map.set(key, value)
  { map: new_map }
}

///|
pub fn Attributes::is_empty(self : Attributes) -> Bool {
  self.map.is_empty()
}

///|
pub fn Attributes::with_string(
  self : Attributes,
  key : String,
  value : String,
) -> Attributes {
  let new_map = self.map.copy()
  new_map.set(key, String(value))
  { map: new_map }
}

///|
pub fn Attributes::with_int(
  self : Attributes,
  key : String,
  value : Int,
) -> Attributes {
  let new_map = self.map.copy()
  new_map.set(key, Int(value))
  { map: new_map }
}

///|
pub fn Attributes::with_bool(
  self : Attributes,
  key : String,
  value : Bool,
) -> Attributes {
  let new_map = self.map.copy()
  new_map.set(key, Bool(value))
  { map: new_map }
}

///|
pub fn Attributes::with_double(
  self : Attributes,
  key : String,
  value : Double,
) -> Attributes {
  let new_map = self.map.copy()
  new_map.set(key, Double(value))
  { map: new_map }
}

///|
pub fn Attributes::get(self : Attributes, key : String) -> AttributeValue? {
  self.map.get(key)
}

///|
pub fn Attributes::get_string(self : Attributes, key : String) -> String? {
  match self.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
pub fn Attributes::get_int(self : Attributes, key : String) -> Int? {
  match self.get(key) {
    Some(Int(i)) => Some(i)
    _ => None
  }
}

///|
pub fn Attributes::get_bool(self : Attributes, key : String) -> Bool? {
  match self.get(key) {
    Some(Bool(b)) => Some(b)
    _ => None
  }
}

///|
pub fn Attributes::get_double(self : Attributes, key : String) -> Double? {
  match self.get(key) {
    Some(Double(d)) => Some(d)
    _ => None
  }
}

///|
pub fn Attributes::contains(self : Attributes, key : String) -> Bool {
  self.map.get(key) is Some(_)
}

///|
pub fn Attributes::size(self : Attributes) -> Int {
  self.map.length()
}

///|
pub fn Attributes::each(
  self : Attributes,
  f : (String, AttributeValue) -> Unit,
) -> Unit {
  self.map.each(f)
}

///|
pub fn Attributes::merge(self : Attributes, other : Attributes) -> Attributes {
  let new_map = self.map.merge(other.map)
  { map: new_map }
}

///|
pub fn Attributes::to_protobuf(
  self : Attributes,
) -> Array[@otel_common.KeyValue] {
  self.map
  .iterator()
  .map(fn(kv) {
    let key = kv.0
    let value = kv.1
    @otel_common.KeyValue::{ key, value: value.to_protobuf() }
  })
  .to_array()
}
