#import "NDIClient.h"
#import <Processing.NDI.Lib.h>
#import <atomic>
#import <mutex>
#import <string>

@interface NDIClient ()
@property (nonatomic, readwrite, nullable) NSString *lastError;
@end

@implementation NDIClient {
   dispatch_queue_t _ndiQueue;
   NDIlib_find_instance_t _finder;
   NDIlib_recv_instance_t _receiver;
   std::atomic_bool _receiving;
   std::atomic_bool _initialized;
   std::mutex _receiverMutex;
}

- (instancetype)init {
   self = [super init];
   if (self) {
      _ndiQueue = dispatch_queue_create("edu.msu.NDIViewer.ndi", DISPATCH_QUEUE_SERIAL);
      _receiver = nullptr;
      _receiving = false;
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
   
   _initialized = true;
   self.lastError = nil;
   return YES;
}

- (void)shutdown {
   if (!_initialized.exchange(false)) return;
   [self disconnect];
   NDIlib_destroy();
}


- (BOOL)connectToSourceNamed:(NSString *)sourceName {
   if (!_initialized.load()) {
      self.lastError = @"NDI has not been initialized.";
      return NO;
   }
   
   [self disconnect];
   
   std::string sourceUTF8([sourceName UTF8String]);
   NDIlib_source_t source = {};
   source.p_ndi_name = sourceUTF8.c_str();
   source.p_url_address = nullptr;
   
   NDIlib_recv_create_v3_t settings = {};
   settings.source_to_connect_to = source;
   settings.color_format = NDIlib_recv_color_format_BGRX_BGRA;
   settings.bandwidth = NDIlib_recv_bandwidth_highest;
   settings.allow_video_fields = false;
   settings.p_ndi_recv_name = "NDI Viewer for macOS";
   
   {
      std::lock_guard<std::mutex> lock(_receiverMutex);
      _receiver = NDIlib_recv_create_v3(&settings);
   }
   if (!_receiver) {
      self.lastError = @"NDIlib_recv_create_v3 failed.";
      return NO;
   }
   
   _receiving = true;
   self.lastError = nil;
   dispatch_async(_ndiQueue, ^{ [self receiveLoop]; });
   return YES;
}

- (void)disconnect {
   _receiving = false;
   std::lock_guard<std::mutex> lock(_receiverMutex);
   if (_receiver) {
      NDIlib_recv_destroy(_receiver);
      _receiver = nullptr;
   }
}

- (void)receiveLoop {
   while (_receiving.load() && _initialized.load()) {
      std::unique_lock<std::mutex> lock(_receiverMutex);
      NDIlib_recv_instance_t receiver = _receiver;
      if (!receiver) break;
      
      NDIlib_video_frame_v2_t video = {};
      NDIlib_audio_frame_v3_t audio = {};
      NDIlib_metadata_frame_t metadata = {};
      NDIlib_frame_type_e type = NDIlib_recv_capture_v3(receiver, &video, &audio, &metadata, 250);
      
      switch (type) {
         case NDIlib_frame_type_video: {
            CGImageRef image = [self newCGImageFromVideoFrame:&video];
            NDIlib_recv_free_video_v2(receiver, &video);
            lock.unlock();
            if (image) {
               void (^callback)(CGImageRef) = self.onVideoFrame;
               if (callback) {
                  CGImageRetain(image);
                  dispatch_async(dispatch_get_main_queue(), ^{
                     callback(image);
                     CGImageRelease(image);
                  });
               }
               CGImageRelease(image);
            }
            break;
         }
         case NDIlib_frame_type_audio:
            NDIlib_recv_free_audio_v3(receiver, &audio);
            lock.unlock();
            break;
         case NDIlib_frame_type_metadata:
            NDIlib_recv_free_metadata(receiver, &metadata);
            lock.unlock();
            break;
         case NDIlib_frame_type_status_change: {
            lock.unlock();
            void (^callback)(NSString *) = self.onStatus;
            if (callback) dispatch_async(dispatch_get_main_queue(), ^{ callback(@"NDI receiver status changed"); });
            break;
         }
         case NDIlib_frame_type_error: {
            lock.unlock();
            void (^callback)(NSString *) = self.onError;
            if (callback) dispatch_async(dispatch_get_main_queue(), ^{ callback(@"The NDI receiver reported an error."); });
            break;
         }
         default:
            lock.unlock();
            break;
      }
   }
}

- (CGImageRef)newCGImageFromVideoFrame:(const NDIlib_video_frame_v2_t *)frame CF_RETURNS_RETAINED {
   if (!frame || !frame->p_data || frame->xres <= 0 || frame->yres <= 0) return nullptr;
   
   const size_t width = (size_t)frame->xres;
   const size_t height = (size_t)frame->yres;
   const size_t bytesPerRow = (size_t)frame->line_stride_in_bytes;
   const size_t byteCount = bytesPerRow * height;
   
   CFDataRef data = CFDataCreate(kCFAllocatorDefault, frame->p_data, (CFIndex)byteCount);
   if (!data) return nullptr;
   CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
   CFRelease(data);
   if (!provider) return nullptr;
   
   CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
   CGBitmapInfo bitmapInfo =
   kCGBitmapByteOrder32Little |
   (CGBitmapInfo)kCGImageAlphaPremultipliedFirst;
   
   CGImageRef image = CGImageCreate(width, height, 8, 32, bytesPerRow, colorSpace,
                                    bitmapInfo, provider, nullptr, false,
                                    kCGRenderingIntentDefault);
   CGColorSpaceRelease(colorSpace);
   CGDataProviderRelease(provider);
   return image;
}

@end
