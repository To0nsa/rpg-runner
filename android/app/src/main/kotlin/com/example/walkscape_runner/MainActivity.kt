package com.example.rpg_runner

import android.util.Log
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.games.PlayGames
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            playGamesAuthChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                requestServerAuthCodeMethod -> requestPlayGamesServerAuthCode(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun requestPlayGamesServerAuthCode(result: MethodChannel.Result) {
        val webClientId = resolvePlayGamesServerClientId()
        Log.d(logTag, "Resolved Play Games web client ID: ${webClientId ?: "<missing>"}")
        if (webClientId == null) {
            result.error(
                "missing-web-client-id",
                "No Play Games web client ID was found. Set play_games_server_client_id or re-download google-services.json and rebuild.",
                null,
            )
            return
        }

        val gamesSignInClient = PlayGames.getGamesSignInClient(this)
        gamesSignInClient
            .signIn()
            .addOnSuccessListener { authResult ->
                if (!authResult.isAuthenticated) {
                    result.error(
                        "play-games-not-authenticated",
                        "Play Games sign-in completed but player is not authenticated.",
                        null,
                    )
                    return@addOnSuccessListener
                }

                gamesSignInClient
                    .requestServerSideAccess(webClientId, false)
                    .addOnSuccessListener { authCode ->
                        Log.d(
                            logTag,
                            "Play Games server auth code received: nonEmpty=${authCode.isNotBlank()} length=${authCode.length}",
                        )
                        if (authCode.isBlank()) {
                            result.error(
                                "missing-server-auth-code",
                                "Play Games did not return a server auth code.",
                                null,
                            )
                            return@addOnSuccessListener
                        }
                        result.success(authCode)
                    }.addOnFailureListener { error ->
                        if (isCanceled(error)) {
                            Log.d(logTag, "Play Games server auth code request canceled.")
                            result.success(null)
                            return@addOnFailureListener
                        }
                        Log.e(
                            logTag,
                            "Play Games server auth code request failed: ${error.message ?: error}",
                            error,
                        )
                        result.error(
                            "server-auth-code-failed",
                            error.message ?: error.toString(),
                            null,
                        )
                    }
            }.addOnFailureListener { error ->
                if (isCanceled(error)) {
                    Log.d(logTag, "Play Games sign-in canceled.")
                    result.success(null)
                    return@addOnFailureListener
                }
                Log.e(
                    logTag,
                    "Play Games sign-in failed: ${error.message ?: error}",
                    error,
                )
                result.error(
                    "play-games-sign-in-failed",
                    error.message ?: error.toString(),
                    null,
                )
            }
    }

    private fun resolvePlayGamesServerClientId(): String? {
        val explicitClientId = resolveStringResource("play_games_server_client_id")
        if (!explicitClientId.isNullOrBlank()) {
            return explicitClientId
        }
        return resolveStringResource("default_web_client_id")
    }

    private fun resolveStringResource(name: String): String? {
        val identifier =
            applicationContext.resources.getIdentifier(
                name,
                "string",
                applicationContext.packageName,
            )
        if (identifier == 0) {
            return null
        }
        return applicationContext.getString(identifier).takeIf { it.isNotBlank() }
    }

    private fun isCanceled(error: Exception): Boolean {
        if (error !is ApiException) {
            return false
        }
        return error.statusCode == CommonStatusCodes.CANCELED
    }

    private companion object {
        private const val logTag = "RpgRunnerPlayGames"
        private const val playGamesAuthChannel = "rpg_runner/play_games_auth"
        private const val requestServerAuthCodeMethod = "requestServerAuthCode"
    }
}
