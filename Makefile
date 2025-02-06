# Makefile

.PHONY: all setup format

# Default target
all: setup

# Run setup.sh
setup:
	bash setup.sh

# Run format.sh
format:
	bash format.sh
