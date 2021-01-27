/*
 *  utf8.h
 *  Squirrel
 *
 *  Created by 弓辰 on 2011/12/31.
 *  Copyright 2011 __MyCompanyName__. All rights reserved.
 *
 */

#if defined(__cplusplus)
#define UTF8_API extern "C"
#else
#define UTF8_API
#endif

UTF8_API unsigned utf8len(const char *text, unsigned octet_len);
