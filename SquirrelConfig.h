#import <Cocoa/Cocoa.h>

typedef NSDictionary<NSString *, NSNumber *> SquirrelAppOptions;
typedef NSMutableDictionary<NSString *, NSNumber *> SquirrelMutableAppOptions;

@interface SquirrelOptionSwitcher : NSObject

@property(nonatomic, strong, readonly) NSString *schemaId;
@property(nonatomic, strong, readonly) NSArray<NSString *> *optionNames;
@property(nonatomic, strong, readonly) NSArray<NSString *> *optionStates;
@property(nonatomic, strong, readonly) NSDictionary<NSString *, NSArray<NSString *> *> *optionGroups;
@property(nonatomic, strong, readonly) NSDictionary<NSString *, NSString *> *switcher;

- (instancetype)initWithSchemaId:(NSString *)schemaId
                        switcher:(NSDictionary<NSString *, NSString *> *)switcher
                    optionGroups:(NSDictionary<NSString *, NSArray<NSString *> *> *)optionGroups;

// return whether switcher options has been successfully updated
- (BOOL)updateSwitcher:(NSDictionary<NSString *, NSString *> *)switcher;

- (BOOL)updateGroupState:(NSString *)optionState ofOption:(NSString *)optionName;

- (BOOL)containsOption:(NSString *)optionName;

- (NSMutableDictionary<NSString *, NSString *> *)mutableSwitcher;

@end

@interface SquirrelConfig : NSObject

@property(nonatomic, readonly) BOOL isOpen;
@property(nonatomic, copy) NSString *colorSpace;
@property(nonatomic, readonly) NSString *schemaId;

- (BOOL)openBaseConfig;
- (BOOL)openWithSchemaId:(NSString *)schemaId
              baseConfig:(SquirrelConfig *)config;
- (BOOL)openUserConfig:(NSString *)configId;
- (BOOL)openWithConfigId:(NSString *)configId;
- (void)close;

- (BOOL)hasSection:(NSString *)section;

- (BOOL)getBool:(NSString *)option;
- (int)getInt:(NSString *)option;
- (double)getDouble:(NSString *)option;
- (NSNumber *)getOptionalBool:(NSString *)option;
- (NSNumber *)getOptionalInt:(NSString *)option;
- (NSNumber *)getOptionalDouble:(NSString *)option;

- (NSString *)getString:(NSString *)option;
// 0xaabbggrr or 0xbbggrr
- (NSColor *)getColor:(NSString *)option;
// file path (absolute or relative to ~/Library/Rime)
- (NSColor *)getPattern:(NSString *)option;

- (NSArray<NSString *> *)getList:(NSString *)option;

- (SquirrelOptionSwitcher *)getOptionSwitcher;
- (SquirrelAppOptions *)getAppOptions:(NSString *)appName;

@end
