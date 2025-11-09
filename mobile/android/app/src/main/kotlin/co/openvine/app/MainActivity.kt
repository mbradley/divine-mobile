package co.openvine.app

import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.witness.proofmode.ProofMode
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "org.openvine/proofmode"
    private val TAG = "OpenVineProofMode"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "generateProof" -> {
                    val mediaPath = call.argument<String>("mediaPath")
                    if (mediaPath == null) {
                        result.error("INVALID_ARGUMENT", "Media path is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        Log.d(TAG, "Generating proof for: $mediaPath")

                        // Convert file path to URI
                        val mediaFile = File(mediaPath)
                        if (!mediaFile.exists()) {
                            result.error("FILE_NOT_FOUND", "Media file does not exist: $mediaPath", null)
                            return@setMethodCallHandler
                        }

                        val mediaUri = Uri.fromFile(mediaFile)

                        // Generate proof using native ProofMode library
                        val proofHash = ProofMode.generateProof(this, mediaUri)

                        Log.d(TAG, "Proof generated successfully: $proofHash")
                        result.success(proofHash)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to generate proof", e)
                        result.error("PROOF_GENERATION_FAILED", e.message, null)
                    }
                }

                "getProofDir" -> {
                    val proofHash = call.argument<String>("proofHash")
                    if (proofHash == null) {
                        result.error("INVALID_ARGUMENT", "Proof hash is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val proofDir = ProofMode.getProofDir(this, proofHash)
                        if (proofDir != null && proofDir.exists()) {
                            result.success(proofDir.absolutePath)
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to get proof directory", e)
                        result.error("GET_PROOF_DIR_FAILED", e.message, null)
                    }
                }

                "isAvailable" -> {
                    // ProofMode is always available on Android when library is included
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}