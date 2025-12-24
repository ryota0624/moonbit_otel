///|
struct InternalLogger {
  print_fn : (String) -> Unit
}

///|
fn InternalLogger::log(self : InternalLogger, message : String) -> Unit {
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

