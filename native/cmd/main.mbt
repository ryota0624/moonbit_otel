async fn main {
	let factory = @lib.http_client_factory()
	@cmd_main.run_example(factory)
}
