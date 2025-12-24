///|
struct InternalLogger {
  print_fn : (&Show) -> Unit
}

///|
fn InternalLogger::log(self : InternalLogger, message : &Show) -> Unit {
  (self.print_fn)(["[internal logger]", message.to_string()])
}

///|
fn InternalLogger::none() -> InternalLogger {
  { print_fn: fn(_) {  } }
}