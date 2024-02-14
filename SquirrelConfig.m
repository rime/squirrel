#import "SquirrelConfig.h"

#import <rime_api.h>

@implementation SquirrelOptionSwitcher

- (instancetype)initWithSchemaId:(NSString *)schemaId
                        switcher:(NSDictionary<NSString *, NSString *> *)switcher
                    optionGroups:(NSDictionary<NSString *, NSArray<NSString *> *> *)optionGroups {
  if (self = [super init]) {
    _schemaId = schemaId;
    _switcher = switcher;
    _optionGroups = optionGroups;
    _optionNames = switcher.allKeys;
  }
  return self;
}

- (instancetype)initWithSchemaId:(NSString *)schemaId {
  if (self = [super init]) {
    _schemaId = schemaId;
    _switcher = nil;
    _optionGroups = nil;
    _optionNames = nil;
  }
  return self;
}

- (NSArray<NSString *> *)optionStates {
  return _switcher.allValues;
}

- (BOOL)updateSwitcher:(NSDictionary<NSString *, NSString *> *)switcher {
  if (switcher.count != _switcher.count) {
    return NO;
  }
  NSMutableDictionary *updatedSwitcher = [[NSMutableDictionary alloc]
                                          initWithCapacity:switcher.count];
  for (NSString *option in _optionNames) {
    if (switcher[option] == nil) {
      return NO;
    }
    updatedSwitcher[option] = switcher[option];
  }
  _switcher = [updatedSwitcher copy];
  return YES;
}

- (BOOL)updateGroupState:(NSString *)optionState
                ofOption:(NSString *)optionName {
  NSArray *optionGroup = _optionGroups[optionName];
  if (![optionGroup containsObject:optionState]) {
    return NO;
  }
  NSMutableDictionary *updatedSwitcher = [_switcher mutableCopy];
  for (NSString *option in optionGroup) {
    updatedSwitcher[option] = optionState;
  }
  _switcher = [updatedSwitcher copy];
  return YES;
}

- (BOOL)containsOption:(NSString *)optionName {
  return [_optionNames containsObject:optionName];
}

- (NSMutableDictionary<NSString *, NSString *> *)mutableSwitcher {
  return [_switcher mutableCopy];
}

@end // SquirrelOptionSwitcher


@implementation SquirrelConfig {
  NSCache *_cache;
  RimeConfig _config;
  SquirrelConfig *_baseConfig;
}

- (instancetype)init {
  if (self = [super init]) {
    _cache = [[NSCache alloc] init];
    _colorSpace = @"srgb";
  }
  return self;
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

- (BOOL)openUserConfig:(NSString *)configId {
  [self close];
  _isOpen = !!rime_get_api()->user_config_open(configId.UTF8String, &_config);
  return _isOpen;
}

- (BOOL)openWithConfigId:(NSString *)configId {
  [self close];
  _isOpen = !!rime_get_api()->config_open(configId.UTF8String, &_config);
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

- (double)getDouble:(NSString *)option
    applyConstraint:(double(*)(double param))func {
  NSNumber *value = [self getOptionalDouble:option];
  return func(value.doubleValue);
}

- (NSNumber *)getOptionalBool:(NSString *)option {
  NSNumber *cachedValue = [self cachedValueOfObjCType:@encode(BOOL) forKey:option];
  if (cachedValue) {
     return cachedValue;
  }
  Bool value;
  if (_isOpen && rime_get_api()->config_get_bool(&_config, option.UTF8String, &value)) {
    NSNumber *number = [NSNumber numberWithBool:(BOOL)value];
    [_cache setObject:number forKey:option];
    return number;
  }
  return [_baseConfig getOptionalBool:option];
}

- (NSNumber *)getOptionalInt:(NSString *)option {
  NSNumber *cachedValue = [self cachedValueOfObjCType:@encode(int) forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  int value;
  if (_isOpen && rime_get_api()->config_get_int(&_config, option.UTF8String, &value)) {
    NSNumber *number = [NSNumber numberWithInt:value];
    [_cache setObject:number forKey:option];
    return number;
  }
  return [_baseConfig getOptionalInt:option];
}

- (NSNumber *)getOptionalDouble:(NSString *)option {
  NSNumber *cachedValue = [self cachedValueOfObjCType:@encode(double) forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  double value;
  if (_isOpen && rime_get_api()->config_get_double(&_config, option.UTF8String, &value)) {
    NSNumber *number = [NSNumber numberWithDouble:value];
    [_cache setObject:number forKey:option];
    return number;
  }
  return [_baseConfig getOptionalDouble:option];
}

- (NSNumber *)getOptionalDouble:(NSString *)option
                applyConstraint:(double(*)(double param))func {
  NSNumber *value = [self getOptionalDouble:option];
  return value ? [NSNumber numberWithDouble:func(value.doubleValue)] : nil;
}

- (NSString *)getString:(NSString *)option {
  NSString *cachedValue = [self cachedValueOfClass:NSString.class forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  const char *value =
    _isOpen ? rime_get_api()->config_get_cstring(&_config, option.UTF8String) : NULL;
  if (value) {
    NSString *string = [@(value) stringByTrimmingCharactersInSet:
                        NSCharacterSet.whitespaceCharacterSet];
    [_cache setObject:string forKey:option];
    return string;
  }
  return [_baseConfig getString:option];
}

- (NSColor *)getColor:(NSString *)option {
  NSColor *cachedValue = [self cachedValueOfClass:NSColor.class forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  NSColor *color = [self colorFromString:[self getString:option]];
  if (color) {
    [_cache setObject:color forKey:option];
    return color;
  }
  return [_baseConfig getColor:option];
}

- (NSImage *)getImage:(NSString *)option {
  NSImage *cachedValue = [self cachedValueOfClass:NSImage.class forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  NSImage *image = [self imageFromFile:[self getString:option]];
  if (image) {
    [_cache setObject:image forKey:option];
    return image;
  }
  return [_baseConfig getImage:option];
}

- (NSUInteger)getListSize:(NSString *)option {
  return rime_get_api()->config_list_size(&_config, option.UTF8String);
}

- (NSArray<NSString *> *)getList:(NSString *)option {
  RimeConfigIterator iterator;
  if (!rime_get_api()->config_begin_list(&iterator, &_config, option.UTF8String)) {
    return nil;
  }
  NSMutableArray *strList = [[NSMutableArray alloc] init];
  while (rime_get_api()->config_next(&iterator)) {
    [strList addObject:[self getString:@(iterator.path)]];
  }
  rime_get_api()->config_end(&iterator);
  return strList;
}

- (SquirrelOptionSwitcher *)getOptionSwitcher {
  RimeConfigIterator switchIter;
  if (!rime_get_api()->config_begin_list(&switchIter, &_config, "switches")) {
    return nil;
  }
  NSMutableDictionary *switcher = [[NSMutableDictionary alloc] init];
  NSMutableDictionary *optionGroups = [[NSMutableDictionary alloc] init];
  while (rime_get_api()->config_next(&switchIter)) {
    int reset = [self getInt:[@(switchIter.path) stringByAppendingString:@"/reset"]];
    NSString *name = [self getString:[@(switchIter.path) stringByAppendingString:@"/name"]];
    if (name) {
      if ([self hasSection:[@"style/!" stringByAppendingString:name]] ||
          [self hasSection:[@"style/" stringByAppendingString:name]]) {
        switcher[name] = reset ? name : [@"!" stringByAppendingString:name];
        optionGroups[name] = @[name];
      }
    } else {
      RimeConfigIterator optionIter;
      if (!rime_get_api()->config_begin_list(&optionIter, &_config,
          [@(switchIter.path) stringByAppendingString:@"/options"].UTF8String)) {
        continue;
      }
      NSMutableArray *optionGroup = [[NSMutableArray alloc] init];
      BOOL hasStyleSection = NO;
      while (rime_get_api()->config_next(&optionIter)) {
        NSString *option = [self getString:@(optionIter.path)];
        [optionGroup addObject:option];
        hasStyleSection |= [self hasSection:[@"style/" stringByAppendingString:option]];
      }
      rime_get_api()->config_end(&optionIter);
      if (hasStyleSection) {
        for (size_t i = 0; i < optionGroup.count; ++i) {
          switcher[optionGroup[i]] = optionGroup[(size_t)reset];
          optionGroups[optionGroup[i]] = optionGroup;
        }
      }
    }
  }
  rime_get_api()->config_end(&switchIter);
  return [[SquirrelOptionSwitcher alloc] initWithSchemaId:_schemaId
                                                 switcher:switcher
                                             optionGroups:optionGroups];
}

- (SquirrelAppOptions *)getAppOptions:(NSString *)appName {
  NSString *rootKey = [@"app_options/" stringByAppendingString:appName];
  SquirrelMutableAppOptions *appOptions = [[SquirrelMutableAppOptions alloc] init];
  RimeConfigIterator iterator;
  if (!rime_get_api()->config_begin_map(&iterator, &_config, rootKey.UTF8String)) {
    return nil;
  }
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
  return appOptions.count > 0 ? appOptions : nil;
}

#pragma mark - Private methods

- (id)cachedValueOfClass:(Class)aClass
                  forKey:(NSString *)key {
  id value = [_cache objectForKey:key];
  if ([value isMemberOfClass:aClass]) {
    return value;
  }
  return nil;
}

- (NSNumber *)cachedValueOfObjCType:(const char *)type
                             forKey:(NSString *)key {
  id value = [_cache objectForKey:key];
  if ([value isMemberOfClass:NSNumber.class] &&
      !strcmp([value objCType], type)) {
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
    // 0xaaBBGGRR
    sscanf(string.UTF8String, "0x%02x%02x%02x%02x", &a, &b, &g, &r);
  } else if (string.length == 8) {
    // 0xBBGGRR
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

- (NSImage *)imageFromFile:(NSString *)filePath {
  if (filePath == nil) {
    return nil;
  }
  NSURL *userDataDir = [NSURL fileURLWithPath:@"~/Library/Rime".stringByExpandingTildeInPath 
                                  isDirectory:YES];
  NSURL *imageFile = [NSURL fileURLWithPath:filePath
                                isDirectory:NO relativeToURL:userDataDir];
  if ([imageFile checkResourceIsReachableAndReturnError:nil]) {
    NSImage *image = [[NSImage alloc] initByReferencingURL:imageFile];
    return image;
  }
  return nil;
}

@end // SquirrelConfig
