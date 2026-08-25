#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NDIFinder : NSObject
@property (nonatomic, copy, nullable) void (^onVideoFrame)(CGImageRef image);
@property (nonatomic, copy, nullable) void (^onStatus)(NSString *status);
@property (nonatomic, copy, nullable) void (^onError)(NSString *message);
@property (nonatomic, readonly, nullable) NSString *lastError;

- (BOOL)initialize;
- (void)shutdown;
- (void)discoverSources:(void (^)(NSArray<NSString *> *names))completion;
@end

NS_ASSUME_NONNULL_END
