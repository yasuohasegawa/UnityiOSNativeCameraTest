package com.develop.cameraapi2jvplugin;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.ImageFormat;
import android.graphics.Point;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.*;
import android.hardware.camera2.params.OutputConfiguration;
import android.hardware.camera2.params.SessionConfiguration;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.Image;
import android.media.ImageReader;
import android.opengl.EGL14;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLSurface;
import android.opengl.GLES11Ext;
import android.opengl.GLES20;
import android.opengl.GLES30;
import android.opengl.GLUtils;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Log;
import android.util.Size;
import android.util.SparseIntArray;
import android.view.Surface;
import android.view.TextureView;
import androidx.annotation.RequiresApi;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import java.nio.ByteBuffer;
import java.util.*;
import java.lang.Long.*;
import java.util.Comparator;
import com.unity3d.player.UnityPlayer;

public class CameraAPI2JV{
    private String TAG = "CameraAPI2JV";
    private ImageReader imageReader;
    private CameraDevice cameraDevice;
    private CameraCharacteristics characteristics;
    private CaptureRequest.Builder previewRequestBuilder;
    private Handler backgroundHandler = null;
    private HandlerThread backgroundThread = null;
    private CameraCaptureSession captureSession;
    private Size previewSize;
    private String cameraId;
    private static final int REQUEST_CAMERA_PERMISSION = 200;

    private int[] textureIds;
    private int textureId;
    private Bitmap bmp = null;

    private int cameraType = 0; // 0:back, 1:front

    private Activity currentActivity;

    private int imgWidth = 1080;
    private int imgHeight = 1920;

    public CameraAPI2JV(){
        currentActivity = UnityPlayer.currentActivity;
    }

    private void startBackgroundThread() {
        backgroundThread = new HandlerThread("Camera Background");
        backgroundThread.start();
        backgroundHandler = new Handler(backgroundThread.getLooper());
    }

    private void stopBackgroundThread() {
        backgroundThread.quitSafely();
        try {
            backgroundThread.join();
            backgroundThread = null;
            backgroundHandler = null;
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

    private ImageReader createImageReader(int width, int height, Handler handler)
    {
        ImageReader imageReader = ImageReader.newInstance(width, height, ImageFormat.JPEG, 1);
        imageReader.setOnImageAvailableListener(onImageAvailableListener, handler);
        return imageReader;
    }

    private ImageReader.OnImageAvailableListener onImageAvailableListener = new ImageReader.OnImageAvailableListener()
    {
        @Override
        public void onImageAvailable(ImageReader reader)
        {
            Image image = reader.acquireNextImage();

            byte[] bytes = imageToByteArray(image);
            if (bytes != null)bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);

            image.close();
            image = null;
        }
    };

    private byte[] imageToByteArray(Image image)
    {
        if (image.getFormat() == ImageFormat.JPEG)
        {
            Image.Plane[] planes = image.getPlanes();
            ByteBuffer buffer = planes[0].getBuffer();
            int size = buffer.capacity();
            byte[] bytes = new byte[size];
            buffer.get(bytes);
            return bytes;
        }
        else
        {
            return null;
        }
    }

    private void createSurfaceTexture(int w, int h) {
        textureIds = new int[1];
        GLES20.glGenTextures(1, textureIds, 0);
        this.textureId = textureIds[0];

        Bitmap bp = Bitmap.createBitmap(w, h, Bitmap.Config.RGB_565);

        Log.d( TAG, "createSurfaceTexture() start" );
        Log.d( TAG, "Thread name = " + Thread.currentThread().getName() );

        updateGLTexture(this.textureId,bp,false);

        if (!bp.isRecycled())
        {
            bp.recycle();
        }
        bp = null;

        Log.d(TAG, "Texture created! " + this.textureId);
    }

    private void updateGLTexture(int id, Bitmap bp, boolean isUpdate){
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0);
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, id);

        //checkGlError(TAG, "glBindTexture videoTextureId");

        GLES20.glTexParameterf(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE);
        GLES20.glTexParameterf(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE);
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR);
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);

        if(!isUpdate)GLES20.glBindTexture( GLES20.GL_TEXTURE_2D, 0 );

        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bp, 0);
    }

    private void checkGlError(String tag, String op) {
        int error;
        if ((error = GLES20.glGetError()) != GLES20.GL_NO_ERROR) {
            Log.e(tag, op + ": glError " + error);
            throw new RuntimeException(op + ": glError 0x" + Integer.toHexString(error));
        }
    }

    private void openCamera() {
        CameraManager manager = (CameraManager) currentActivity.getSystemService(Context.CAMERA_SERVICE);
        Log.e(TAG, "is camera open");
        try {
            cameraId = manager.getCameraIdList()[0]; // back camera
            if(manager.getCameraIdList().length>=2 && cameraType == 1){
                cameraId = manager.getCameraIdList()[1]; // front camera
            }

            characteristics = manager.getCameraCharacteristics(cameraId);
            StreamConfigurationMap map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
            assert map != null;
            previewSize = map.getOutputSizes(SurfaceTexture.class)[0];
            Log.d(TAG, "previewSize " + previewSize.getWidth()+","+previewSize.getHeight());

            if (ActivityCompat.checkSelfPermission(currentActivity, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED && ActivityCompat.checkSelfPermission(currentActivity, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                requestPermission();
                return;
            }
            manager.openCamera(cameraId, stateCallback, null);
        } catch (CameraAccessException e) {
            e.printStackTrace();
        }
        Log.d(TAG, "openCamera X");
    }

    private final CameraDevice.StateCallback stateCallback = new CameraDevice.StateCallback() {
        @Override
        public void onOpened(CameraDevice camera) {
            //This is called when the camera is open
            Log.d(TAG, "onOpened");
            cameraDevice = camera;

            imageReader = createImageReader(imgWidth,imgHeight,backgroundHandler);

            createCameraPreview();
        }

        @Override
        public void onDisconnected(CameraDevice camera) {
            cameraDevice.close();
        }

        @Override
        public void onError(CameraDevice camera, int error) {
            cameraDevice.close();
            cameraDevice = null;
        }
    };

    private void createCameraPreview() {
        try {
            Surface surface = imageReader.getSurface();
            previewRequestBuilder = cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
            previewRequestBuilder.addTarget(surface);
            cameraDevice.createCaptureSession(Arrays.asList(surface), new CameraCaptureSession.StateCallback() {
                @Override
                public void onConfigured(@NonNull CameraCaptureSession cameraCaptureSession) {

                    if (null == cameraDevice) {
                        return;
                    }

                    captureSession = cameraCaptureSession;
                    updatePreview();
                }

                @Override
                public void onConfigureFailed(@NonNull CameraCaptureSession cameraCaptureSession) {
                    //Toast.makeText(MainActivity.this, "Configuration change", Toast.LENGTH_SHORT).show();
                }
            }, backgroundHandler);
        } catch (CameraAccessException e) {
            e.printStackTrace();
        }
    }

    protected void updatePreview() {
        if (null == cameraDevice) {
            Log.e(TAG, "updatePreview error, return");
        }

        previewRequestBuilder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE);

        try {
            captureSession.setRepeatingRequest(previewRequestBuilder.build(), null, backgroundHandler);
        } catch (CameraAccessException e) {
            e.printStackTrace();
        }
    }

    private void release() {
        if (textureIds != null) {
            GLES20.glDeleteTextures(textureIds.length, textureIds, 0);
            textureIds[0] = 0;
        }
        bmp = null;
    }

    /* Unity methods */

    public void startCamera(int w, int h, int type){
        imgWidth = w;
        imgHeight = h;
        cameraType = type;

        startBackgroundThread();
        createSurfaceTexture(imgWidth,imgHeight);
        openCamera();
    }

    public void closeCamera() {
        stopBackgroundThread();

        if(captureSession != null){
            try
            {
                captureSession.stopRepeating();
            }
            catch (CameraAccessException e)
            {
                Log.e(TAG, "closeCamera: " + e.getMessage());
            }
            captureSession.close();
            captureSession = null;
        }

        if (cameraDevice != null) {
            cameraDevice.close();
            cameraDevice = null;
        }
        if (null != imageReader) {
            imageReader.close();
            imageReader = null;
        }
        release();
    }

    public int getAndroidTextureID() {
        return this.textureId;
    }

    public boolean hasPermission(){
        return ActivityCompat.checkSelfPermission(currentActivity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED;
    }

    public void requestPermission(){
        ActivityCompat.requestPermissions(currentActivity, new String[]{Manifest.permission.CAMERA, Manifest.permission.WRITE_EXTERNAL_STORAGE}, REQUEST_CAMERA_PERMISSION);
    }

    public int getWidth(){
        if(previewSize == null)return 0;
        return previewSize.getWidth();
    }

    public int getHeight(){
        if(previewSize == null)return 0;
        return previewSize.getHeight();
    }

    public void updateTexture() {
        if (bmp == null)
        {
            //Log.d(TAG, "updateTexture: Bitmap is null");
            return;
        }

        //Log.d(TAG, "updateTexture: working...");

        updateGLTexture(this.textureId,bmp,true);

        if (!bmp.isRecycled())
        {
            bmp.recycle();
        }
        bmp = null;
    }

//    @Override
//    protected void onResume() {
//        super.onResume();
//        Log.e(TAG, "onResume");
//        startBackgroundThread();
//        if (textureView.isAvailable()) {
//            openCamera();
//        } else {
//            textureView.setSurfaceTextureListener(textureListener);
//        }
//    }
//
//    @Override
//    protected void onPause() {
//        Log.e(TAG, "onPause");
//        //closeCamera();
//        stopBackgroundThread();
//        super.onPause();
//    }
}
