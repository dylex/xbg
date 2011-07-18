CC=gcc
CFLAGS=-g -O3 -Wall -D_GNU_SOURCE=1
LDFLAGS=-lm
GIMPDIR=~/.gimp-2.6

default: sunpos $(GIMPDIR)/gradients/prism.ggr
sunpos: main.o sunpos.o
$(GIMPDIR)/gradients/%.ggr: %.ggr
	install -m 644 $< $@
