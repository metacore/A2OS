
all:	OberonLoader.32 OberonLoader.64

OberonLoader.32:	OberonLoader.c
	gcc -m32 OberonLoader.c -ldl -lc -o OberonLoader.32

OberonLoader.64:	OberonLoader.c
	gcc -m64 OberonLoader.c -ldl -lc -o OberonLoader.64
