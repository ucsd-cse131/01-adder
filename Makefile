######################################################
ORG=ucsd-cse131
ASGN=01
COMPILER=adder
EXT=adder
######################################################

COMPILEREXEC=stack exec -- $(COMPILER)

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

test: clean
	stack test

bin:
	stack build

tests/output/%.result: tests/output/%.run
	$< > $@

tests/output/%.run: tests/output/%.o c-bits/main.c
	clang $(WINSTUFF) -g -m64 -o $@ c-bits/main.c $<

tests/output/%.o: tests/output/%.s
	nasm -f $(FORMAT) -o $@ $<

tests/output/%.s: tests/input/%.$(EXT)
	$(COMPILEREXEC) $< > $@

clean:
	rm -rf tests/output/*.o tests/output/*.s tests/output/*.dSYM tests/output/*.run tests/output/*.log tests/output/*.result tests/output/*.$(COMPILER) tests/output/*.result

distclean: clean
	stack clean

tags:
	hasktags -x -c lib/

turnin: 
	git commit -a -m "turnin"
	git push origin main

upstream:
	git remote add upstream git@github.com:$(ORG)/$(ASGN)-$(COMPILER).git

update:
	git pull upstream main
