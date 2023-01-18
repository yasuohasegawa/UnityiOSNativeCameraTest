using System;
using System.Collections;
using System.Threading;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.UI;

public class AndroidPluginTest : MonoBehaviour
{
    [SerializeField] private RawImage _rawImage;

    private AndroidCameraPlugin _androidcameraPlugin;

    // Start is called before the first frame update
    void Start()
    {
        _androidcameraPlugin = new AndroidCameraPlugin();
        _androidcameraPlugin.OnCaptureStarted += OnCaptureStarted;
        _rawImage.texture = _androidcameraPlugin.Tex;
    }

    public void StartNativeCamera()
    {
        _androidcameraPlugin.StartNativeCamera();
    }

    public void StopNativeCamera()
    {
        _androidcameraPlugin.StopNativeCamera();
    }

    private void OnCaptureStarted()
    {
        _androidcameraPlugin.UpdatePreviewTransform(_rawImage);
    }

    // Update is called once per frame
    void Update()
    {
        if(_androidcameraPlugin != null)
        {
            _androidcameraPlugin.UpdateTexture();
        }
    }
}
