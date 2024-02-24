#import "SquirrelConfig.h"

#import <rime_api.h>

@implementation SquirrelConfig {
  NSMutableDictionary *_cache;
  RimeConfig _config;
  NSString *_schemaId;
  SquirrelConfig *_baseConfig;
  BOOL _isOpen;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _cache = [[NSMutableDictionary alloc] init];
  }
  self.colorSpace = @"srgb";
  return self;
}

- (BOOL)isOpen {
  return _isOpen;
}

- (NSString *)schemaId {
  return _schemaId;
}

- (BOOL)openBaseConfig {
  [self close];
  _isOpen = !!rime_get_api()->config_open("squirrel", &_config);
  return _isOpen;
}

- (BOOL)openWithSchemaId:(NSString *)schemaId
              baseConfig:(SquirrelConfig *)baseConfig {
  [self close];
  _isOpen = !!rime_get_api()->schema_open(schemaId.UTF8String, &_config);
  if (_isOpen) {
    _schemaId = schemaId;
    _baseConfig = baseConfig;
  }
  return _isOpen;
}

- (void)close {
  if (_isOpen) {
    rime_get_api()->config_close(&_config);
    _baseConfig = nil;
    _isOpen = NO;
  }
}

- (BOOL)hasSection:(NSString *)section {
  if (_isOpen) {
    RimeConfigIterator iterator = {0};
    if (rime_get_api()->config_begin_map(&iterator, &_config, section.UTF8String)) {
      rime_get_api()->config_end(&iterator);
      return YES;
    }
  }
  return NO;
}

- (BOOL)getBool:(NSString *)option {
  return [self getOptionalBool:option].boolValue;
}

- (int)getInt:(NSString *)option {
  return [self getOptionalInt:option].intValue;
}

- (double)getDouble:(NSString *)option {
  return [self getOptionalDouble:option].doubleValue;
}

- (NSNumber *)getOptionalBool:(NSString *)option {
  NSNumber* cachedValue = [self cachedValueOfClass:[NSNumber class] forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  Bool value;
  if (_isOpen && rime_get_api()->config_get_bool(&_config, option.UTF8String, &value)) {
    return _cache[option] = [NSNumber numberWithBool:(BOOL)value];
  }
  return [_baseConfig getOptionalBool:option];
}

- (NSNumber *)getOptionalInt:(NSString *)option {
  NSNumber *cachedValue = [self cachedValueOfClass:[NSNumber class] forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  int value;
  if (_isOpen && rime_get_api()->config_get_int(&_config, option.UTF8String, &value)) {
    return _cache[option] = [NSNumber numberWithInt:value];
  }
  return [_baseConfig getOptionalInt:option];

}

- (NSNumber *)getOptionalDouble:(NSString *)option {
  NSNumber *cachedValue = [self cachedValueOfClass:[NSNumber class] forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  double value;
  if (_isOpen && rime_get_api()->config_get_double(&_config, option.UTF8String, &value)) {
    return _cache[option] = [NSNumber numberWithDouble:value];
  }
  return [_baseConfig getOptionalDouble:option];
}

- (NSString *)getString:(NSString *)option {
  NSString *cachedValue = [self cachedValueOfClass:[NSString class] forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  const char *value =
      _isOpen ? rime_get_api()->config_get_cstring(&_config, option.UTF8String) : NULL;
  if (value) {
    return _cache[option] = @(value);
  }
  return [_baseConfig getString:option];
}

- (NSColor *)getColor:(NSString *)option {
  NSColor *cachedValue = [self cachedValueOfClass:[NSColor class] forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  NSColor *color = [self colorFromString:[self getString:option]];
  if (color) {
    _cache[option] = color;
    return color;
  }
  return [_baseConfig getColor:option];
}

- (SquirrelAppOptions *)getAppOptions:(NSString *)appName {
  NSString * rootKey = [@"app_options/" stringByAppendingString:appName];
  SquirrelMutableAppOptions* appOptions = [[SquirrelMutableAppOptions alloc] init];
  RimeConfigIterator iterator;
  rime_get_api()->config_begin_map(&iterator, &_config, rootKey.UTF8String);
  while (rime_get_api()->config_next(&iterator)) {
    //NSLog(@"DEBUG option[%d]: %s (%s)", iterator.index, iterator.key, iterator.path);
    NSNumber *value = [self getOptionalBool:@(iterator.path)] ? :
                      [self getOptionalInt:@(iterator.path)] ? :
                      [self getOptionalDouble:@(iterator.path)];
    if (value) {
      appOptions[@(iterator.key)] = value;
    }
  }
  rime_get_api()->config_end(&iterator);
  return [appOptions copy];
}

#pragma mark - Private methods

- (id)cachedValueOfClass:(Class)aClass forKey:(NSString *)key {
  id value = [_cache objectForKey:key];
  if (value && [value isKindOfClass:aClass]) {
    return value;
  }
  return nil;
}

- (NSColor *)colorFromString:(NSString *)string {
  if (string == nil) {
    return nil;
  }

  int r = 0, g = 0, b = 0, a = 0xff;
  if (string.length == 10) {
    // 0xffccbbaa
    sscanf(string.UTF8String, "0x%02x%02x%02x%02x", &a, &b, &g, &r);
  } else if (string.length == 8) {
    // 0xccbbaa
    sscanf(string.UTF8String, "0x%02x%02x%02x", &b, &g, &r);
  }
  if ([self.colorSpace isEqualToString:@"display_p3"]) {
    return [NSColor colorWithDisplayP3Red:(CGFloat)r / 255.
                                    green:(CGFloat)g / 255.
                                     blue:(CGFloat)b / 255.
                                    alpha:(CGFloat)a / 255.];
  } else {  // sRGB by default
    return [NSColor colorWithSRGBRed:(CGFloat)r / 255.
                               green:(CGFloat)g / 255.
                                blue:(CGFloat)b / 255.
                               alpha:(CGFloat)a / 255.];
  }
}

@end
