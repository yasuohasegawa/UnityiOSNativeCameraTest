# UnityiOSNativeCameraTest
example codes of Unity iOS camera implementation without using Webcamtexture
<br>

<b>Update 18/1/23:</b><br>
・Added an native camera capture sample for Android<br>
There are 2 Android native capture plugins. One uses Java, and the other one uses Kotlin. The feature is the same. We also pushed the Android Studio project files.
About the Kotlin project, if you will work on the latest Android Studio, you also need to update the Kotlin version in Gradle build, download the `kotlin-stdlib.jar` from the following link, and replace it with the downloaded jar file.
The `kotlin-stdlib.jar` should match with the version specified in the Gradle build.<br>
<br>
https://github.com/JetBrains/kotlin/releases/<br>
<br>
In the player setting, please set up the Graphics API to the OpenGL3.x only. The project has been using the OpenGL texture to pass it to the Unity side.
<br><br>
I know the name of this repository named `UnityiOSNativeCameraTest`, but I did not want to separate the sample in new repository. That's why we added it here.<br><br>
We've tried to investigate capturing the back and front cameras at the same time like the iOS has that feature.
But, there is no feature to capture both back and front cameras for Android.
We won't provide this kind of sample in this repo.

<br><br>
<b>Update 29/12/22:</b><br>
・Added an AVCaptureMultiCam sample for iOS<br>
In the iOS player setting, you need to set up the minimum os version to 13.0 and default orientation setting to portrait.<br>
The MultiCam scene is the main scene to build.<br>
<br>
We only tested this sample on iPhone 12 pro with iOS 16.<br>
If you'd like to use this sample in your production, you need to take care of the memory and performance as well.<br>
We would also like you to recommend to check the following swift version of MultiCamCapture sample. There are a lots of good features to improve this sample code.<br>

https://developer.apple.com/documentation/avfoundation/capture_setup/avmulticampip_capturing_from_multiple_cameras
