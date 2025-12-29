///|
struct InternalLogger {
  print_fn : (&Show) -> Unit
}

///|
fn InternalLogger::log(self : InternalLogger, message : &Show) -> Unit {
  let i_m : &Show = "[internal logger]"
  (self.print_fn)([i_m, message])
}

///|
fn InternalLogger::none() -> InternalLogger {
  { print_fn: fn(_) {  } }
}
