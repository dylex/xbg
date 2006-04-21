CC=gcc
CFLAGS=-g -O3 -Wall -D_GNU_SOURCE=1
LDFLAGS=-lm

default: sunpos
sunpos: main.o sunpos.o
