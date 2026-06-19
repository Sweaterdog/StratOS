// ============================================================================
// flux_runtime.h — Freestanding Flux Runtime for StratOS
// ============================================================================
// Public C API for executing Flux scripts within the StratOS kernel.
// Called from transpiled .lx code via the bridge module.
//
// Usage:
//   flux_rt_init();
//   flux_rt_set_drawctx(x, y, w, h);
//   flux_rt_load(source_text, source_len);
//   flux_rt_exec();              // Returns 0 on success
//   flux_rt_get_error(buf, len); // Get error message on failure
//   flux_rt_cleanup();
// ============================================================================

#pragma once

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// ---- Lifecycle ----
// Initialize the runtime. Must be called once before any other function.
void flux_rt_init(void);

// Clean up and release runtime state (frees arena if applicable).
void flux_rt_cleanup(void);

// ---- Script Loading ----
// Load a Flux script from a null-terminated string.
// Returns 0 on success, -1 on error (call flux_rt_get_error).
int flux_rt_load(const char* source, int sourceLen);

// ---- Execution ----
// Execute the loaded script. Returns 0 on success, -1 on error.
int flux_rt_exec(void);

// Execute a single frame of the game loop (call draw, check input).
// Returns 0 if game continues, 1 if game has ended, -1 on error.
int flux_rt_frame(int scancode, int ascii, int mouseX, int mouseY, int mouseBtn);

// Check if the loaded script is a game (has a game loop / draw function).
int flux_rt_is_game(void);

// ---- Draw Context ----
// Set the rendering context for the script (window position and size).
void flux_rt_set_drawctx(int x, int y, int w, int h);

// ---- Error Handling ----
// Copy the last error message into buf (null-terminated).
// Returns the length of the error message.
int flux_rt_get_error(char* buf, int maxLen);

// ---- Status Queries ----
// Get the script's requested window width/height (0 if not specified).
int flux_rt_get_width(void);
int flux_rt_get_height(void);

// Get the script's title (copies into buf, returns length).
int flux_rt_get_title(char* buf, int maxLen);

#ifdef __cplusplus
} // extern "C"
#endif
