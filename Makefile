run_all:
	moon run --target js cmd/main
	moon run --target native cmd/main

moon_check:
	moon check --target js
	moon check --target native

build_protc_gen_mbt:
	git clone git@github.com:moonbitlang/protoc-gen-mbt.git tmp
	cd tmp && moon build -C cli && cp cli/target/native/release/build/protoc-gen-mbt.exe ../protoc-gen-mbt.exe
	rm -rf tmp
