#include "utf8.h"
#include "utf8/unchecked.h"


unsigned long utf8len(const char *text, unsigned octet_len) {
  return utf8::unchecked::distance(text, text + octet_len);
}
