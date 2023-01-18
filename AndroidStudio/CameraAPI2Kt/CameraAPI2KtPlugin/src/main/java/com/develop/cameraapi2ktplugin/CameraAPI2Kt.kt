package com.develop.cameraapi2ktplugin

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.hardware.camera2.params.OutputConfiguration
import android.hardware.camera2.params.SessionConfiguration
import android.media.Image
import android.media.ImageReader
import android.media.ImageReader.OnImageAvailableListener
import android.opengl.GLES20
import android.opengl.GLUtils
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.util.Size
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.unity3d.player.UnityPlayer
import java.util.*


class CameraAPI2Kt{
    private val TAG = "CameraAPI2Kt"

    private var imageReader: ImageReader? = null
    private var cameraDevice: CameraDevice? = null
    private var characteristics: CameraCharacteristics? = null
    private var previewRequestBuilder: CaptureRequest.Builder? = null
    private var backgroundHandler: Handler? = null
    private var backgroundThread: HandlerThread? = null
    private var captureSession: CameraCaptureSession? = null
    private var previewSize: Size? = null
    private var cameraId: String? = null

    private lateinit var textureIds: IntArray
    private var textureId = 0
    private var bmp: Bitmap? = null

    private var cameraType = 0; // 0:back, 1:front

    private var currentActivity: Activity? = null

    private var imgWidth = 1080
    private var imgHeight = 1920

    companion object {
        private val REQUEST_CAMERA_PERMISSION = 200
    }

    init {
        currentActivity = UnityPlayer.currentActivity
    }

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = backgroundThread?.looper?.let { Handler(it) }
    }

    private fun stopBackgroundThread() {
        backgroundThread!!.quitSafely()
        try {
            backgroundThread!!.join()
            backgroundThread = null
            backgroundHandler = null
        } catch (e: InterruptedException) {
            e.printStackTrace()
        }
    }

    private fun createImageReader(width: Int, height: Int, handler: Handler): ImageReader? {
        val imageReader = ImageReader.newInstance(width, height, ImageFormat.JPEG, 1)
        imageReader.setOnImageAvailableListener(onImageAvailableListener, handler)
        return imageReader
    }

    private val onImageAvailableListener = OnImageAvailableListener { reader ->
        var image = reader.acquireNextImage()
        val bytes = imageToByteArray(image)
        if (bytes != null) bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        image!!.close()
        image = null
    }

    private fun imageToByteArray(image: Image?): ByteArray? {
        return if (image!!.format == ImageFormat.JPEG) {
            val planes = image.planes
            val buffer = planes[0].buffer
            val size = buffer.capacity()
            val bytes = ByteArray(size)
            buffer[bytes]
            bytes
        } else {
            //Log.e(TAG, "ImageToByteArray: unsupported image format");
            null
        }
    }

    private fun createSurfaceTexture(w: Int, h: Int) {
        textureIds = IntArray(1)
        GLES20.glGenTextures(1, textureIds, 0)
        textureId = textureIds[0]
        var bp = Bitmap.createBitmap(w, h, Bitmap.Config.RGB_565)
        Log.d(TAG, "createSurfaceTexture() start")
        Log.d(TAG, "Thread name = " + Thread.currentThread().name)
        updateGLTexture(textureId, bp, false)
        if (!bp!!.isRecycled) {
            bp.recycle()
        }
        bp = null
        Log.d(TAG, "Texture created! " + textureId)
    }

    private fun updateGLTexture(id: Int, bp: Bitmap?, isUpdate: Boolean) {
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, id)

        //checkGlError(TAG, "glBindTexture videoTextureId");
        GLES20.glTexParameterf(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE.toFloat())
        GLES20.glTexParameterf(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE.toFloat())
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        if (!isUpdate) GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bp, 0)
    }

    private fun checkGlError(tag: String, op: String) {
        var error: Int
        if (GLES20.glGetError().also { error = it } != GLES20.GL_NO_ERROR) {
            Log.e(tag, "$op: glError $error")
            throw RuntimeException(op + ": glError 0x" + Integer.toHexString(error))
        }
    }

    private fun openCamera() {
        val manager = currentActivity!!.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        Log.e(TAG, "is camera open")
        try {
            cameraId = manager.cameraIdList[0] // back camera
            if(manager.cameraIdList.size>=2 && cameraType == 1){
                cameraId = manager.cameraIdList[1] // front camera
            }
            characteristics = manager.getCameraCharacteristics(cameraId!!)
            val map = characteristics!!.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)!!
            previewSize = map.getOutputSizes(SurfaceTexture::class.java)[0]
            Log.d(TAG, "previewSize " + previewSize!!.getWidth() + "," + previewSize!!.getHeight())
            if (ActivityCompat.checkSelfPermission(currentActivity!!, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED && ActivityCompat.checkSelfPermission(currentActivity!!, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                requestPermission()
                return
            }
            manager.openCamera(cameraId!!, stateCallback, null)
        } catch (e: CameraAccessException) {
            e.printStackTrace()
        }
        Log.d(TAG, "openCamera X")
    }

    private val stateCallback: CameraDevice.StateCallback = object : CameraDevice.StateCallback() {
        override fun onOpened(camera: CameraDevice) {
            //This is called when the camera is open
            Log.d(TAG, "onOpened")
            cameraDevice = camera
            imageReader = createImageReader(imgWidth, imgHeight, backgroundHandler!!)
            createCameraPreview()
        }

        override fun onDisconnected(camera: CameraDevice) {
            cameraDevice!!.close()
        }

        override fun onError(camera: CameraDevice, error: Int) {
            cameraDevice!!.close()
            cameraDevice = null
        }
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun createCameraPreview() {
        try {

            val surface = imageReader!!.surface
            previewRequestBuilder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            previewRequestBuilder!!.addTarget(surface)

            Log.d(TAG, "createCameraPreviewSession called")

            val surfaces = Arrays.asList(surface)
            val type = SessionConfiguration.SESSION_REGULAR
            val configurations = surfaces.map { OutputConfiguration(it) }
            val executor = ContextCompat.getMainExecutor(currentActivity)
            val callback = object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(cameraCaptureSession: CameraCaptureSession) {

                    if (cameraDevice == null) {
                        return
                    }

                    captureSession = cameraCaptureSession
                    updatePreview()
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    //Tools.makeToast(baseContext, "Failed")
                    Log.d(TAG, "createCameraPreview Failed")
                }
            }

            val configuration = SessionConfiguration(type, configurations, executor, callback)
            cameraDevice!!.createCaptureSession(configuration)

//            cameraDevice?.createCaptureSession(
//                Arrays.asList(surface, imageReader?.surface),
//                object : CameraCaptureSession.StateCallback() {
//
//                    override fun onConfigured(cameraCaptureSession: CameraCaptureSession) {
//
//                        if (cameraDevice == null) return
//                        captureSession = cameraCaptureSession
//                        try {
//                            previewRequestBuilder.set(
//                                CaptureRequest.CONTROL_AF_MODE,
//                                CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
//                            previewRequest = previewRequestBuilder.build()
//                            captureSession?.setRepeatingRequest(previewRequest,
//                                null, backgroundThread?.looper?.let { Handler(it) }
//                            )
//                        } catch (e: CameraAccessException) {
//                            Log.e("erfs", e.toString())
//                        }
//
//                    }
//
//                    override fun onConfigureFailed(session: CameraCaptureSession) {
//                        //Tools.makeToast(baseContext, "Failed")
//                    }
//                }, null)
        } catch (e: CameraAccessException) {
            Log.e("erf", e.toString())
        }

    }

    private fun updatePreview() {
        if (null == cameraDevice) {
            Log.e(TAG, "updatePreview error, return")
        }
        previewRequestBuilder!!.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
        try {
            captureSession!!.setRepeatingRequest(previewRequestBuilder!!.build(), null, backgroundHandler)
        } catch (e: CameraAccessException) {
            e.printStackTrace()
        }
    }

    private fun release() {
        if (textureIds != null) {
            GLES20.glDeleteTextures(textureIds.size, textureIds, 0)
            textureIds[0] = 0
        }
        bmp = null
    }

    /* Unity methods */
    fun startCamera(w: Int, h: Int, type:Int){
        imgWidth = w
        imgHeight = h
        cameraType = type
        startBackgroundThread();
        createSurfaceTexture(imgWidth, imgHeight)
        openCamera()
    }

    fun closeCamera() {
        stopBackgroundThread()
        if (captureSession != null) {
            try {
                captureSession!!.stopRepeating()
            } catch (e: CameraAccessException) {
                Log.e(TAG, "closeCamera: " + e.message)
            }
            captureSession!!.close()
            captureSession = null
        }
        if (cameraDevice != null) {
            cameraDevice!!.close()
            cameraDevice = null
        }
        if (null != imageReader) {
            imageReader!!.close()
            imageReader = null
        }
        release()
    }

    fun getAndroidTextureID(): Int {
        return textureId
    }

    fun hasPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(currentActivity!!, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    }

    fun requestPermission() {
        ActivityCompat.requestPermissions(currentActivity!!, arrayOf(Manifest.permission.CAMERA, Manifest.permission.WRITE_EXTERNAL_STORAGE), com.develop.cameraapi2ktplugin.CameraAPI2Kt.REQUEST_CAMERA_PERMISSION)
    }

    fun getWidth(): Int {
        return if (previewSize == null) 0 else previewSize!!.width
    }

    fun getHeight(): Int {
        return if (previewSize == null) 0 else previewSize!!.height
    }

    fun updateTexture() {
        if (bmp == null) {
            //Log.d(TAG, "updateTexture: Bitmap is null");
            return
        }

        //Log.d(TAG, "updateTexture: working...");
        updateGLTexture(textureId, bmp, true)
        if (!bmp!!.isRecycled) {
            bmp!!.recycle()
        }
        bmp = null
    }
}