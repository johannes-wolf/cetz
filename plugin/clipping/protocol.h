#pragma once

#include "emscripten.h"
#include <cstdint>

#define PROTOCOL_FUNCTION __attribute__((import_module("typst_env"))) extern

extern "C" {

PROTOCOL_FUNCTION
void wasm_minimal_protocol_send_result_to_host(const uint8_t *ptr, size_t len);
PROTOCOL_FUNCTION
void wasm_minimal_protocol_write_args_to_buffer(uint8_t *ptr);

}
