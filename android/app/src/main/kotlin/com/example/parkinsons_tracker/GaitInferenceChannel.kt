package com.example.parkinsons_tracker

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.pytorch.IValue
import org.pytorch.LiteModuleLoader
import org.pytorch.Module
import org.pytorch.Tensor
import java.io.File
import java.io.FileOutputStream

class GaitInferenceChannel(
    private val context: Context,
    messenger: BinaryMessenger
) {
    companion object {
        const val CHANNEL = "com.example.parkinsons_tracker/gait_inference"
        const val MODEL_ASSET = "gait_classifier.ptl"
        const val N_FEATURES = 27
    }

    private var module: Module? = null

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "runInference" -> {
                    val features = call.argument<List<Double>>("features")
                    if (features == null || features.size != N_FEATURES) {
                        result.error(
                            "INVALID_INPUT",
                            "Expected $N_FEATURES features, got ${features?.size ?: 0}",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    try {
                        val output = runInference(features.map { it.toFloat() }.toFloatArray())
                        result.success(output)
                    } catch (e: Exception) {
                        result.error("INFERENCE_ERROR", e.message, null)
                    }
                }
                "loadModel" -> {
                    try {
                        loadModel()
                        result.success("Model loaded successfully")
                    } catch (e: Exception) {
                        result.error("LOAD_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun loadModel() {
        if (module != null) return  // already loaded
        val modelFile = assetToFile(MODEL_ASSET)
        module = LiteModuleLoader.load(modelFile.absolutePath)
    }

    private fun runInference(features: FloatArray): Map<String, Any> {
        loadModel()  // no-op if already loaded

        val inputTensor = Tensor.fromBlob(features, longArrayOf(1, N_FEATURES.toLong()))
        val outputTensor = module!!.forward(IValue.from(inputTensor)).toTensor()
        val logit = outputTensor.dataAsFloatArray[0]

        // Sigmoid to get probability
        val probability = 1.0f / (1.0f + Math.exp(-logit.toDouble()).toFloat())
        val isImpaired = probability >= 0.5f

        return mapOf(
            "probability" to probability.toDouble(),
            "is_impaired" to isImpaired,
            "logit" to logit.toDouble()
        )
    }

    // Copies an asset file to the app's files directory so PyTorch can load it
   private fun assetToFile(assetName: String): File {
    val file = File(context.filesDir, assetName)
    if (!file.exists()) {
        context.assets.open("flutter_assets/assets/$assetName").use { input ->
            FileOutputStream(file).use { output ->
                input.copyTo(output)
            }
        }
    }
    return file
}
}
