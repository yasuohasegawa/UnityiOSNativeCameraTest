using System;
using System.Runtime.InteropServices;
using UnityEngine;

public class NativeMultiCamPlugin
{
    [DllImport("__Internal")]
    private static extern IntPtr _InitMultiCapture();

    [DllImport("__Internal")]
    private static extern IntPtr _GetBackMTLTexture(IntPtr multiCamPtr);

    [DllImport("__Internal")]
    private static extern IntPtr _GetFrontMTLTexture(IntPtr multiCamPtr);

    [DllImport("__Internal")]
    private static extern bool _IsMTLTextureCreated(IntPtr multiCamPtr);

    private Texture2D _backTexture;
    private Texture2D _frontTexture;

    private static IntPtr _multiCamInstance;
    private static IntPtr _backTexPtr;
    private static IntPtr _frontTexPtr;

    private const int TEX_WIDTH = 1080;
    private const int TEX_HEIGHT = 1920;

    public Action<Texture2D> OnBackTexCreated;
    public Action<Texture2D> OnFrontTexCreated;

    public void Initialize()
    {
#if !UNITY_EDITOR && UNITY_IOS
        _multiCamInstance = _InitMultiCapture();
#endif
    }

    public void UpdateMovieTexture()
    {
        if (_IsMTLTextureCreated(_multiCamInstance))
        {
            // back
            _backTexPtr = _GetBackMTLTexture(_multiCamInstance);

            if(_backTexPtr != null)
            {
                if (_backTexture == null)
                {
                    Debug.Log($"[UpdateMovieTexture] back:{_backTexPtr}");
                    // The following codes call only once.
                    _backTexture = Texture2D.CreateExternalTexture(
                        TEX_WIDTH,
                        TEX_HEIGHT,
                        TextureFormat.RGBA32,
                        false,
                        true,
                        _backTexPtr);
                    _backTexture.UpdateExternalTexture(_backTexPtr);

                    //Debug.Log($">>>>> CreateExternalTexture: {m_width}/{m_height}");

                    OnBackTexCreated?.Invoke(_backTexture);
                }
                else
                {
                    _backTexture.UpdateExternalTexture(_backTexPtr);
                }
            }

            // front
            _frontTexPtr = _GetFrontMTLTexture(_multiCamInstance);

            if(_frontTexPtr != null)
            {
                if (_frontTexture == null)
                {
                    Debug.Log($"[UpdateMovieTexture] front:{_frontTexPtr}");
                    // The following codes call only once.
                    _frontTexture = Texture2D.CreateExternalTexture(
                        TEX_WIDTH,
                        TEX_HEIGHT,
                        TextureFormat.RGBA32,
                        false,
                        true,
                        _frontTexPtr);
                    _frontTexture.UpdateExternalTexture(_frontTexPtr);

                    //Debug.Log($">>>>> CreateExternalTexture: {m_width}/{m_height}");

                    OnFrontTexCreated?.Invoke(_frontTexture);
                }
                else
                {
                    _frontTexture.UpdateExternalTexture(_frontTexPtr);
                }
            }
        }
    }
}
