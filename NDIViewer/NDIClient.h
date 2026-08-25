#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NDIClient : NSObject
@property (nonatomic, copy, nullable) void (^onVideoFrame)(CGImageRef image);
@property (nonatomic, copy, nullable) void (^onStatus)(NSString *status);
@property (nonatomic, copy, nullable) void (^onError)(NSString *message);
@property (nonatomic, readonly, nullable) NSString *lastError;

- (BOOL)initialize;
- (void)shutdown;
- (BOOL)connectToSourceNamed:(NSString *)sourceName;
- (void)disconnect;
@end

NS_ASSUME_NONNULL_END
