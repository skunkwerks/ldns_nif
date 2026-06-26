.POSIX:
.PHONY: build clean lint test

build:
	mix do clean + deps.get + compile

clean:
	rm -rf _build deps

lint:
	mix deps.get
	test -L ~/.mix/plts -o -d ~/.mix/plts || mkdir -p ~/.mix/plts/ldns
	env MIX_DEBUG=0 mix do format --check-formatted + dialyzer --format dialyxir
	env MIX_DEBUG=0 mix credo --strict || true

test:
	mix test --trace
