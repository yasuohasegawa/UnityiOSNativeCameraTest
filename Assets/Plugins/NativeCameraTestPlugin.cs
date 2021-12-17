using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.UI;

public class NativeCameraTestPlugin : MonoBehaviour
{
    [DllImport("__Internal")]
    static extern void startCamera();

    [DllImport("__Internal")]
    static extern void stopCamera();

    [DllImport("__Internal")]
    private static extern void getNativeImageData(IntPtr image);

    [SerializeField]
    private RawImage img;

    private Texture2D texture;
    private Color32[] pixels;
    private GCHandle pixelsHandle;
    private IntPtr pixelsPtr;

    private const int WIDTH = 1920;
    private const int HEIGHT = 1080;

    private bool isCameraActive = false;

    // Start is called before the first frame update
    void Start()
    {

    }

    void Update()
    {
        if (isCameraActive)
        {
            getNativeImageData(pixelsPtr);
            texture.SetPixels32(pixels);
            texture.Apply();
        }
    }

    private void StartCamera()
    {
        if (isCameraActive) return;
        texture = new Texture2D(WIDTH, HEIGHT, TextureFormat.RGBA32, false);
        pixels = texture.GetPixels32();
        pixelsHandle = GCHandle.Alloc(pixels, GCHandleType.Pinned);
        pixelsPtr = pixelsHandle.AddrOfPinnedObject();
        img.texture = texture;

        startCamera();
        isCameraActive = true;
    }

    private void StopCamera()
    {
        if (!isCameraActive) return;
        isCameraActive = false;
        stopCamera();

        pixelsHandle.Free();
        pixels = null;
        Destroy(texture);
        texture = null;
    }

    public void OnStartCamera()
    {
        StartCamera();
    }

    public void OnStopCamera()
    {
        StopCamera();
    }

    void OnDestroy()
    {
#if UNITY_IOS
        StopCamera();
#endif
    }
}
