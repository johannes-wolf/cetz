CC=emcc
CONFIGURE=emconfigure
EMMAKE=emmake
CFLAGS=-std=c++20 -Oz -sERROR_ON_UNDEFINED_SYMBOLS=0 -sFILESYSTEM=0 -sASSERTIONS=0 -sEXPORT_KEEPALIVE=1 --no-entry -flto
INCLUDE_FLAGS=

all: build

build: main.cpp
	$(CC) $(CFLAGS) main.cpp -o clipping.wasm $(INCLUDE_FLAGS)
	wasi-stub clipping.wasm -o clipping.wasm

clean:
	rm *.wasm || true
