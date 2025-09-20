# Makefile

.PHONY: format format-check

# Run cairo-format inplace
format:
	.venv/bin/cairo-format -i src/*.cairo
	.venv/bin/cairo-format -i src/**/*.cairo

# Run cairo-format check
format-check:
	.venv/bin/cairo-format -c src/*.cairo
	.venv/bin/cairo-format -c src/**/*.cairo