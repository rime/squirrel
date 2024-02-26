#import "SquirrelConfig.h"

#import <rime_api.h>

@implementation SquirrelConfig {
  NSMutableDictionary* _cache;
  RimeConfig _config;
  SquirrelConfig* _baseConfig;
}

- (instancetype)init {
  if (self = [super init]) {
    _cache = [[NSMutableDictionary alloc] init];
    _colorSpace = @"srgb";
  }
  return self;
}

- (BOOL)openBaseConfig {
  [self close];
  _isOpen = !!rime_get_api()->config_open("squirrel", &_config);
  return _isOpen;
}

- (BOOL)openWithSchemaId:(NSString*)schemaId
              baseConfig:(SquirrelConfig*)baseConfig {
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

- (void)dealloc {
  [self close];
}

- (BOOL)hasSection:(NSString*)section {
  if (_isOpen) {
    RimeConfigIterator iterator = {0};
    if (rime_get_api()->config_begin_map(&iterator, &_config,
                                         section.UTF8String)) {
      rime_get_api()->config_end(&iterator);
      return YES;
    }
  }
  return NO;
}

- (BOOL)getBool:(NSString*)option {
  return [self getOptionalBool:option].boolValue;
}

- (int)getInt:(NSString*)option {
  return [self getOptionalInt:option].intValue;
}

- (double)getDouble:(NSString*)option {
  return [self getOptionalDouble:option].doubleValue;
}

- (NSNumber*)getOptionalBool:(NSString*)option {
  NSNumber* cachedValue = [self cachedValueOfObjCType:@encode(BOOL)
                                               forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  Bool value;
  if (_isOpen &&
      rime_get_api()->config_get_bool(&_config, option.UTF8String, &value)) {
    return _cache[option] = @(!!value);
  }
  return [_baseConfig getOptionalBool:option];
}

- (NSNumber*)getOptionalInt:(NSString*)option {
  NSNumber* cachedValue = [self cachedValueOfObjCType:@encode(int)
                                               forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  int value;
  if (_isOpen &&
      rime_get_api()->config_get_int(&_config, option.UTF8String, &value)) {
    return _cache[option] = @(value);
  }
  return [_baseConfig getOptionalInt:option];
}

- (NSNumber*)getOptionalDouble:(NSString*)option {
  NSNumber* cachedValue = [self cachedValueOfObjCType:@encode(double)
                                               forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  double value;
  if (_isOpen &&
      rime_get_api()->config_get_double(&_config, option.UTF8String, &value)) {
    return _cache[option] = @(value);
  }
  return [_baseConfig getOptionalDouble:option];
}

- (NSString*)getString:(NSString*)option {
  NSString* cachedValue = [self cachedValueOfClass:[NSString class]
                                            forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  const char* value =
      _isOpen ? rime_get_api()->config_get_cstring(&_config, option.UTF8String)
              : NULL;
  if (value) {
    return _cache[option] = @(value);
  }
  return [_baseConfig getString:option];
}

- (NSColor*)getColor:(NSString*)option {
  NSColor* cachedValue = [self cachedValueOfClass:[NSColor class]
                                           forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  NSColor* color = [self colorFromString:[self getString:option]];
  if (color) {
    _cache[option] = color;
    return color;
  }
  return [_baseConfig getColor:option];
}

- (SquirrelAppOptions*)getAppOptions:(NSString*)appName {
  NSString* rootKey = [@"app_options/" stringByAppendingString:appName];
  SquirrelMutableAppOptions* appOptions =
      [[SquirrelMutableAppOptions alloc] init];
  RimeConfigIterator iterator;
  rime_get_api()->config_begin_map(&iterator, &_config, rootKey.UTF8String);
  while (rime_get_api()->config_next(&iterator)) {
    // NSLog(@"DEBUG option[%d]: %s (%s)", iterator.index, iterator.key,
    // iterator.path);
    BOOL value = [self getBool:@(iterator.path)];
    appOptions[@(iterator.key)] = @(value);
  }
  rime_get_api()->config_end(&iterator);
  return [appOptions copy];
}

#pragma mark - Private methods

- (id)cachedValueOfClass:(Class)aClass forKey:(NSString*)key {
  id value = [_cache objectForKey:key];
  if ([value isMemberOfClass:aClass]) {
    return value;
  }
  return nil;
}

- (NSNumber*)cachedValueOfObjCType:(const char*)type forKey:(NSString*)key {
  id value = [_cache objectForKey:key];
  if ([value isMemberOfClass:NSNumber.class] &&
      !strcmp([value objCType], type)) {
    return value;
  }
  return nil;
}

- (NSColor*)colorFromString:(NSString*)string {
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
    return [NSColor colorWithDisplayP3Red:r / 255.0
                                    green:g / 255.0
                                     blue:b / 255.0
                                    alpha:a / 255.0];
  } else {  // sRGB by default
    return [NSColor colorWithSRGBRed:r / 255.0
                               green:g / 255.0
                                blue:b / 255.0
                               alpha:a / 255.0];
  }
}

@end
