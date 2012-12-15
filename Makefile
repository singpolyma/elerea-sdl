GHCFLAGS=-Wall -O2 -fno-warn-name-shadowing -XHaskell98
HLINTFLAGS=-XHaskell98 -XCPP -i 'Use camelCase' -i 'Use String' -i 'Use head' -i 'Use string literal' -i 'Use list comprehension' --utf8
VERSION=0.1.1

.PHONY: all clean doc install

all: report.html doc dist/build/libHSelerea-sdl-$(VERSION).a dist/elerea-sdl-$(VERSION).tar.gz

install: dist/build/libHSelerea-sdl-$(VERSION).a
	cabal install

report.html: FRP/Elerea/SDL.hs
	-hlint $(HLINTFLAGS) --report $^

doc: dist/doc/html/elerea-sdl/index.html README

README: elerea-sdl.cabal
	tail -n+$$(( `grep -n ^description: $^ | head -n1 | cut -d: -f1` + 1 )) $^ > .$@
	head -n+$$(( `grep -n ^$$ .$@ | head -n1 | cut -d: -f1` - 1 )) .$@ > $@
	-printf ',s/        //g\n,s/^.$$//g\nw\nq\n' | ed $@
	$(RM) .$@

dist/doc/html/elerea-sdl/index.html: dist/setup-config FRP/Elerea/SDL.hs
	cabal haddock --hyperlink-source

dist/setup-config: elerea-sdl.cabal
	cabal configure

clean:
	find -name '*.o' -o -name '*.hi' | xargs $(RM)
	$(RM) -r dist dist-ghc

dist/build/libHSelerea-sdl-$(VERSION).a: elerea-sdl.cabal dist/setup-config FRP/Elerea/SDL.hs
	cabal build --ghc-options="$(GHCFLAGS)"

dist/elerea-sdl-$(VERSION).tar.gz: elerea-sdl.cabal dist/setup-config README FRP/Elerea/SDL.hs
	cabal check
	cabal sdist
