#import "SquirrelConfig.h"

#import <rime_api.h>

@implementation SquirrelOptionSwitcher {
  NSString *_schemaId;
  NSDictionary<NSString *, NSString *> *_switcher;
  NSDictionary<NSString *, NSArray<NSString *> *> *_optionGroups;
  NSArray<NSString *> *_optionNames;
}

- (instancetype)initWithSchemaId:(NSString *)schemaId
                        switcher:(NSDictionary<NSString *, NSString *> *)switcher
                    optionGroups:(NSDictionary<NSString *, NSArray<NSString *> *> *)optionGroups{
  self = [super init];
  if (self) {
    _schemaId = schemaId;
    _switcher = switcher;
    _optionGroups = optionGroups;
    _optionNames = [switcher allKeys];
  }
  return self;
}

- (NSString *)schemaId {
  return _schemaId;
}

- (NSArray<NSString *> *)optionNames {
  return _optionNames;
}

- (NSArray<NSString *> *)optionStates {
  return [_switcher allValues];
}

- (NSDictionary<NSString *, NSString *> *)switcher {
  return _switcher;
}

- (BOOL)updateSwitcher:(NSDictionary<NSString *, NSString *> *)switcher {
  if (switcher.count != _switcher.count) {
    return NO;
  }
  NSMutableDictionary<NSString *, NSString *> *updatedSwitcher =
    [[NSMutableDictionary alloc] initWithCapacity:switcher.count];
  for (NSString *option in _optionNames) {
    if (switcher[option] == nil) {
      return NO;
    }
    updatedSwitcher[option] = switcher[option];
  }
  _switcher = [updatedSwitcher copy];
  return YES;
}

- (BOOL)updateGroupState:(NSString *)optionState ofOption:(NSString *)optionName {
  NSArray<NSString *> *optionGroup = _optionGroups[optionName];
  if (!optionGroup || ![optionGroup containsObject:optionState]) {
    return NO;
  }
  NSMutableDictionary<NSString *, NSString *> *updatedSwitcher = [_switcher mutableCopy];
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

@end

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
  NSNumber *cachedValue = [self cachedValueOfClass:[NSNumber class] forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  Bool value;
  if (_isOpen && rime_get_api()->config_get_bool(&_config, option.UTF8String, &value)) {
    return _cache[option] = @(!!value);
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
    return _cache[option] = @(value);
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
    return _cache[option] = @(value);
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

- (NSColor *)getPattern:(NSString *)option {
  NSColor *cachedValue = [self cachedValueOfClass:[NSColor class] forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  NSColor *pattern = [self patternFromFile:[self getString:option]];
  if (pattern) {
    _cache[option] = pattern;
    return pattern;
  }
  return [_baseConfig getPattern:option];
}

- (NSArray<NSString *> *)getList:(NSString *)option {
  NSMutableArray<NSString *> *strList = [[NSMutableArray alloc] init];
  RimeConfigIterator iterator;
  rime_get_api()->config_begin_list(&iterator, &_config, option.UTF8String);
  while (rime_get_api()->config_next(&iterator)) {
    [strList addObject:[self getString:@(iterator.path)]];
  }
  rime_get_api()->config_end(&iterator);
  return strList;
}

- (SquirrelOptionSwitcher *)getOptionSwitcher {
  NSMutableDictionary<NSString *, NSString*> *switcher = [[NSMutableDictionary alloc] init];
  NSMutableDictionary<NSString *, NSArray<NSString *> *> *optionGroups = [[NSMutableDictionary alloc] init];
  RimeConfigIterator switchIter;
  rime_get_api()->config_begin_list(&switchIter, &_config, "switches");
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
      NSMutableArray *optionGroup = [[NSMutableArray alloc] init];
      BOOL hasStyleSection = NO;
      RimeConfigIterator optionIter;
      rime_get_api()->config_begin_list(&optionIter, &_config, [@(switchIter.path) stringByAppendingString:@"/options"].UTF8String);
      while (rime_get_api()->config_next(&optionIter)) {
        NSString *option = [self getString:@(optionIter.path)];
        [optionGroup addObject:option];
        hasStyleSection |= [self hasSection:[@"style/" stringByAppendingString:option]];
      }
      rime_get_api()->config_end(&optionIter);
      if (hasStyleSection) {
        for (NSUInteger i = 0; i < optionGroup.count; ++i) {
          switcher[optionGroup[i]] = optionGroup[reset];
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
  rime_get_api()->config_begin_map(&iterator, &_config, rootKey.UTF8String);
  while (rime_get_api()->config_next(&iterator)) {
    //NSLog(@"DEBUG option[%d]: %s (%s)", iterator.index, iterator.key, iterator.path);
    BOOL value = [self getBool:@(iterator.path)];
    appOptions[@(iterator.key)] = @(value);
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

- (NSColor *)patternFromFile:(NSString *)filePath {
  if (filePath == nil) {
    return nil;
  }
  NSFileManager *fileManager = [NSFileManager defaultManager];
  [fileManager changeCurrentDirectoryPath:[@"~/Library/Rime" stringByStandardizingPath]];
  NSString *patternFile = [filePath stringByStandardizingPath];
  if ([fileManager fileExistsAtPath:patternFile]) {
    NSColor *pattern = [NSColor colorWithPatternImage:[[NSImage alloc] initByReferencingFile:patternFile]];
    return pattern;
  }
  return nil;
}

@end
