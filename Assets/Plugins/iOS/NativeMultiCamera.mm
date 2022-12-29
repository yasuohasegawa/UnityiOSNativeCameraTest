#import <AVFoundation/AVFoundation.h>
#import <UnityFramework/UnityFramework-Swift.h>

extern "C" {
    MultiCamCapture* _InitMultiCapture() {
        MultiCamCapture *multiCam = [[MultiCamCapture alloc] init];
        CFRetain((CFTypeRef)multiCam);
        return multiCam;
    }

    id<MTLTexture> _GetBackMTLTexture(MultiCamCapture *multiCam){
        return [multiCam getBackMovieTexture];
    }

    id<MTLTexture> _GetFrontMTLTexture(MultiCamCapture *multiCam){
        return [multiCam getFrontMovieTexture];
    }
    
    bool _IsMTLTextureCreated(MultiCamCapture *multiCam){
        return [multiCam isMTLTextureCreated];
    }
}
