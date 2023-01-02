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
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
        case multiCamNotSupported
    }
    private var setupResult: SessionSetupResult = .success
    private let sessionQueue = DispatchQueue(label: "session queue")
    private let dataOutputQueue = DispatchQueue(label: "data output queue")
    
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
        
        sessionQueue.async {
            self.systemConfigure()
            self.addCameraInput()
            self.getFrames()
            self.captureSession.startRunning()
            self.isStarted = true
        }
        print(">>>> start")
        
        // Keep the screen awake
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    func systemConfigure(){
        guard setupResult == .success else { return }
        
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            print("MultiCam not supported on this device")
            setupResult = .multiCamNotSupported
            return
        }
        
        // When using AVCaptureMultiCamSession, it is best to manually add connections from AVCaptureInputs to AVCaptureOutputs
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
            if setupResult == .success {
                checkSystemCost()
            }
        }
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
        backVideoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue) // set up the sample buffer delegate
        
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
        frontVideoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        
        
        
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
    
    struct ExceededCaptureSessionCosts: OptionSet {
        let rawValue: Int
        
        static let systemPressureCost = ExceededCaptureSessionCosts(rawValue: 1 << 0)
        static let hardwareCost = ExceededCaptureSessionCosts(rawValue: 1 << 1)
    }
    
    func checkSystemCost() {
        var exceededSessionCosts: ExceededCaptureSessionCosts = []
        
        if captureSession.systemPressureCost > 1.0 {
            exceededSessionCosts.insert(.systemPressureCost)
        }
        
        if captureSession.hardwareCost > 1.0 {
            exceededSessionCosts.insert(.hardwareCost)
        }
        
        switch exceededSessionCosts {
            
        case .systemPressureCost:
            // Choice #1: Reduce front camera resolution
            if reduceResolutionForCamera(.front) {
                checkSystemCost()
            }
                
            // Choice 2: Reduce the number of video input ports
            else if reduceVideoInputPorts() {
                checkSystemCost()
            }
                
            // Choice #3: Reduce back camera resolution
            else if reduceResolutionForCamera(.back) {
                checkSystemCost()
            }
                
            // Choice #4: Reduce front camera frame rate
            else if reduceFrameRateForCamera(.front) {
                checkSystemCost()
            }
                
            // Choice #5: Reduce frame rate of back camera
            else if reduceFrameRateForCamera(.back) {
                checkSystemCost()
            } else {
                print("Unable to further reduce session cost.")
            }
            
        case .hardwareCost:
            // Choice #1: Reduce front camera resolution
            if reduceResolutionForCamera(.front) {
                checkSystemCost()
            }
                
            // Choice 2: Reduce back camera resolution
            else if reduceResolutionForCamera(.back) {
                checkSystemCost()
            }
                
            // Choice #3: Reduce front camera frame rate
            else if reduceFrameRateForCamera(.front) {
                checkSystemCost()
            }
                
            // Choice #4: Reduce back camera frame rate
            else if reduceFrameRateForCamera(.back) {
                checkSystemCost()
            } else {
                print("Unable to further reduce session cost.")
            }
            
        case [.systemPressureCost, .hardwareCost]:
            // Choice #1: Reduce front camera resolution
            if reduceResolutionForCamera(.front) {
                checkSystemCost()
            }
                
            // Choice #2: Reduce back camera resolution
            else if reduceResolutionForCamera(.back) {
                checkSystemCost()
            }
                
            // Choice #3: Reduce front camera frame rate
            else if reduceFrameRateForCamera(.front) {
                checkSystemCost()
            }
                
            // Choice #4: Reduce back camera frame rate
            else if reduceFrameRateForCamera(.back) {
                checkSystemCost()
            } else {
                print("Unable to further reduce session cost.")
            }
            
        default:
            break
        }
    }
    
    func reduceResolutionForCamera(_ position: AVCaptureDevice.Position) -> Bool {
        for connection in captureSession.connections {
            for inputPort in connection.inputPorts {
                if inputPort.mediaType == .video && inputPort.sourceDevicePosition == position {
                    guard let videoDeviceInput: AVCaptureDeviceInput = inputPort.input as? AVCaptureDeviceInput else {
                        return false
                    }
                    
                    var dims: CMVideoDimensions
                    
                    var width: Int32
                    var height: Int32
                    var activeWidth: Int32
                    var activeHeight: Int32
                    
                    dims = CMVideoFormatDescriptionGetDimensions(videoDeviceInput.device.activeFormat.formatDescription)
                    activeWidth = dims.width
                    activeHeight = dims.height
                    
                    if ( activeHeight <= 480 ) && ( activeWidth <= 640 ) {
                        return false
                    }
                    
                    let formats = videoDeviceInput.device.formats
                    if let formatIndex = formats.firstIndex(of: videoDeviceInput.device.activeFormat) {
                        
                        for index in (0..<formatIndex).reversed() {
                            let format = videoDeviceInput.device.formats[index]
                            if format.isMultiCamSupported {
                                dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                                width = dims.width
                                height = dims.height
                                
                                if width < activeWidth || height < activeHeight {
                                    do {
                                        try videoDeviceInput.device.lockForConfiguration()
                                        videoDeviceInput.device.activeFormat = format
                                        
                                        videoDeviceInput.device.unlockForConfiguration()
                                        
                                        print("reduced width = \(width), reduced height = \(height)")
                                        
                                        return true
                                    } catch {
                                        print("Could not lock device for configuration: \(error)")
                                        
                                        return false
                                    }
                                    
                                } else {
                                    continue
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    func reduceFrameRateForCamera(_ position: AVCaptureDevice.Position) -> Bool {
        for connection in captureSession.connections {
            for inputPort in connection.inputPorts {
                
                if inputPort.mediaType == .video && inputPort.sourceDevicePosition == position {
                    guard let videoDeviceInput: AVCaptureDeviceInput = inputPort.input as? AVCaptureDeviceInput else {
                        return false
                    }
                    let activeMinFrameDuration = videoDeviceInput.device.activeVideoMinFrameDuration
                    var activeMaxFrameRate: Double = Double(activeMinFrameDuration.timescale) / Double(activeMinFrameDuration.value)
                    activeMaxFrameRate -= 10.0
                    
                    // Cap the device frame rate to this new max, never allowing it to go below 15 fps
                    if activeMaxFrameRate >= 15.0 {
                        do {
                            try videoDeviceInput.device.lockForConfiguration()
                            videoDeviceInput.videoMinFrameDurationOverride = CMTimeMake(value: 1, timescale: Int32(activeMaxFrameRate))
                            
                            videoDeviceInput.device.unlockForConfiguration()
                            
                            print("reduced fps = \(activeMaxFrameRate)")
                            
                            return true
                        } catch {
                            print("Could not lock device for configuration: \(error)")
                            return false
                        }
                    } else {
                        return false
                    }
                }
            }
        }
        
        return false
    }
    
    func reduceVideoInputPorts () -> Bool {
        var newConnection: AVCaptureConnection
        var result = false
        
        for connection in captureSession.connections {
            for inputPort in connection.inputPorts where inputPort.sourceDeviceType == .builtInDualCamera {
                print("Changing input from dual to single camera")
                
                guard let videoDeviceInput: AVCaptureDeviceInput = inputPort.input as? AVCaptureDeviceInput,
                    let wideCameraPort: AVCaptureInput.Port = videoDeviceInput.ports(for: .video,
                                                                                     sourceDeviceType: .builtInWideAngleCamera,
                                                                                     sourceDevicePosition: videoDeviceInput.device.position).first else {
                                                                                        return false
                }
                
                if let previewLayer = connection.videoPreviewLayer {
                    newConnection = AVCaptureConnection(inputPort: wideCameraPort, videoPreviewLayer: previewLayer)
                } else if let savedOutput = connection.output {
                    newConnection = AVCaptureConnection(inputPorts: [wideCameraPort], output: savedOutput)
                } else {
                    continue
                }
                captureSession.beginConfiguration()
                
                captureSession.removeConnection(connection)
                
                if captureSession.canAddConnection(newConnection) {
                    captureSession.addConnection(newConnection)
                    
                    captureSession.commitConfiguration()
                    result = true
                } else {
                    print("Could not add new connection to the session")
                    captureSession.commitConfiguration()
                    return false
                }
            }
        }
        return result
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