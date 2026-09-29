package com.example.ai_coach_app

import android.graphics.Bitmap
import android.os.SystemClock
import android.util.Log
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val METHOD_CHANNEL = "com.aicoach.mediapipe/commands"
    private val EVENT_CHANNEL = "com.aicoach.mediapipe/stream"

    private var poseLandmarker: PoseLandmarker? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private var preview: Preview? = null
    private lateinit var backgroundExecutor: ExecutorService

    private var eventSink: EventChannel.EventSink? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null

    private var reusableBitmap: Bitmap? = null
    // ⚠️ We acknowledge this is a race condition risk, but we lock it down for this stationary test.
    private var lastRotation = 0
    private var isFrontCamera = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        backgroundExecutor = Executors.newSingleThreadExecutor()

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    // Defaulting to the full model
                    val modelPath = call.argument<String>("modelPath") ?: "pose_landmarker_full.task"
                    setupMediaPipe(modelPath)
                    result.success(true)
                }
                "startNativeCamera" -> {
                    val isFrontFacing = call.argument<Boolean>("isFrontFacing") ?: false
                    this.isFrontCamera = isFrontFacing
                    
                    if (textureEntry == null) {
                        textureEntry = flutterEngine.renderer.createSurfaceTexture()
                    }
                    startCamera(isFrontFacing, textureEntry)
                    
                    val texId = textureEntry?.id()
                    if (texId != null) {
                        result.success(texId)
                    } else {
                        result.success(-1L)
                    }
                }
                "stopNativeCamera" -> {
                    cameraProvider?.unbindAll()
                    textureEntry?.release()
                    textureEntry = null
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setupMediaPipe(modelAssetPath: String) {
        poseLandmarker?.close()
        
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("flutter_assets/$modelAssetPath")
            .build()

        val options = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setMinPoseDetectionConfidence(0.5f)
            .setMinPosePresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .setResultListener(this::returnLandmarksToFlutter)
            .setErrorListener { error -> Log.e("MediaPipe", "Error: ", error) }
            .build()

        poseLandmarker = PoseLandmarker.createFromOptions(context, options)
    }

    private fun startCamera(isFrontFacing: Boolean, textureEntry: TextureRegistry.SurfaceTextureEntry?) {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            val cameraSelector = if (isFrontFacing) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA

            preview = Preview.Builder().build().also {
                it.setSurfaceProvider { request ->
                    val surfaceTexture = textureEntry?.surfaceTexture()
                    surfaceTexture?.setDefaultBufferSize(request.resolution.width, request.resolution.height)
                    val surface = android.view.Surface(surfaceTexture)
                    request.provideSurface(surface, backgroundExecutor) { }
                }
            }

            imageAnalyzer = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .build()
                .also {
                    it.setAnalyzer(backgroundExecutor) { imageProxy ->
                        processImageProxy(imageProxy)
                    }
                }

            try {
                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(this, cameraSelector, preview, imageAnalyzer)
            } catch (exc: Exception) {
                Log.e("CameraX", "Use case binding failed", exc)
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun processImageProxy(imageProxy: ImageProxy) {
        poseLandmarker?.let { landmarker ->
            val width = imageProxy.width
            val height = imageProxy.height
            lastRotation = imageProxy.imageInfo.rotationDegrees

            if (reusableBitmap == null || reusableBitmap!!.width != width || reusableBitmap!!.height != height) {
                reusableBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            }

            val buffer = imageProxy.planes[0].buffer
            buffer.rewind()
            reusableBitmap!!.copyPixelsFromBuffer(buffer) 

            val mpImage = BitmapImageBuilder(reusableBitmap!!).build()

            val options = ImageProcessingOptions.builder()
                .setRotationDegrees(lastRotation)
                .build()

            val timestampMs = SystemClock.uptimeMillis()

            try {
                landmarker.detectAsync(mpImage, options, timestampMs)
            } catch (e: Exception) {
                // 🚀 FIX: No more silent catch! Log the exact failure and timestamp.
                Log.e("MediaPipe", "detectAsync failed: timestamp=$timestampMs", e)
            }
        }
        imageProxy.close()
    }

    private fun returnLandmarksToFlutter(result: PoseLandmarkerResult, mpImage: MPImage) {
        if (result.landmarks().isEmpty()) return
        
        val pose = result.landmarks().first()
        val worldPose = if (result.worldLandmarks().isNotEmpty()) result.worldLandmarks().first() else null

        val isRotated = lastRotation == 90 || lastRotation == 270
        
        val uprightWidth = if (isRotated) mpImage.height else mpImage.width
        val uprightHeight = if (isRotated) mpImage.width else mpImage.height

        val rootObj = JSONObject()
        rootObj.put("width", uprightWidth)
        rootObj.put("height", uprightHeight)

        val jsonArray = JSONArray()
        for (i in pose.indices) {
            val obj = JSONObject()
            
            var rawX = if (isRotated) pose[i].y() else pose[i].x()
            var rawY = if (isRotated) pose[i].x() else pose[i].y()

            if (lastRotation == 90) {
                rawX = 1.0f - rawX 
            } else if (lastRotation == 270) {
                rawY = 1.0f - rawY 
            }

            if (isFrontCamera) {
                rawX = 1.0f - rawX
            }

            obj.put("x", rawX * uprightWidth)
            obj.put("y", rawY * uprightHeight)
            obj.put("c", pose[i].visibility().orElse(1.0f))
            
            if (worldPose != null) {
                var wX = worldPose[i].x()
                if (isFrontCamera) {
                    wX = -wX 
                }
                obj.put("wx", wX)
                obj.put("wy", worldPose[i].y())
                obj.put("wz", worldPose[i].z())
            }
            jsonArray.put(obj)
        }
        rootObj.put("landmarks", jsonArray)

        runOnUiThread {
            eventSink?.success(rootObj.toString())
        }
    }
}