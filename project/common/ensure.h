#pragma once

#include <assert.h>

#ifdef NDEBUG
	#define ensure(expr)	if (!expr) {LOG("WARNING: ensure condition failed: %s (%s:%d)", _CRT_WIDE(#expr), __FILE__, __LINE__);}
#else
	#define ensure(expr)	assert(expr)
#endif
