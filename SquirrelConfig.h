#import <Cocoa/Cocoa.h>

@interface SquirrelOptionSwitcher : NSObject

@property(nonatomic, strong, readonly) NSString *schemaId;
@property(nonatomic, strong, readonly) NSArray<NSString *> *optionNames;
@property(nonatomic, strong, readonly) NSArray<NSString *> *optionStates;
@property(nonatomic, strong, readonly) NSDictionary<NSString *, NSArray<NSString *> *> *optionGroups;
@property(nonatomic, strong, readonly) NSDictionary<NSString *, NSString *> *switcher;

- (instancetype)initWithSchemaId:(NSString *)schemaId
                        switcher:(NSDictionary<NSString *, NSString *> *)switcher
                    optionGroups:(NSDictionary<NSString *, NSArray<NSString *> *> *)optionGroups;

- (instancetype)initWithSchemaId:(NSString *)schemaId;

// return whether switcher options has been successfully updated
- (BOOL)updateSwitcher:(NSDictionary<NSString *, NSString *> *)switcher;

- (BOOL)updateGroupState:(NSString *)optionState
                ofOption:(NSString *)optionName;

- (BOOL)containsOption:(NSString *)optionName;

- (NSMutableDictionary<NSString *, NSString *> *)mutableSwitcher;

@end // SquirrelOptionSwitcher


@interface SquirrelConfig : NSObject

typedef NSDictionary<NSString *, NSNumber *> SquirrelAppOptions;
typedef NSMutableDictionary<NSString *, NSNumber *> SquirrelMutableAppOptions;

@property(nonatomic, readonly) BOOL isOpen;
@property(nonatomic, strong) NSString *colorSpace;
@property(nonatomic, strong, readonly) NSString *schemaId;

- (BOOL)openBaseConfig;
- (BOOL)openWithSchemaId:(NSString *)schemaId
              baseConfig:(SquirrelConfig *)config;
- (BOOL)openUserConfig:(NSString *)configId;
- (BOOL)openWithConfigId:(NSString *)configId;
- (void)close;

- (BOOL)hasSection:(NSString *)section;

- (BOOL)setBool:(bool)value forOption:(NSString *)option;
- (BOOL)setInt:(int)value forOption:(NSString *)option;
- (BOOL)setDouble:(double)value forOption:(NSString *)option;
- (BOOL)setString:(NSString *)value forOption:(NSString *)option;

- (BOOL)getBoolForOption:(NSString *)option;
- (int)getIntForOption:(NSString *)option;
- (double)getDoubleForOption:(NSString *)option;
- (double)getDoubleForOption:(NSString *)option
             applyConstraint:(double(*)(double param))func;

- (NSNumber *)getOptionalBoolForOption:(NSString *)option;
- (NSNumber *)getOptionalIntForOption:(NSString *)option;
- (NSNumber *)getOptionalDoubleForOption:(NSString *)option;
- (NSNumber *)getOptionalDoubleForOption:(NSString *)option
                         applyConstraint:(double(*)(double param))func;

- (NSString *)getStringForOption:(NSString *)option;
// 0xaabbggrr or 0xbbggrr
- (NSColor *)getColorForOption:(NSString *)option;
// file path (absolute or relative to ~/Library/Rime)
- (NSImage *)getImageForOption:(NSString *)option;

- (NSUInteger)getListSizeForOption:(NSString *)option;
- (NSArray<NSString *> *)getListForOption:(NSString *)option;

- (SquirrelOptionSwitcher *)getOptionSwitcher;
- (SquirrelAppOptions *)getAppOptions:(NSString *)appName;

@end // SquirrelConfig
