.PHONY: build test sample

build:
	mkdir -p build && csc -O2 -include-path src -o build/ens-checker src/main.scm 2>/dev/null

test: build
	csi -s tests/tests.scm && bash tests/cli.sh

sample: build
	mkdir -p docs site
	build/ens-checker examples --today 2026-11-16 > docs/sample-output.txt; true
	build/ens-checker examples --today 2026-11-16 --tsv > docs/sample-output.tsv; true
	python3 scripts/site.py docs/sample-output.tsv site/index.html "ens-checker" "Checks declared security facts of a system against ENS (Esquema Nacional de Seguridad) measures for BASICA, MEDIA and ALTA categories. Chicken Scheme." "Synthetic data."
