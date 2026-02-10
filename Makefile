lint:
	verilator --lint-only src/project.v
	verible-verilog-lint src/project.v
