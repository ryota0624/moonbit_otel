///| `suspend` will suspend the execution of the current coroutine.
/// The suspension will be handled by a callback passed to `suspend`
async fn[T, E : Error] suspend(
  // `f` is a callback for handling suspension
  f : (
    // the first parameter of `f` is used to resume the execution of the coroutine normally
    (T) -> Unit,
    // the second parameter of `f` is used to cancel the execution of the current coroutine
    // by throwing an error at suspension point
    (E) -> Unit,
  ) -> Unit,
) -> T raise E = "%async.suspend"

///| `run_async` spawn a new coroutine and execute an async function in it
pub fn run_async(f : async () -> Unit noraise) -> Unit = "%async.run"