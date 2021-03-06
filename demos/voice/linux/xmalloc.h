/*
 * Lightweight Autonomic Network Architecture
 * Copyright 2011 Daniel Borkmann <dborkma@tik.ee.ethz.ch>,
 * Swiss federal institute of technology (ETH Zurich)
 * Subject to the GPL.
 */

#ifndef XMALLOC_H
#define XMALLOC_H

#include "compiler.h"

extern __hidden void *xmalloc(size_t size);
extern __hidden void *xvalloc(size_t size);
extern __hidden void *xzmalloc(size_t size);
extern __hidden void *xmallocz(size_t size);
extern __hidden void *xmalloc_aligned(size_t size, size_t alignment);
extern __hidden void *xmemdupz(const void *data, size_t len);
extern __hidden void *xrealloc(void *ptr, size_t nmemb, size_t size);
extern __hidden void xfree(void *ptr);
extern __hidden char *xstrdup(const char *str);
extern __hidden char *xstrndup(const char *str, size_t size);
extern __hidden int xdup(int fd);

#endif /* XMALLOC_H */
