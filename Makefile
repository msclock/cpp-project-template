.PHONY: clean prerequisites pre-commit cmake-configure cmake-build cmake-test cmake-install cmake-uninstall test-build test-build-memcheck test-build-test test-build-test-install test-build-test-install-ccov test-coverage test-valgrind test-sanitizer-address test-sanitizer-leak test-sanitizer-memory test-sanitizer-undefined test-sanitizer test-cppcheck test-clang-tidy test-export-mode docs-clean docs-pip-requirements docs docs-check docs-serve docs-linkcheck template-watch template-build

########################################################################################
# Variables
########################################################################################

# Extra arguments to pass to pre-commit.
PRE_COMMIT_EXTRA_ARGS ?=

# Preset to use for CMake.
PRESET ?= default

# Extra arguments to pass to CMake when configuring.
CONFIGURE ?=

########################################################################################
# Development Environment Management
########################################################################################

# Remove common intermediate files.
clean:
	-rm -rf \
		out \
		docs/_build

# Install standalone tools
prerequisites:
	pipx install --force copier==9.4.1
	pipx install --force pre-commit==4.0.1
	pipx install --force watchfiles==1.0.4

########################################################################################
# Lint
########################################################################################

# Run pre-commit with autofix against all files.
pre-commit:
	pre-commit run --all-files $(PRE_COMMIT_EXTRA_ARGS)

########################################################################################
# CMake build and test
########################################################################################

_PRESET_ARGS = --preset $(PRESET)

cmake-configure:
	cmake -S . $(_PRESET_ARGS) $(CONFIGURE)

cmake-build-template-%:
	cmake --build $(_PRESET_ARGS) --target $*

cmake-build: cmake-build-template-all

cmake-test:
	ctest $(_PRESET_ARGS)

cmake-install:
	cmake --build $(_PRESET_ARGS) --target install

cmake-uninstall:
	cmake --build $(_PRESET_ARGS) --target uninstall

test-build: cmake-configure cmake-build

test-build-memcheck: test-build cmake-build-template-ExperimentalMemCheck

test-build-doxygen: cmake-configure cmake-build-template-ss-cpp-doxygen

test-build-test: test-build cmake-test

test-build-test-install: test-build-test cmake-install cmake-uninstall

test-build-test-install-ccov: test-build-test-install cmake-build-template-ccov-all

test-coverage:
	$(MAKE) test-build-test-install-ccov CONFIGURE="-DBUILD_TESTING=ON -DCODE_COVERAGE=ON $(CONFIGURE) --fresh"

test-valgrind:
	$(MAKE) test-build-memcheck CONFIGURE="-DBUILD_TESTING=ON -DUSE_VALGRIND=ON $(CONFIGURE) --fresh"

test-sanitizer-template-%:
	$(MAKE) test-build-test CONFIGURE="-DBUILD_TESTING=ON -DUSE_SANITIZER=$* $(CONFIGURE) --fresh"

test-sanitizer-address: test-sanitizer-template-address

test-sanitizer-leak: test-sanitizer-template-leak

test-sanitizer-memory: test-sanitizer-template-memory

test-sanitizer-undefined: test-sanitizer-template-undefined

test-sanitizer: test-sanitizer-template-address test-sanitizer-template-leak test-sanitizer-template-memory test-sanitizer-template-undefined

test-cppcheck:
	$(MAKE) test-build CONFIGURE="-DBUILD_TESTING=ON -DUSE_CPPCHECK=ON $(CONFIGURE) --fresh"

test-clang-tidy:
	$(MAKE) test-build CONFIGURE="-DBUILD_TESTING=ON -DUSE_CLANGTIDY=ON $(CONFIGURE) --fresh"

test-export-mode:
	$(MAKE) test-build-test-install CONFIGURE="-DBUILD_TESTING=ON -DVCPKG_EXPORT_MODE=ON $(CONFIGURE) --fresh"

########################################################################################
# Documentation
########################################################################################

docs-clean:
	cmake -E rm -rf docs/_build/html

docs-pip-requirements:
	pip install -r docs/requirements.txt

docs-doxygen: cmake-build-template-ss-cpp-doxygen

docs: docs-pip-requirements docs-doxygen docs-clean
	sphinx-build -T $(SPHINX_EXTRA_OPTS) -c docs docs docs/_build/html

docs-check:
	$(MAKE) docs SPHINX_EXTRA_OPTS="--keep-going -W $(SPHINX_EXTRA_OPTS)"

docs-linkcheck:
	$(MAKE) docs SPHINX_EXTRA_OPTS="-b linkcheck $(SPHINX_EXTRA_OPTS)"

docs-serve: docs-pip-requirements docs-doxygen docs-clean
	python -m http.server --directory docs/_build/html &
	watchfiles "make docs" docs src README.md LICENSE --ignore-paths docs/_build

########################################################################################
# Template
########################################################################################

template-watch:
	watchfiles "make template-build" template includes copier.yml

template-build:
	find . -maxdepth 1 | grep -vE '(\.|\.git|template|includes|copier\.yml)$$' | xargs -I {} rm -r {}
	copier copy -r HEAD --data-file includes/copier-answers-sample.yml $(COPIER_EXTRA_OPTS) -f . .
	rm -rf .copier-answers.yml
