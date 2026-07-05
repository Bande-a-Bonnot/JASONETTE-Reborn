package com.jasonette.rendering

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Small production geolocation seam for `$geo.get`.
 *
 * This intentionally uses already-authorized last-known Android locations as a
 * baseline. Runtime permission prompting remains future work for fuller legacy
 * Android parity.
 */
class AndroidGeolocationProvider(private val context: Context) {
    suspend fun currentCoordinate(): String = withContext(Dispatchers.IO) {
        if (!hasLocationPermission()) {
            throw ActionDispatcher.ActionException("Location permission denied")
        }
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            ?: throw ActionDispatcher.ActionException("Location services unavailable")
        val location = bestLastKnownLocation(locationManager)
            ?: throw ActionDispatcher.ActionException("Location unavailable")
        "${location.latitude},${location.longitude}"
    }

    private fun hasLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun bestLastKnownLocation(locationManager: LocationManager): Location? =
        locationManager.getProviders(true)
            .mapNotNull { provider ->
                try {
                    locationManager.getLastKnownLocation(provider)
                } catch (_: SecurityException) {
                    null
                } catch (_: IllegalArgumentException) {
                    null
                }
            }
            .maxByOrNull { it.time }
}
