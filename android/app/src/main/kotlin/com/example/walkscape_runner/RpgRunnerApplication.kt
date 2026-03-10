package com.example.rpg_runner

import android.app.Application
import com.google.android.gms.games.PlayGamesSdk

class RpgRunnerApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        PlayGamesSdk.initialize(this)
    }
}
