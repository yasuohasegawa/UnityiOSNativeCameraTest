//
//  MultiCamCapture.swift
//  MultiCamTest
//
//  Created by Yasuo Hasegawa on 2022/12/29.
//

import UIKit
import AVFoundation
import Metal

public class MultiCamCapture : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var captureSession: AVCaptureMultiCamSession = AVCaptureMultiCamSession()
    private let backVideoDataOutput = AVCaptureVideoDataOutput()
    private let frontVideoDataOutput = AVCaptureVideoDataOutput()
    
    private var backCameraInput:AVCaptureDeviceInput?
    private var frontCameraInput:AVCaptureDeviceInput?
    
    private var metalDevice = MTLCreateSystemDefaultDevice()
    private var backTextureCache: CVMetalTextureCache?
    private var backMovieTexture:MTLTexture!
    private var frontTextureCache: CVMetalTextureCache?
    private var frontMovieTexture:MTLTexture!
    
    private var texWidth:Int = 0
    
    private var isStarted:Bool = false;
    
    @objc public override init() {
        super.init()
        
        // create texture caches for MTLTexture
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice!, nil, &backTextureCache)
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice!, nil, &frontTextureCache)
        
        addCameraInput()
        getFrames()
        captureSession.startRunning()
        isStarted = true
        print(">>>> start")
    }
    
    private func addCameraInput() {
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: .back).devices.first else {
                fatalError("No back camera device found, please make sure to run SimpleLaneDetection in an iOS device and not a simulator")
        }
        backCameraInput = try! AVCaptureDeviceInput(device: device)
        self.captureSession.addInput(backCameraInput!)
        
        guard let frontDevice = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front).devices.first else {
                fatalError("No front camera device found, please make sure to run SimpleLaneDetection in an iOS device and not a simulator")
        }
        frontCameraInput = try! AVCaptureDeviceInput(device: frontDevice)
        self.captureSession.addInput(frontCameraInput!)
    }
    
    private func getFrames() {
        let outQueue = DispatchQueue(label: "camera.frame.processing.queue")
        if backVideoDataOutput.availableVideoPixelFormatTypes.contains(kCVPixelFormatType_Lossy_32BGRA) {
            // Set the Lossy format
            print("Selecting lossy pixel format")
            backVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_Lossy_32BGRA)]
        } else if backVideoDataOutput.availableVideoPixelFormatTypes.contains(kCVPixelFormatType_Lossless_32BGRA) {
            // Set the Lossless format
            print("Selecting a lossless pixel format")
            backVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_Lossless_32BGRA)]
        } else {
            // Set to the fallback format
            print("Selecting a 32BGRA pixel format")
            backVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        }
        backVideoDataOutput.alwaysDiscardsLateVideoFrames = true
        backVideoDataOutput.setSampleBufferDelegate(self, queue: outQueue) // set up the sample buffer delegate
        
        if frontVideoDataOutput.availableVideoPixelFormatTypes.contains(kCVPixelFormatType_Lossy_32BGRA) {
            // Set the Lossy format
            frontVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_Lossy_32BGRA)]
        } else if frontVideoDataOutput.availableVideoPixelFormatTypes.contains(kCVPixelFormatType_Lossless_32BGRA) {
            // Set the Lossless format
            frontVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_Lossless_32BGRA)]
        } else {
            // Set to the fallback format
            frontVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        }
        
        frontVideoDataOutput.alwaysDiscardsLateVideoFrames = true
        frontVideoDataOutput.setSampleBufferDelegate(self, queue: outQueue)
        
        
        
        let backCameraVideoPort = backCameraInput?.ports(for: .video,
                                                          sourceDeviceType: .builtInWideAngleCamera,
                                                           sourceDevicePosition: .back).first
        
        self.captureSession.addOutputWithNoConnections(backVideoDataOutput)
        
        let backConnection = AVCaptureConnection(inputPorts: [backCameraVideoPort!], output: backVideoDataOutput)
        self.captureSession.addConnection(backConnection)
        
        
        backConnection.videoOrientation = .portrait

        backConnection.videoPreviewLayer?.videoGravity = .resizeAspectFill
        
        
        
        let frontCameraVideoPort = frontCameraInput?.ports(for: .video,
                                                          sourceDeviceType: .builtInWideAngleCamera,
                                                           sourceDevicePosition: .front).first
        
        self.captureSession.addOutputWithNoConnections(frontVideoDataOutput)
        
        let frontConnection = AVCaptureConnection(inputPorts: [frontCameraVideoPort!], output: frontVideoDataOutput)
        self.captureSession.addConnection(frontConnection)
        
        frontConnection.videoOrientation = .portrait
        frontConnection.automaticallyAdjustsVideoMirroring = false
        frontConnection.isVideoMirrored = true
        
        //frontConnection.videoPreviewLayer?.videoGravity = .resizeAspectFill
    }
    
    public func captureOutput( _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if !isStarted {
            return
        }
        let vout = output as? AVCaptureVideoDataOutput
        
        let pixelBuffer:CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        autoreleasepool {
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

            let w = CVPixelBufferGetWidth(pixelBuffer)
            let h = CVPixelBufferGetHeight(pixelBuffer)

            //print("w:\(w) h:\(h)")

            var cache = backTextureCache!
            if vout == frontVideoDataOutput {
                cache = frontTextureCache!
            }
            var imageTexture: CVMetalTexture?
            let planeIndex = 0
            let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, pixelBuffer, nil, .bgra8Unorm, w, h, planeIndex, &imageTexture)
            
            guard let unwrappedImageTexture = imageTexture,
                  let texture = CVMetalTextureGetTexture(unwrappedImageTexture),
                        result == kCVReturnSuccess
            else {
                return
            }
            
            if vout == backVideoDataOutput {
                backMovieTexture = texture
            } else if vout == frontVideoDataOutput {
                frontMovieTexture = texture
            }
            
            texWidth = w
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0));
        }
        
    }
    
    /* methods call from Unity */
    
    @objc public func getBackMovieTexture()->MTLTexture {
        return backMovieTexture
    }
    
    @objc public func getFrontMovieTexture()->MTLTexture {
        return frontMovieTexture
    }
    
    @objc public func isMTLTextureCreated()->Bool {
        return texWidth >= 1
    }
}
