######################################################
ORG=ucsd-cse131
ASGN=01
COMPILER=adder
EXT=adder
BUILD_OPTS=--ghc-options -O0 
######################################################
REPL=cabal v2-repl
CLEAN=cabal v2-clean
BUILD=cabal v2-build $(BUILD_OPTS)
TEST=cabal v2-test $(BUILD_OPTS) --test-show-details=always
EXEC=cabal v2-run $(BUILD_OPTS) -v0
UPDATE=cabal update
######################################################

COMPILEREXEC=$(EXEC) -- $(COMPILER)

UNAME := $(shell uname)
ifeq ($(UNAME), Linux)
  FORMAT=elf64
else
ifeq ($(UNAME), Darwin)
  FORMAT=macho64
else
ifeq ($(UNAME), CYGWIN_NT-10.0)
  FORMAT=win64
  WINSTUFF=-target i686-pc-mingw64
endif
endif
endif

.PHONY: clean

test: clean init.txt
	$(TEST)

bin: init.txt
	$(BUILD)

clean:
	rm -rf tests/output/*.o tests/output/*.s tests/output/*.dSYM tests/output/*.run tests/output/*.log tests/output/*.result tests/output/*.$(COMPILER) tests/output/*.result

distclean: clean 
	$(CLEAN)
	rm -rf dist-newstyle 

ghci: init.txt
	$(REPL) $(BUILD_OPTS)

init.txt:
	$(UPDATE) > init.txt

turnin: 
	git commit -a -m "turnin"
	git push origin main

upstream:
	git remote add upstream https://github.com/$(ORG)/$(ASGN)-$(COMPILER).git

update:
	git pull upstream main --allow-unrelated-histories

tests/output/%.result: tests/output/%.run
	$< > $@

tests/output/%.run: tests/output/%.o c-bits/main.c
	clang $(WINSTUFF) -g -m64 -o $@ c-bits/main.c $<

tests/output/%.o: tests/output/%.s
	nasm -f $(FORMAT) -o $@ $<

tests/output/%.s: tests/input/%.$(EXT)
	$(COMPILEREXEC) $< > $@
