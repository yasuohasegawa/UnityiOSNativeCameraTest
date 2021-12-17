// reference:https://mike-neko.github.io/blog/unity-opencv/

#import "AppDelegateListener.h"
#import <string.h>
#import <AVFoundation/AVFoundation.h>

@interface NativeCameraTest : NSObject<AppDelegateListener, AVCaptureVideoDataOutputSampleBufferDelegate> {
    int w;
    int h;
    uint8_t imageBuffer[1920*1080*4];
}
@property (nonatomic, strong) AVCaptureSession* captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput* deviceInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput* videoDataOutput;
@property (nonatomic, strong) NSDictionary* settings;

@end

static NativeCameraTest *_instance;

@implementation NativeCameraTest

+ (NativeCameraTest *)sharedInstance {
    return _instance;
}

+ (void)load {
    if(!_instance) {
        _instance = [[NativeCameraTest alloc] init];
    }
}

- (id)init {
    if(_instance)
        return _instance;
    self = [super init];
    if (!self)
        return nil;
    _instance = self;
    UnityRegisterAppDelegateListener(self);
    return self;
}

- (void)startCamera{
    self.captureSession = [[AVCaptureSession alloc] init];
    [self addCameraInput];
    [self getFrames];
    [self.captureSession startRunning];
}

- (void)stopCamera{
    [self.captureSession stopRunning];
    self.captureSession = nil;
    self.videoDataOutput = nil;
    self.deviceInput = nil;
    self.settings = nil;
}

- (void)addCameraInput{
    AVCaptureDeviceDiscoverySession* device = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInDualCamera,AVCaptureDeviceTypeBuiltInTrueDepthCamera]
                                                                                                    mediaType:AVMediaTypeVideo
                                                                                                     position:AVCaptureDevicePositionUnspecified];
    
    self.deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:[device.devices objectAtIndex:0] error:NULL];
    [self.captureSession addInput:self.deviceInput];
}

- (void)getFrames {
    self.settings = @{(id)kCVPixelBufferPixelFormatTypeKey:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]};
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.videoDataOutput.videoSettings = self.settings;
    self.videoDataOutput.alwaysDiscardsLateVideoFrames = true;
    [self.videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    self.captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
    [self.captureSession addOutput:self.videoDataOutput];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // lock the buffer
    CVPixelBufferLockBaseAddress(buffer, 0);
    
    w = (int)CVPixelBufferGetWidth(buffer);
    h = (int)CVPixelBufferGetHeight(buffer);
    
    uint8_t *base = (uint8_t *)(CVPixelBufferGetBaseAddress(buffer));
    int size = w*h*4;
    for (int i = 0; i < size; i+=4) {
        imageBuffer[i]   = base[i+2];
        imageBuffer[i+1] = base[i+1];
        imageBuffer[i+2] = base[i];
        imageBuffer[i+3] = base[i+3];
    }
    
    // unlock the buffer
    CVPixelBufferUnlockBaseAddress(buffer, 0);
}

- (void)updateImage:(unsigned char*)data {
    memcpy(data, imageBuffer, sizeof(imageBuffer));
}

@end

extern "C" {
    void startCamera()
    {
        [[NativeCameraTest sharedInstance] startCamera];
    }

    void stopCamera()
    {
        [[NativeCameraTest sharedInstance] stopCamera];
    }

    void getNativeImageData(uint8_t * dest) {
        [[NativeCameraTest sharedInstance] updateImage: dest];
    }
}
