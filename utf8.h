#if defined(__cplusplus)
#define UTF8_API extern "C"
#else
#define UTF8_API
#endif

UTF8_API unsigned long utf8len(const char *text, unsigned octet_len);
