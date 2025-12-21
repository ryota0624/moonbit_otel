// Context represents a propagation context that carries request-scoped values
// across API boundaries and between logically associated execution units.
///|
struct Context {
  values : Map[String, ContextValue]
}

// ContextValue represents a value that can be stored in a Context

///|
enum ContextValue {
  StringValue(String)
  IntValue(Int)
  BoolValue(Bool)
  DoubleValue(Double)
} derive(Eq, Show)

// Create an empty Context

///|
pub fn Context::empty() -> Context {
  { values: Map::new() }
}

// Create a new Context

///|
pub fn Context::new() -> Context {
  Context::empty()
}

// Set a string value in the Context, returning a new Context

///|
pub fn Context::with_string(
  self : Context,
  key : String,
  value : String,
) -> Context {
  let new_values = self.values.copy()
  new_values.set(key, StringValue(value))
  { values: new_values }
}

// Set an int value in the Context, returning a new Context

///|
pub fn Context::with_int(self : Context, key : String, value : Int) -> Context {
  let new_values = self.values.copy()
  new_values.set(key, IntValue(value))
  { values: new_values }
}

// Set a bool value in the Context, returning a new Context

///|
pub fn Context::with_bool(
  self : Context,
  key : String,
  value : Bool,
) -> Context {
  let new_values = self.values.copy()
  new_values.set(key, BoolValue(value))
  { values: new_values }
}

// Set a double value in the Context, returning a new Context

///|
pub fn Context::with_double(
  self : Context,
  key : String,
  value : Double,
) -> Context {
  let new_values = self.values.copy()
  new_values.set(key, DoubleValue(value))
  { values: new_values }
}

// Get a value from the Context

///|
pub fn Context::get(self : Context, key : String) -> ContextValue? {
  self.values.get(key)
}

// Get a string value from the Context

///|
pub fn Context::get_string(self : Context, key : String) -> String? {
  match self.get(key) {
    Some(StringValue(s)) => Some(s)
    _ => None
  }
}

// Get an int value from the Context

///|
pub fn Context::get_int(self : Context, key : String) -> Int? {
  match self.get(key) {
    Some(IntValue(i)) => Some(i)
    _ => None
  }
}

// Get a bool value from the Context

///|
pub fn Context::get_bool(self : Context, key : String) -> Bool? {
  match self.get(key) {
    Some(BoolValue(b)) => Some(b)
    _ => None
  }
}

// Get a double value from the Context

///|
pub fn Context::get_double(self : Context, key : String) -> Double? {
  match self.get(key) {
    Some(DoubleValue(d)) => Some(d)
    _ => None
  }
}

// Check if a key exists in the Context

///|
pub fn Context::contains(self : Context, key : String) -> Bool {
  self.values.get(key) is Some(_)
}

// Get the number of values in the Context

///|
pub fn Context::size(self : Context) -> Int {
  self.values.length()
}
