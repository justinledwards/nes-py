# Use the mise tasks as the canonical local workflow.
all: ci

setup:
	mise run setup

test:
	mise run test

clean:
	mise run clean

build:
	mise run build

ci:
	mise run ci
