#import <Cocoa/Cocoa.h>

typedef NSDictionary<NSString *, NSNumber *> SquirrelAppOptions;
typedef NSMutableDictionary<NSString *, NSNumber *> SquirrelMutableAppOptions;

@interface SquirrelConfig : NSObject

@property(nonatomic, readonly) BOOL isOpen;
@property(nonatomic, copy) NSString *colorSpace;
@property(nonatomic, readonly) NSString *schemaId;

- (BOOL)openBaseConfig;
- (BOOL)openWithSchemaId:(NSString *)schemaId
              baseConfig:(SquirrelConfig *)config;
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

- (SquirrelAppOptions *)getAppOptions:(NSString *)appName;

@end
