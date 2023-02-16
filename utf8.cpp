#include "utf8.h"
#include "utf8/unchecked.h"
#include <vector>


unsigned long utf8len(const char *text, unsigned octet_len) {
  std::vector <unsigned short> utf16result;
  utf8::unchecked::utf8to16(text, text + octet_len, std::back_inserter(utf16result));
  return utf16result.size();
}
