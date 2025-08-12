# Makefile

.PHONY: all setup format format-check

# Default target
all: setup

# Run setup.sh
setup:
	bash setup.sh

# Run cairo-format inplace
format:
	./venv/bin/cairo-format -i src/*.cairo
	./venv/bin/cairo-format -i src/**/*.cairo

# Run cairo-format check
format-check:
	./venv/bin/cairo-format -c src/*.cairo