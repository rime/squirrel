#import <Cocoa/Cocoa.h>

@interface SquirrelOptionSwitcher : NSObject

@property(nonatomic, strong, readonly, nonnull) NSString* schemaId;
@property(nonatomic, strong, readonly, nullable)
    NSArray<NSString*>* optionNames;
@property(nonatomic, strong, readonly, nullable)
    NSArray<NSString*>* optionStates;
@property(nonatomic, strong, readonly, nullable)
    NSDictionary<NSString*, NSArray<NSString*>*>* optionGroups;
@property(nonatomic, strong, readonly, nullable)
    NSDictionary<NSString*, NSString*>* switcher;

- (instancetype _Nonnull)
    initWithSchemaId:(NSString* _Nonnull)schemaId
            switcher:(NSDictionary<NSString*, NSString*>* _Nullable)switcher
        optionGroups:(NSDictionary<NSString*, NSArray<NSString*>*>* _Nullable)
                         optionGroups;

- (instancetype _Nonnull)initWithSchemaId:(NSString* _Nonnull)schemaId;

// return whether switcher options has been successfully updated
- (BOOL)updateSwitcher:(NSDictionary<NSString*, NSString*>* _Nullable)switcher;

- (BOOL)updateGroupState:(NSString* _Nullable)optionState
                ofOption:(NSString* _Nullable)optionName;

- (BOOL)containsOption:(NSString* _Nonnull)optionName;

- (NSMutableDictionary<NSString*, NSString*>* _Nullable)mutableSwitcher;

@end  // SquirrelOptionSwitcher

@interface SquirrelConfig : NSObject

typedef NSDictionary<NSString*, NSNumber*> SquirrelAppOptions;
typedef NSMutableDictionary<NSString*, NSNumber*> SquirrelMutableAppOptions;

@property(nonatomic, readonly) BOOL isOpen;
@property(nonatomic, strong, nonnull) NSString* colorSpace;
@property(nonatomic, strong, readonly, nonnull) NSString* schemaId;

- (BOOL)openBaseConfig;
- (BOOL)openWithSchemaId:(NSString* _Nonnull)schemaId
              baseConfig:(SquirrelConfig* _Nullable)config;
- (BOOL)openUserConfig:(NSString* _Nonnull)configId;
- (BOOL)openWithConfigId:(NSString* _Nonnull)configId;
- (void)close;

- (BOOL)hasSection:(NSString* _Nonnull)section;

- (BOOL)setOption:(NSString* _Nonnull)option withBool:(bool)value;
- (BOOL)setOption:(NSString* _Nonnull)option withInt:(int)value;
- (BOOL)setOption:(NSString* _Nonnull)option withDouble:(double)value;
- (BOOL)setOption:(NSString* _Nonnull)option
       withString:(NSString* _Nonnull)value;

- (BOOL)getBoolForOption:(NSString* _Nonnull)option;
- (int)getIntForOption:(NSString* _Nonnull)option;
- (double)getDoubleForOption:(NSString* _Nonnull)option;
- (double)getDoubleForOption:(NSString* _Nonnull)option
             applyConstraint:(double (*_Nonnull)(double param))func;

- (NSNumber* _Nullable)getOptionalBoolForOption:(NSString* _Nonnull)option;
- (NSNumber* _Nullable)getOptionalIntForOption:(NSString* _Nonnull)option;
- (NSNumber* _Nullable)getOptionalDoubleForOption:(NSString* _Nonnull)option;
- (NSNumber* _Nullable)getOptionalDoubleForOption:(NSString* _Nonnull)option
                                  applyConstraint:
                                      (double (*_Nonnull)(double param))func;

- (NSString* _Nullable)getStringForOption:(NSString* _Nonnull)option;
// 0xaabbggrr or 0xbbggrr
- (NSColor* _Nullable)getColorForOption:(NSString* _Nonnull)option;
// file path (absolute or relative to ~/Library/Rime)
- (NSImage* _Nullable)getImageForOption:(NSString* _Nonnull)option;

- (NSUInteger)getListSizeForOption:(NSString* _Nonnull)option;
- (NSArray<NSString*>* _Nullable)getListForOption:(NSString* _Nonnull)option;

- (SquirrelOptionSwitcher* _Nullable)getOptionSwitcher;
- (SquirrelAppOptions* _Nullable)getAppOptions:(NSString* _Nonnull)appName;

@end  // SquirrelConfig
