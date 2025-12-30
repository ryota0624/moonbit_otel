// Resource represents an immutable representation of the entity producing telemetry.
// For example, a process producing telemetry that is running in a container on Kubernetes
// has a Pod name, a namespace, and possibly a deployment name.

///|
pub struct Resource {
  attributes : Attributes
} derive(ToJson)

///|
pub impl Hash for Resource with hash_combine(self, hasher) {
  self.attributes.map.each(fn(key, value) {
    hasher.combine_string(key)
    match value {
      AttributeValue::String(s) => hasher.combine_string(s)
      AttributeValue::Int(i) => hasher.combine_int(i)
      AttributeValue::Bool(b) => hasher.combine_bool(b)
      AttributeValue::Double(d) => hasher.combine_double(d)
    }
  })
}

///|
pub impl Eq for Resource with equal(self, other : Resource) -> Bool {
  if self.attributes.size() != other.attributes.size() {
    return false
  }
  for kv in self.attributes.map {
    let (key, value) = kv
    match other.attributes.get(key) {
      Some(v) => if value != v { return false }
      None => return false
    }
  }
  true
}

///|
pub fn Resource::to_protobuf(self : Resource) -> @resource.Resource {
  let resourece = @resource.Resource::default()
  self.attributes.map.each(fn(key, value) {
    let any_value = value.to_protobuf()
    let key_value = @otel_common.KeyValue::{ key, value: any_value }
    resourece.attributes.push(key_value)
  })
  resourece
}

// Create an empty Resource

///|
pub fn Resource::empty() -> Resource {
  { attributes: Attributes::new() }
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
  let new_attributes = self.attributes.with_string(key, value)
  { attributes: new_attributes }
}

// Add an int attribute to the Resource, returning a new Resource

///|
pub fn Resource::with_int(
  self : Resource,
  key : String,
  value : Int,
) -> Resource {
  let new_attributes = self.attributes.with_int(key, value)
  { attributes: new_attributes }
}

// Add a bool attribute to the Resource, returning a new Resource

///|
pub fn Resource::with_bool(
  self : Resource,
  key : String,
  value : Bool,
) -> Resource {
  let new_attributes = self.attributes.with_bool(key, value)
  { attributes: new_attributes }
}

// Add a double attribute to the Resource, returning a new Resource

///|
pub fn Resource::with_double(
  self : Resource,
  key : String,
  value : Double,
) -> Resource {
  let new_attributes = self.attributes.with_double(key, value)
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
  let mut result = self.attributes
  other.attributes.each(fn(key, value) {
    match value {
      String(s) => result = result.with_string(key, s)
      Int(i) => result = result.with_int(key, i)
      Bool(b) => result = result.with_bool(key, b)
      Double(d) => result = result.with_double(key, d)
    }
  })
  { attributes: result }
}

// Check if an attribute exists in the Resource

///|
pub fn Resource::contains(self : Resource, key : String) -> Bool {
  self.attributes.contains(key)
}

// Get the number of attributes in the Resource

///|
pub fn Resource::size(self : Resource) -> Int {
  self.attributes.size()
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
