run_all:
	cd js && moon run --target js cmd
	cd native && moon run --target native cmd
	cd wasm && make run

moon_check:
	cd js && moon check --target js cmd
	cd native && moon check --target native cmd
	cd wasm && moon check
