#import "SquirrelConfig.hh"

#import <rime_api.h>

static NSArray<NSString*>* const scripts = @[
  @"zh-Hans", @"zh-Hant", @"zh-TW", @"zh-HK", @"zh-MO", @"zh-SG", @"zh-CN",
  @"zh"
];

@implementation SquirrelOptionSwitcher

- (instancetype)
        initWithSchemaId:(NSString*)schemaId
                switcher:(NSMutableDictionary<NSString*, NSString*>*)switcher
            optionGroups:
                (NSDictionary<NSString*, NSOrderedSet<NSString*>*>*)optionGroups
    defaultScriptVariant:(NSString*)defaultScriptVariant
    scriptVariantOptions:
        (NSDictionary<NSString*, NSString*>*)scriptVariantOptions {
  self = [super init];
  if (self) {
    _schemaId = schemaId ?: @"";
    _switcher = switcher ?: NSMutableDictionary.dictionary;
    _optionGroups = optionGroups ?: NSDictionary.dictionary;
    _optionNames = [NSSet setWithArray:_switcher.allKeys];
    _optionStates = [NSSet setWithArray:_switcher.allValues];
    _currentScriptVariant =
        defaultScriptVariant
            ?: [NSBundle preferredLocalizationsFromArray:scripts][0];
    _scriptVariantOptions = scriptVariantOptions ?: NSDictionary.dictionary;
  }
  return self;
}

- (instancetype)initWithSchemaId:(NSString*)schemaId {
  return [self initWithSchemaId:schemaId
                       switcher:nil
                   optionGroups:nil
           defaultScriptVariant:nil
           scriptVariantOptions:nil];
}

- (instancetype)init {
  return [self initWithSchemaId:nil
                       switcher:nil
                   optionGroups:nil
           defaultScriptVariant:nil
           scriptVariantOptions:nil];
}

- (BOOL)updateSwitcher:(NSMutableDictionary<NSString*, NSString*>*)switcher {
  if (switcher.count != _switcher.count) {
    return NO;
  }
  NSSet<NSString*>* optNames = [NSSet setWithArray:switcher.allKeys];
  if ([optNames isEqualToSet:_optionNames]) {
    _switcher = switcher;
    _optionStates = [NSSet setWithArray:switcher.allValues];
    return YES;
  }
  return NO;
}

- (BOOL)updateGroupState:(NSString*)optionState ofOption:(NSString*)optionName {
  NSOrderedSet* optionGroup = _optionGroups[optionName];
  if (!optionGroup) {
    return NO;
  }
  if (optionGroup.count == 1) {
    if (![optionName isEqualToString:[optionState hasPrefix:@"!"]
                                         ? [optionState substringFromIndex:1]
                                         : optionState]) {
      return NO;
    }
    _switcher[optionName] = optionState;
  } else if ([optionGroup containsObject:optionState]) {
    for (NSString* option in optionGroup) {
      _switcher[option] = optionState;
    }
  }
  _optionStates = [NSSet setWithArray:_switcher.allValues];
  return YES;
}

- (BOOL)updateCurrentScriptVariant:(NSString*)scriptVariant {
  if (_scriptVariantOptions.count == 0) {
    return NO;
  }
  NSString* scriptVariantCode = _scriptVariantOptions[scriptVariant];
  if (!scriptVariantCode) {
    return NO;
  }
  _currentScriptVariant = scriptVariantCode;
  return YES;
}

- (void)updateWithRimeSession:(RimeSessionId)session {
  for (NSString* state in _optionStates) {
    NSString* updatedState;
    NSArray<NSString*>* optionGroup = [_switcher allKeysForObject:state];
    for (NSString* option in optionGroup) {
      if (rime_get_api()->get_option(session, option.UTF8String)) {
        updatedState = option;
        break;
      }
    }
    updatedState =
        updatedState ?: [@"!" stringByAppendingString:optionGroup[0]];
    if (![updatedState isEqualToString:state]) {
      [self updateGroupState:updatedState ofOption:state];
    }
  }
  // update script variant
  if (_scriptVariantOptions.count > 0) {
    for (NSString* option in _scriptVariantOptions) {
      if ([option hasPrefix:@"!"]
              ? !rime_get_api()->get_option(
                    session, [option substringFromIndex:1].UTF8String)
              : rime_get_api()->get_option(session, option.UTF8String)) {
        [self updateCurrentScriptVariant:option];
        break;
      }
    }
  }
}

@end  // SquirrelOptionSwitcher

@implementation SquirrelConfig {
  NSCache<NSString*, id>* _cache;
  SquirrelConfig* _baseConfig;
  NSColorSpace* _colorSpace;
  NSString* _colorSpaceName;
  RimeConfig _config;
  BOOL _isOpen;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _cache = NSCache.alloc.init;
    _colorSpace = NSColorSpace.sRGBColorSpace;
    _colorSpaceName = @"sRGB";
  }
  return self;
}

- (NSString*)colorSpace {
  return _colorSpaceName;
}

static NSDictionary<NSString*, NSColorSpace*>* const colorSpaceMap = @{
  @"deviceRGB" : NSColorSpace.deviceRGBColorSpace,
  @"genericRGB" : NSColorSpace.genericRGBColorSpace,
  @"sRGB" : NSColorSpace.sRGBColorSpace,
  @"displayP3" : NSColorSpace.displayP3ColorSpace,
  @"adobeRGB" : NSColorSpace.adobeRGB1998ColorSpace,
  @"extendedSRGB" : NSColorSpace.extendedSRGBColorSpace
};

- (void)setColorSpace:(NSString*)colorSpace {
  colorSpace = [colorSpace stringByReplacingOccurrencesOfString:@"_"
                                                     withString:@""];
  if ([_colorSpaceName caseInsensitiveCompare:colorSpace] == NSOrderedSame) {
    return;
  }
  for (NSString* name in colorSpaceMap) {
    if ([name caseInsensitiveCompare:colorSpace] == NSOrderedSame) {
      _colorSpaceName = name;
      _colorSpace = colorSpaceMap[name];
      return;
    }
  }
}

- (BOOL)openBaseConfig {
  [self close];
  _isOpen = (BOOL)rime_get_api()->config_open("squirrel", &_config);
  return _isOpen;
}

- (BOOL)openWithSchemaId:(NSString*)schemaId
              baseConfig:(SquirrelConfig*)baseConfig {
  [self close];
  _isOpen = (BOOL)rime_get_api()->schema_open(schemaId.UTF8String, &_config);
  if (_isOpen) {
    _schemaId = schemaId;
    _baseConfig = baseConfig;
  }
  return _isOpen;
}

- (BOOL)openUserConfig:(NSString*)configId {
  [self close];
  _isOpen =
      (BOOL)rime_get_api()->user_config_open(configId.UTF8String, &_config);
  return _isOpen;
}

- (BOOL)openWithConfigId:(NSString*)configId {
  [self close];
  _isOpen = (BOOL)rime_get_api()->config_open(configId.UTF8String, &_config);
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
    RimeConfigIterator iterator;
    if (rime_get_api()->config_begin_map(&iterator, &_config,
                                         section.UTF8String)) {
      rime_get_api()->config_end(&iterator);
      return YES;
    }
  }
  return NO;
}

- (BOOL)setOption:(NSString*)option withBool:(bool)value {
  return (BOOL)(rime_get_api()->config_set_bool(&_config, option.UTF8String,
                                                value));
}

- (BOOL)setOption:(NSString*)option withInt:(int)value {
  return (
      BOOL)(rime_get_api()->config_set_int(&_config, option.UTF8String, value));
}

- (BOOL)setOption:(NSString*)option withDouble:(double)value {
  return (BOOL)(rime_get_api()->config_set_double(&_config, option.UTF8String,
                                                  value));
}

- (BOOL)setOption:(NSString*)option withString:(NSString*)value {
  return (BOOL)(rime_get_api()->config_set_string(&_config, option.UTF8String,
                                                  value.UTF8String));
}

- (BOOL)getBoolForOption:(NSString*)option {
  return [self getOptionalBoolForOption:option].boolValue;
}

- (int)getIntForOption:(NSString*)option {
  return [self getOptionalIntForOption:option].intValue;
}

- (double)getDoubleForOption:(NSString*)option {
  return [self getOptionalDoubleForOption:option].doubleValue;
}

- (double)getDoubleForOption:(NSString*)option
             applyConstraint:(double (*)(double param))func {
  NSNumber* value = [self getOptionalDoubleForOption:option];
  return func(value.doubleValue);
}

- (NSNumber*)getOptionalBoolForOption:(NSString*)option {
  return [self getOptionalBoolForOption:option alias:nil];
}

- (NSNumber*)getOptionalIntForOption:(NSString*)option {
  return [self getOptionalIntForOption:option alias:nil];
}

- (NSNumber*)getOptionalDoubleForOption:(NSString*)option {
  return [self getOptionalDoubleForOption:option alias:nil];
}

- (NSNumber*)getOptionalDoubleForOption:(NSString*)option
                        applyConstraint:(double (*)(double param))func {
  NSNumber* value = [self getOptionalDoubleForOption:option alias:nil];
  return value ? [NSNumber numberWithDouble:func(value.doubleValue)] : nil;
}

- (NSNumber*)getOptionalBoolForOption:(NSString*)option alias:(NSString*)alias {
  NSNumber* cachedValue = [self cachedValueOfObjCType:@encode(BOOL)
                                               forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  Bool value;
  if (_isOpen &&
      rime_get_api()->config_get_bool(&_config, option.UTF8String, &value)) {
    NSNumber* number = [NSNumber numberWithBool:(BOOL)value];
    [_cache setObject:number forKey:option];
    return number;
  }
  if (alias != nil) {
    NSString* aliasOption = [[option stringByDeletingLastPathComponent]
        stringByAppendingPathComponent:alias.lastPathComponent];
    if (_isOpen && rime_get_api()->config_get_bool(
                       &_config, aliasOption.UTF8String, &value)) {
      NSNumber* number = [NSNumber numberWithBool:(BOOL)value];
      [_cache setObject:number forKey:option];
      return number;
    }
  }
  return [_baseConfig getOptionalBoolForOption:option alias:alias];
}

- (NSNumber*)getOptionalIntForOption:(NSString*)option alias:(NSString*)alias {
  NSNumber* cachedValue = [self cachedValueOfObjCType:@encode(int)
                                               forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  int value;
  if (_isOpen &&
      rime_get_api()->config_get_int(&_config, option.UTF8String, &value)) {
    NSNumber* number = [NSNumber numberWithInt:value];
    [_cache setObject:number forKey:option];
    return number;
  }
  if (alias != nil) {
    NSString* aliasOption = [[option stringByDeletingLastPathComponent]
        stringByAppendingPathComponent:alias.lastPathComponent];
    if (_isOpen && rime_get_api()->config_get_int(
                       &_config, aliasOption.UTF8String, &value)) {
      NSNumber* number = [NSNumber numberWithInt:value];
      [_cache setObject:number forKey:option];
      return number;
    }
  }
  return [_baseConfig getOptionalIntForOption:option alias:alias];
}

- (NSNumber*)getOptionalDoubleForOption:(NSString*)option
                                  alias:(NSString*)alias {
  NSNumber* cachedValue = [self cachedValueOfObjCType:@encode(double)
                                               forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  double value;
  if (_isOpen &&
      rime_get_api()->config_get_double(&_config, option.UTF8String, &value)) {
    NSNumber* number = [NSNumber numberWithDouble:value];
    [_cache setObject:number forKey:option];
    return number;
  }
  if (alias != nil) {
    NSString* aliasOption = [[option stringByDeletingLastPathComponent]
        stringByAppendingPathComponent:alias.lastPathComponent];
    if (_isOpen && rime_get_api()->config_get_double(
                       &_config, aliasOption.UTF8String, &value)) {
      NSNumber* number = [NSNumber numberWithDouble:value];
      [_cache setObject:number forKey:option];
      return number;
    }
  }
  return [_baseConfig getOptionalDoubleForOption:option alias:alias];
}

- (NSNumber*)getOptionalDoubleForOption:(NSString*)option
                                  alias:(NSString*)alias
                        applyConstraint:(double (*)(double param))func {
  NSNumber* value = [self getOptionalDoubleForOption:option alias:alias];
  return value ? [NSNumber numberWithDouble:func(value.doubleValue)] : nil;
}

- (NSString*)getStringForOption:(NSString*)option {
  return [self getStringForOption:option alias:nil];
}

- (NSColor*)getColorForOption:(NSString*)option {
  return [self getColorForOption:option alias:nil];
}

- (NSImage*)getImageForOption:(NSString*)option {
  return [self getImageForOption:option alias:nil];
}

- (NSString*)getStringForOption:(NSString*)option alias:(NSString*)alias {
  NSString* cachedValue =
      [self cachedValueOfClass:NSString.class forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  const char* value =
      _isOpen ? rime_get_api()->config_get_cstring(&_config, option.UTF8String)
              : NULL;
  if (value) {
    NSString* string = [@(value)
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    [_cache setObject:string forKey:option];
    return string;
  }
  if (alias != nil) {
    NSString* aliasOption = [[option stringByDeletingLastPathComponent]
        stringByAppendingPathComponent:alias.lastPathComponent];
    value = _isOpen ? rime_get_api()->config_get_cstring(&_config,
                                                         aliasOption.UTF8String)
                    : NULL;
    if (value) {
      NSString* string = [@(value)
          stringByTrimmingCharactersInSet:NSCharacterSet
                                              .whitespaceCharacterSet];
      [_cache setObject:string forKey:option];
      return string;
    }
  }
  return [_baseConfig getStringForOption:option alias:alias];
}

- (NSColor*)getColorForOption:(NSString*)option alias:(NSString*)alias {
  NSColor* cachedValue = [self cachedValueOfClass:NSColor.class forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  NSColor* color = [self colorFromString:[self getStringForOption:option]];
  if (color) {
    [_cache setObject:color forKey:option];
    return color;
  }
  if (alias != nil) {
    NSString* aliasOption = [option.stringByDeletingLastPathComponent
        stringByAppendingPathComponent:alias.lastPathComponent];
    color = [self colorFromString:[self getStringForOption:aliasOption]];
    if (color) {
      [_cache setObject:color forKey:option];
      return color;
    }
  }
  return [_baseConfig getColorForOption:option alias:alias];
}

- (NSImage*)getImageForOption:(NSString*)option alias:(NSString*)alias {
  NSImage* cachedValue = [self cachedValueOfClass:NSImage.class forKey:option];
  if (cachedValue) {
    return cachedValue;
  }
  NSImage* image = [self imageFromFile:[self getStringForOption:option]];
  if (image) {
    [_cache setObject:image forKey:option];
    return image;
  }
  if (alias != nil) {
    NSString* aliasOption = [option.stringByDeletingLastPathComponent
        stringByAppendingPathComponent:alias.lastPathComponent];
    image = [self imageFromFile:[self getStringForOption:aliasOption]];
    if (image) {
      [_cache setObject:image forKey:option];
      return image;
    }
  }
  return [_baseConfig getImageForOption:option];
}

- (NSUInteger)getListSizeForOption:(NSString*)option {
  return rime_get_api()->config_list_size(&_config, option.UTF8String);
}

- (NSArray<NSString*>*)getListForOption:(NSString*)option {
  RimeConfigIterator iterator;
  if (!rime_get_api()->config_begin_list(&iterator, &_config,
                                         option.UTF8String)) {
    return nil;
  }
  NSMutableArray<NSString*>* strList = NSMutableArray.alloc.init;
  while (rime_get_api()->config_next(&iterator))
    [strList addObject:[self getStringForOption:@(iterator.path)]];
  rime_get_api()->config_end(&iterator);
  return strList;
}

static NSDictionary<NSString*, NSString*>* const localeScript = @{
  @"simplification" : @"zh-Hans",
  @"simplified" : @"zh-Hans",
  @"!traditional" : @"zh-Hans",
  @"traditional" : @"zh-Hant",
  @"!simplification" : @"zh-Hant",
  @"!simplified" : @"zh-Hant"
};
static NSDictionary<NSString*, NSString*>* const localeRegion = @{
  @"tw" : @"zh-TW",
  @"taiwan" : @"zh-TW",
  @"hk" : @"zh-HK",
  @"hongkong" : @"zh-HK",
  @"hong_kong" : @"zh-HK",
  @"mo" : @"zh-MO",
  @"macau" : @"zh-MO",
  @"macao" : @"zh-MO",
  @"sg" : @"zh-SG",
  @"singapore" : @"zh-SG",
  @"cn" : @"zh-CN",
  @"china" : @"zh-CN"
};

static NSString* codeForScriptVariant(NSString* scriptVariant) {
  for (NSString* script in localeScript) {
    if ([script caseInsensitiveCompare:scriptVariant] == NSOrderedSame) {
      return localeScript[script];
    }
  }
  for (NSString* region in localeRegion) {
    if ([scriptVariant rangeOfString:region options:NSCaseInsensitiveSearch]
            .length > 0) {
      return localeRegion[region];
    }
  }
  return @"zh";
}

- (SquirrelOptionSwitcher*)getOptionSwitcher {
  RimeConfigIterator switchIter;
  if (!rime_get_api()->config_begin_list(&switchIter, &_config, "switches")) {
    return nil;
  }
  NSMutableDictionary<NSString*, NSString*>* switcher =
      NSMutableDictionary.alloc.init;
  NSMutableDictionary<NSString*, NSOrderedSet<NSString*>*>* optionGroups =
      NSMutableDictionary.alloc.init;
  NSString* defaultScriptVariant = nil;
  NSMutableDictionary<NSString*, NSString*>* scriptVariantOptions =
      NSMutableDictionary.alloc.init;
  while (rime_get_api()->config_next(&switchIter)) {
    int reset = [self
        getIntForOption:[@(switchIter.path) stringByAppendingString:@"/reset"]];
    NSString* name =
        [self getStringForOption:[@(switchIter.path)
                                     stringByAppendingString:@"/name"]];
    if (name) {
      if ([self hasSection:[@"style/!" stringByAppendingString:name]] ||
          [self hasSection:[@"style/" stringByAppendingString:name]]) {
        switcher[name] = reset ? name : [@"!" stringByAppendingString:name];
        optionGroups[name] = [NSOrderedSet orderedSetWithObject:name];
      }
      if (defaultScriptVariant == nil &&
          ([name caseInsensitiveCompare:@"simplification"] == NSOrderedSame ||
           [name caseInsensitiveCompare:@"simplified"] == NSOrderedSame ||
           [name caseInsensitiveCompare:@"traditional"] == NSOrderedSame)) {
        defaultScriptVariant =
            reset ? name : [@"!" stringByAppendingString:name];
        scriptVariantOptions[name] = codeForScriptVariant(name);
        scriptVariantOptions[[@"!" stringByAppendingString:name]] =
            codeForScriptVariant([@"!" stringByAppendingString:name]);
      }
    } else {
      RimeConfigIterator optionIter;
      if (!rime_get_api()->config_begin_list(
              &optionIter, &_config,
              [@(switchIter.path) stringByAppendingString:@"/options"]
                  .UTF8String)) {
        continue;
      }
      NSMutableOrderedSet<NSString*>* optGroup = NSMutableOrderedSet.alloc.init;
      BOOL hasStyleSection = NO;
      BOOL hasScriptVariant = defaultScriptVariant != nil;
      while (rime_get_api()->config_next(&optionIter)) {
        NSString* option = [self getStringForOption:@(optionIter.path)];
        [optGroup addObject:option];
        hasStyleSection |=
            [self hasSection:[@"style/" stringByAppendingString:option]];
        hasScriptVariant |=
            [option caseInsensitiveCompare:@"simplification"] ==
                NSOrderedSame ||
            [option caseInsensitiveCompare:@"simplified"] == NSOrderedSame ||
            [option caseInsensitiveCompare:@"traditional"] == NSOrderedSame;
      }
      rime_get_api()->config_end(&optionIter);
      if (hasStyleSection) {
        for (NSUInteger i = 0; i < optGroup.count; ++i) {
          switcher[optGroup[i]] = optGroup[(NSUInteger)reset];
          optionGroups[optGroup[i]] = optGroup;
        }
      }
      if (defaultScriptVariant == nil && hasScriptVariant) {
        for (NSString* opt in optGroup) {
          scriptVariantOptions[opt] = codeForScriptVariant(opt);
        }
        defaultScriptVariant =
            scriptVariantOptions[optGroup[(NSUInteger)reset]];
      }
    }
  }
  rime_get_api()->config_end(&switchIter);
  return [SquirrelOptionSwitcher.alloc
          initWithSchemaId:_schemaId
                  switcher:switcher
              optionGroups:optionGroups
      defaultScriptVariant:defaultScriptVariant ?: @"zh"
      scriptVariantOptions:scriptVariantOptions];
}

- (SquirrelAppOptions*)getAppOptions:(NSString*)appName {
  NSString* rootKey = [@"app_options/" stringByAppendingString:appName];
  NSMutableDictionary<NSString*, NSNumber*>* appOptions =
      NSMutableDictionary.alloc.init;
  RimeConfigIterator iterator;
  if (!rime_get_api()->config_begin_map(&iterator, &_config,
                                        rootKey.UTF8String)) {
    return appOptions;
  }
  while (rime_get_api()->config_next(&iterator)) {
    // NSLog(@"DEBUG option[%d]: %s (%s)", iterator.index, iterator.key,
    // iterator.path);
    NSNumber *value = [self getOptionalBoolForOption:@(iterator.path)] ? :
                      [self getOptionalIntForOption:@(iterator.path)] ? :
                      [self getOptionalDoubleForOption:@(iterator.path)];
    if (value) {
      appOptions[@(iterator.key)] = value;
    }
  }
  rime_get_api()->config_end(&iterator);
  return appOptions;
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
  if (string == nil || (string.length != 8 && string.length != 10) ||
      (![string hasPrefix:@"0x"] && ![string hasPrefix:@"0X"])) {
    return nil;
  }
  NSScanner* hexScanner = [NSScanner scannerWithString:string];
  UInt hex = 0x0;
  if ([hexScanner scanHexInt:&hex] && hexScanner.atEnd) {
    UInt r = hex % 0x100;
    UInt g = hex / 0x100 % 0x100;
    UInt b = hex / 0x10000 % 0x100;
    // 0xaaBBGGRR or 0xBBGGRR
    UInt a = string.length == 10 ? hex / 0x1000000 : 0xFF;
    CGFloat components[4] = {r / 255.0, g / 255.0, b / 255.0, a / 255.0};
    return [NSColor colorWithColorSpace:_colorSpace
                             components:components
                                  count:4];
  }
  return nil;
}

- (NSImage*)imageFromFile:(NSString*)filePath {
  if (filePath == nil) {
    return nil;
  }
  NSURL* userDataDir =
      [NSURL fileURLWithPath:@"~/Library/Rime".stringByExpandingTildeInPath
                 isDirectory:YES];
  NSURL* imageFile = [NSURL fileURLWithPath:filePath
                                isDirectory:NO
                              relativeToURL:userDataDir];
  if ([imageFile checkResourceIsReachableAndReturnError:nil]) {
    NSImage* image = [NSImage.alloc initByReferencingURL:imageFile];
    return image;
  }
  return nil;
}

@end  // SquirrelConfig
