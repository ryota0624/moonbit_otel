run_all:
	cd js && moon run --target js cmd
	cd native && moon run --target native cmd
	cd wasm && make run
