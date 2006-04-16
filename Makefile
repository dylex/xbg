CC=gcc
CFLAGS=-g -O3 -Wall -D_GNU_SOURCE=1
LDFLAGS=-lm

default: sunpos
sunpos: main.o sunpos.o

install: sunpos xbg.scm xbg.sh
	install sunpos ~/bin
	install xbg.scm ~/.gimp-2.2/scripts
	install xbg.sh ~/bin/xbg
