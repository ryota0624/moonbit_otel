// AttributeValue represents a value that can be stored as a Resource attribute

///|
pub(all) enum AttributeValue {
  String(String)
  Int(Int)
  Bool(Bool)
  Double(Double)
  StringArray(Array[String])
  IntArray(Array[Int])
  BoolArray(Array[Bool])
  DoubleArray(Array[Double])
} derive(Eq, Show)

impl ToJson for AttributeValue with to_json(self : AttributeValue) -> Json {
  match self {
    AttributeValue::String(s) => Json::string(s)
    AttributeValue::Int(i) => Json::number(i.to_double())
    AttributeValue::Bool(b) => Json::boolean(b)
    AttributeValue::Double(d) => Json::number(d)
    AttributeValue::StringArray(arr) => Json::array(arr.map(fn(s) { Json::string(s) }))
    AttributeValue::IntArray(arr) => Json::array(arr.map(fn(i) { Json::number(i.to_double()) }))
    AttributeValue::BoolArray(arr) => Json::array(arr.map(fn(b) { Json::boolean(b) }))
    AttributeValue::DoubleArray(arr) => Json::array(arr.map(fn(d) { Json::number(d) }))
  }
}


// Resource represents an immutable representation of the entity producing telemetry.
// For example, a process producing telemetry that is running in a container on Kubernetes
// has a Pod name, a namespace, and possibly a deployment name.

///|
struct Resource {
  attributes : Map[String, AttributeValue]
} derive(ToJson)

// Create an empty Resource

///|
pub fn Resource::empty() -> Resource {
  { attributes: Map::new() }
}

// Create a new Resource with initial attributes

///|
pub fn Resource::new() -> Resource {
  Resource::empty()
}

// Add a string attribute to the Resource, returning a new Resource

///|
pub fn Resource::with_string(
  self : Resource,
  key : String,
  value : String,
) -> Resource {
  let new_attributes = self.attributes.copy()
  new_attributes.set(key, String(value))
  { attributes: new_attributes }
}

// Add an int attribute to the Resource, returning a new Resource

///|
pub fn Resource::with_int(
  self : Resource,
  key : String,
  value : Int,
) -> Resource {
  let new_attributes = self.attributes.copy()
  new_attributes.set(key, Int(value))
  { attributes: new_attributes }
}

// Add a bool attribute to the Resource, returning a new Resource

///|
pub fn Resource::with_bool(
  self : Resource,
  key : String,
  value : Bool,
) -> Resource {
  let new_attributes = self.attributes.copy()
  new_attributes.set(key, Bool(value))
  { attributes: new_attributes }
}

// Add a double attribute to the Resource, returning a new Resource

///|
pub fn Resource::with_double(
  self : Resource,
  key : String,
  value : Double,
) -> Resource {
  let new_attributes = self.attributes.copy()
  new_attributes.set(key, Double(value))
  { attributes: new_attributes }
}

// Add a string array attribute to the Resource, returning a new Resource

///|
pub fn Resource::with_string_array(
  self : Resource,
  key : String,
  value : Array[String],
) -> Resource {
  let new_attributes = self.attributes.copy()
  new_attributes.set(key, StringArray(value))
  { attributes: new_attributes }
}

// Add an int array attribute to the Resource, returning a new Resource

///|
pub fn Resource::with_int_array(
  self : Resource,
  key : String,
  value : Array[Int],
) -> Resource {
  let new_attributes = self.attributes.copy()
  new_attributes.set(key, IntArray(value))
  { attributes: new_attributes }
}

// Add a bool array attribute to the Resource, returning a new Resource

///|
pub fn Resource::with_bool_array(
  self : Resource,
  key : String,
  value : Array[Bool],
) -> Resource {
  let new_attributes = self.attributes.copy()
  new_attributes.set(key, BoolArray(value))
  { attributes: new_attributes }
}

// Add a double array attribute to the Resource, returning a new Resource

///|
pub fn Resource::with_double_array(
  self : Resource,
  key : String,
  value : Array[Double],
) -> Resource {
  let new_attributes = self.attributes.copy()
  new_attributes.set(key, DoubleArray(value))
  { attributes: new_attributes }
}

// Get an attribute value from the Resource

///|
pub fn Resource::get(self : Resource, key : String) -> AttributeValue? {
  self.attributes.get(key)
}

// Get a string attribute from the Resource

///|
pub fn Resource::get_string(self : Resource, key : String) -> String? {
  match self.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

// Get an int attribute from the Resource

///|
pub fn Resource::get_int(self : Resource, key : String) -> Int? {
  match self.get(key) {
    Some(Int(i)) => Some(i)
    _ => None
  }
}

// Get a bool attribute from the Resource

///|
pub fn Resource::get_bool(self : Resource, key : String) -> Bool? {
  match self.get(key) {
    Some(Bool(b)) => Some(b)
    _ => None
  }
}

// Get a double attribute from the Resource

///|
pub fn Resource::get_double(self : Resource, key : String) -> Double? {
  match self.get(key) {
    Some(Double(d)) => Some(d)
    _ => None
  }
}

// Merge two Resources, with attributes from the other Resource taking precedence

///|
pub fn Resource::merge(self : Resource, other : Resource) -> Resource {
  let result = self.attributes.copy()
  other.attributes.each(fn(key, value) { result.set(key, value) })
  { attributes: result }
}

// Check if an attribute exists in the Resource

///|
pub fn Resource::contains(self : Resource, key : String) -> Bool {
  self.attributes.get(key) is Some(_)
}

// Get the number of attributes in the Resource

///|
pub fn Resource::size(self : Resource) -> Int {
  self.attributes.length()
}

// Common semantic conventions for Resource attributes

///|
pub let service_name : String = "service.name"

///|
pub let service_namespace : String = "service.namespace"

///|
pub let service_version : String = "service.version"

///|
pub let service_instance_id : String = "service.instance.id"
