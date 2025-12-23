fn main {

	let factory = @lib.http_client_factory()
	run_async(fn() {
		try {
			@cmd_main.run_example(factory)
		} catch {
			err => {
				// println("Error: " + err.to_string())
				()
			}
		}
	})
}

fn run_async(f : async () -> Unit noraise) -> Unit = "%async.run"
