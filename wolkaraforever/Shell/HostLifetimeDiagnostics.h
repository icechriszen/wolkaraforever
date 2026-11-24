#pragma once
#include <stdbool.h>
// Explicit diagnostic build/launch only. Records host counters, never guest memory.
bool WKHostDiagnosticsEnabled(void);
bool WKHostDiagnosticsStart(const char *path, double interval, unsigned samples);
void WKHostDiagnosticsCheckpoint(const char *event);
void WKHostDiagnosticsMemory(const char *event);
void WKHostDiagnosticsFinish(int code);
