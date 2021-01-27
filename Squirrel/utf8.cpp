/*
 *  utf8.cpp
 *  Squirrel
 *
 *  Created by 弓辰 on 2011/12/31.
 *  Copyright 2011 __MyCompanyName__. All rights reserved.
 *
 */

#include "utf8.h"
#include "utf8/unchecked.h"


unsigned utf8len(const char *text, unsigned octet_len) {
  return utf8::unchecked::distance(text, text + octet_len);
}