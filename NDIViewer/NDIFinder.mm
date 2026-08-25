#import "NDIFinder.h"
#import <Processing.NDI.Lib.h>
#import <atomic>
#import <mutex>
#import <string>

@interface NDIFinder ()
@property (nonatomic, readwrite, nullable) NSString *lastError;
@end

@implementation NDIFinder {
    dispatch_queue_t _ndiQueue;
    NDIlib_find_instance_t _finder;
    std::atomic_bool _initialized;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _ndiQueue = dispatch_queue_create("edu.msu.NDIViewer.ndi", DISPATCH_QUEUE_SERIAL);
        _finder = nullptr;
        //_receiver = nullptr;
        //_receiving = false;
        _initialized = false;
    }
    return self;
}

- (void)dealloc {
    [self shutdown];
}

- (BOOL)initialize {
    if (_initialized.load()) return YES;
    if (!NDIlib_initialize()) {
        self.lastError = @"NDIlib_initialize failed. Verify that libndi.dylib is embedded in the app and supports this Mac's architecture.";
        return NO;
    }

    NDIlib_find_create_t settings = {};
    settings.show_local_sources = true;
    settings.p_groups = nullptr;
    settings.p_extra_ips = nullptr;
    _finder = NDIlib_find_create_v2(&settings);
    if (!_finder) {
        NDIlib_destroy();
        self.lastError = @"Unable to create the NDI source finder.";
        return NO;
    }

    _initialized = true;
    self.lastError = nil;
    return YES;
}

- (void)shutdown {
    if (!_initialized.exchange(false)) return;
    if (_finder) {
        NDIlib_find_destroy(_finder);
        _finder = nullptr;
    }
    NDIlib_destroy();
}

- (void)discoverSources:(void (^)(NSArray<NSString *> *names))completion {
    if (!_initialized.load() || !_finder) {
        completion(@[]);
        return;
    }

    dispatch_async(_ndiQueue, ^{
        if (!self->_initialized.load() || !self->_finder) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(@[]); });
            return;
        }

        NDIlib_find_wait_for_sources(self->_finder, 250);
        uint32_t count = 0;
        const NDIlib_source_t *sources = NDIlib_find_get_current_sources(self->_finder, &count);
        NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:count];
        for (uint32_t i = 0; i < count; ++i) {
            if (sources[i].p_ndi_name) {
                NSString *name = [NSString stringWithUTF8String:sources[i].p_ndi_name];
                if (name) [names addObject:name];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(names); });
    });
}


@end
