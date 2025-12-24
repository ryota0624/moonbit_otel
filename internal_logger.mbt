///|
pub struct InternalLogger {
  print_fn : (String) -> Unit
}

///|
pub fn InternalLogger::log(self : InternalLogger, message : String) -> Unit {
  // println("[Logger] " + message) --- IGNORE ---
  (self.print_fn)("[Logger] " + message)
}

///|
fn InternalLogger::default() -> InternalLogger {
  { print_fn: println }
}

///|
fn InternalLogger::none() -> InternalLogger {
  { print_fn: fn(_) {  } }
}

///|
pub fn InternalLogger::with_fn(print_fn : (String) -> Unit) -> InternalLogger {
  { print_fn, }
}
