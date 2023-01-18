using System;
using System.Collections;
using System.Threading;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.UI;

public enum eCameraMode
{
    Back,
    Front
}

public class AndroidCameraPlugin
{
    private Texture2D _tex;

    private IntPtr _texPtr;

    private AndroidJavaObject _androidJavaObject;

    private bool _hasPermission = false;

    private CancellationTokenSource _cancellationTokenSource;

    private int _captureWidth = 1920;
    private int _captureHeight = 1080;

    private eCameraMode _cameraMode = eCameraMode.Back;

    public Texture2D Tex => _tex;

    public Action OnCaptureStarted;

    public AndroidCameraPlugin()
    {
        CreateCaptureTexture();
#if !UNITY_EDITOR
        //using (AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
        //using (AndroidJavaObject currentActivity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity"))
        //_androidJavaObject = new AndroidJavaObject("com.develop.cameraapi2jvplugin.CameraAPI2JV"); // Java version
        _androidJavaObject = new AndroidJavaObject("com.develop.cameraapi2ktplugin.CameraAPI2Kt"); // kotlin version
#endif
    }

    private void CreateCaptureTexture()
    {
        _tex = new Texture2D(_captureWidth, _captureHeight, TextureFormat.ARGB32, false)
        { filterMode = FilterMode.Point };
        _tex.Apply();
    }

    public void StartNativeCamera()
    {
        if (_androidJavaObject != null)
        {
            CancelToken();
            _cancellationTokenSource = new CancellationTokenSource();
            _hasPermission = _androidJavaObject.Call<bool>("hasPermission");
            if (!_hasPermission)
            {
                _androidJavaObject.Call("requestPermission");
            }
            CheckPermission();
        }
    }

    public void StopNativeCamera()
    {
        if (_androidJavaObject != null)
        {
            _androidJavaObject.Call("closeCamera");
        }
    }

    private async void CheckPermission()
    {
        Debug.Log(">>>>>> CheckPermission called");
        while (true)
        {
            await Task.Delay(100);
            _hasPermission = _androidJavaObject.Call<bool>("hasPermission");
            Debug.Log($">>>> CheckPermission1:{_hasPermission}");
            if (_hasPermission) break;
            if (_cancellationTokenSource.IsCancellationRequested) break;
        }
        if (_cancellationTokenSource.IsCancellationRequested) return;
        Debug.Log($">>>> CheckPermission2 end:{_hasPermission}");
        _androidJavaObject.Call("startCamera", _captureWidth, _captureHeight, (int)_cameraMode);
        int iAndroidTextureID = _androidJavaObject.Call<int>("getAndroidTextureID");
        Debug.Log("iAndroidTextureID = " + iAndroidTextureID.ToString());
        _texPtr = new IntPtr(iAndroidTextureID);
        CancelToken();
        OnCaptureStarted?.Invoke();
    }

    public void UpdatePreviewTransform(RawImage img)
    {
        var angle = img.transform.localEulerAngles;
        var scale = img.transform.localScale;
        angle.x = 0;
        angle.y = 0;

        if (_cameraMode == eCameraMode.Back)
        {
            angle.z = 90;
            scale.x = -1;
            scale.y = 1;
            scale.z = 1;
        }
        else if (_cameraMode == eCameraMode.Front)
        {
            angle.z = -90;
            scale.x = -1;
            scale.y = -1;
            scale.z = 1;
        }

        img.transform.localEulerAngles = angle;
        img.transform.localScale = scale;
    }

    private void CancelToken()
    {
        _cancellationTokenSource?.Cancel();
        _cancellationTokenSource?.Dispose();
        _cancellationTokenSource = null;
    }

    public void UpdateTexture()
    {
#if !UNITY_EDITOR
            if (_androidJavaObject != null)
            {
                _androidJavaObject.Call("updateTexture");
                _tex.UpdateExternalTexture(_texPtr);
            }
#endif
    }
}
