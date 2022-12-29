using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class TestMultiCam : MonoBehaviour
{
    [SerializeField] private RawImage _backImage;
    [SerializeField] private RawImage _frontImage;

    private NativeMultiCamPlugin _nativeMultiCamPlugin;

    // Start is called before the first frame update
    void Awake()
    {
        _nativeMultiCamPlugin = new NativeMultiCamPlugin();
        _nativeMultiCamPlugin.Initialize();
        _nativeMultiCamPlugin.OnBackTexCreated += OnBackTexCreated;
        _nativeMultiCamPlugin.OnFrontTexCreated += OnFrontTexCreated;
    }

    // Update is called once per frame
    void Update()
    {
        if(_nativeMultiCamPlugin != null) _nativeMultiCamPlugin.UpdateMovieTexture();
    }

    private void OnBackTexCreated(Texture2D tex)
    {
        _backImage.texture = tex;
    }

    private void OnFrontTexCreated(Texture2D tex)
    {
        _frontImage.texture = tex;
    }
}
