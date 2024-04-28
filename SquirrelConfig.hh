#import <Cocoa/Cocoa.h>

typedef uintptr_t RimeSessionId;

__attribute__((objc_direct_members))
@interface SquirrelOptionSwitcher : NSObject

@property(nonatomic, strong, readonly, nonnull) NSString* schemaId;
@property(nonatomic, strong, readonly, nonnull) NSString* currentScriptVariant;
@property(nonatomic, strong, readonly, nonnull) NSSet<NSString*>* optionNames;
@property(nonatomic, strong, readonly, nonnull) NSSet<NSString*>* optionStates;
@property(nonatomic, strong, readonly, nonnull)
    NSDictionary<NSString*, NSString*>* scriptVariantOptions;
@property(nonatomic, strong, readonly, nonnull)
    NSMutableDictionary<NSString*, NSString*>* switcher;
@property(nonatomic, strong, readonly, nonnull)
    NSDictionary<NSString*, NSOrderedSet<NSString*>*>* optionGroups;

- (instancetype _Nonnull)
        initWithSchemaId:(NSString* _Nullable)schemaId
                switcher:(NSMutableDictionary<NSString*, NSString*>* _Nullable)
                             switcher
            optionGroups:
                (NSDictionary<NSString*, NSOrderedSet<NSString*>*>* _Nullable)
                    optionGroups
    defaultScriptVariant:(NSString* _Nullable)defaultScriptVariant
    scriptVariantOptions:
        (NSDictionary<NSString*, NSString*>* _Nullable)scriptVariantOptions
    NS_DESIGNATED_INITIALIZER;
- (instancetype _Nonnull)initWithSchemaId:(NSString* _Nullable)schemaId;
// return whether switcher options has been successfully updated
- (BOOL)updateSwitcher:
    (NSMutableDictionary<NSString*, NSString*>* _Nonnull)switcher;
- (BOOL)updateGroupState:(NSString* _Nonnull)optionState
                ofOption:(NSString* _Nonnull)optionName;
- (BOOL)updateCurrentScriptVariant:(NSString* _Nonnull)scriptVariant;
- (void)updateWithRimeSession:(RimeSessionId)session;

@end  // SquirrelOptionSwitcher

__attribute__((objc_direct_members))
@interface SquirrelConfig : NSObject

typedef NSDictionary<NSString*, NSNumber*> SquirrelAppOptions;

@property(nonatomic, strong, readonly, nonnull) NSString* schemaId;
@property(nonatomic, strong, nonnull) NSString* colorSpace;

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

- (NSNumber* _Nullable)getOptionalBoolForOption:(NSString* _Nonnull)option
                                          alias:(NSString* _Nullable)alias;
- (NSNumber* _Nullable)getOptionalIntForOption:(NSString* _Nonnull)option
                                         alias:(NSString* _Nullable)alias;
- (NSNumber* _Nullable)getOptionalDoubleForOption:(NSString* _Nonnull)option
                                            alias:(NSString* _Nullable)alias;
- (NSNumber* _Nullable)getOptionalDoubleForOption:(NSString* _Nonnull)option
                                            alias:(NSString* _Nullable)alias
                                  applyConstraint:
                                      (double (*_Nonnull)(double param))func;

- (NSString* _Nullable)getStringForOption:(NSString* _Nonnull)option;
// 0xaabbggrr or 0xbbggrr
- (NSColor* _Nullable)getColorForOption:(NSString* _Nonnull)option;
// file path (absolute or relative to ~/Library/Rime)
- (NSImage* _Nullable)getImageForOption:(NSString* _Nonnull)option;

- (NSString* _Nullable)getStringForOption:(NSString* _Nonnull)option
                                    alias:(NSString* _Nullable)alias;
- (NSColor* _Nullable)getColorForOption:(NSString* _Nonnull)option
                                  alias:(NSString* _Nullable)alias;
- (NSImage* _Nullable)getImageForOption:(NSString* _Nonnull)option
                                  alias:(NSString* _Nullable)alias;

- (NSUInteger)getListSizeForOption:(NSString* _Nonnull)option;
- (NSArray<NSString*>* _Nullable)getListForOption:(NSString* _Nonnull)option;

- (SquirrelOptionSwitcher* _Nullable)getOptionSwitcher;
- (SquirrelAppOptions* _Nonnull)getAppOptions:(NSString* _Nonnull)appName;

@end  // SquirrelConfig
