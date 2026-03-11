package com.example.omnix_dashboard.telemetry

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.os.BatteryManager
import android.os.Build
import android.os.StatFs
import android.util.Log
import com.example.omnix_dashboard.BuildConfig
import org.json.JSONObject
import java.util.Random

data class FskRuntimeConfig(
    val useLiveMode: Boolean,
    val useLiveModeSource: String,
    val heartbeatAction: String,
    val heartbeatActionSource: String,
    val payloadAdapterId: String,
    val payloadAdapterSource: String,
    val connectorClassName: String?,
    val connectorClassSource: String?,
)

class FskRuntimeConfigResolver(private val context: Context) {
    fun resolve(adapterRegistry: FskPayloadAdapterRegistry): FskRuntimeConfig {
        val appInfo = try {
            context.packageManager.getApplicationInfo(
                context.packageName,
                android.content.pm.PackageManager.GET_META_DATA,
            )
        } catch (_: Exception) {
            null
        }
        val metaData = appInfo?.metaData

        val buildUseLive = BuildConfig.USE_LIVE_FSK_SDK
        val metaUseLive = toBooleanOrNull(metaData?.get("onyx.use_live_fsk_sdk"))
        val (useLiveMode, useLiveModeSource) = if (metaUseLive != null) {
            metaUseLive to "manifest_meta_data"
        } else {
            buildUseLive to "build_config"
        }

        val buildAction = BuildConfig.FSK_SDK_HEARTBEAT_ACTION.trim().ifEmpty {
            "com.onyx.fsk.SDK_HEARTBEAT"
        }
        val metaAction = toTrimmedStringOrNull(metaData?.get("onyx.fsk_sdk_heartbeat_action"))
        val (heartbeatAction, heartbeatActionSource) = if (metaAction != null) {
            metaAction to "manifest_meta_data"
        } else {
            buildAction to "build_config"
        }

        val availableAdapters = adapterRegistry.availableAdapterIds().toSet()
        val buildAdapterRaw = BuildConfig.FSK_SDK_PAYLOAD_ADAPTER.trim().lowercase()
        val buildAdapter = if (availableAdapters.contains(buildAdapterRaw)) {
            buildAdapterRaw
        } else {
            "standard"
        }
        val metaAdapterRaw = toTrimmedStringOrNull(metaData?.get("onyx.fsk_sdk_payload_adapter"))
            ?.lowercase()
        val (payloadAdapterId, payloadAdapterSource) = if (metaAdapterRaw != null &&
            availableAdapters.contains(metaAdapterRaw)
        ) {
            metaAdapterRaw to "manifest_meta_data"
        } else {
            buildAdapter to "build_config"
        }

        val buildConnectorClassName = BuildConfig.FSK_SDK_CONNECTOR_CLASS.trim()
        val metaConnectorClassName = toTrimmedStringOrNull(
            metaData?.get("onyx.fsk_sdk_connector_class"),
        )
        val defaultConnectorClassName = if (useLiveMode) {
            FskReflectiveVendorSdkConnector::class.java.name
        } else {
            null
        }
        val (connectorClassName, connectorClassSource) = if (metaConnectorClassName != null) {
            metaConnectorClassName to "manifest_meta_data"
        } else if (buildConnectorClassName.isNotEmpty()) {
            buildConnectorClassName to "build_config"
        } else if (defaultConnectorClassName != null) {
            defaultConnectorClassName to "platform_builtin_default"
        } else {
            null to null
        }

        return FskRuntimeConfig(
            useLiveMode = useLiveMode,
            useLiveModeSource = useLiveModeSource,
            heartbeatAction = heartbeatAction,
            heartbeatActionSource = heartbeatActionSource,
            payloadAdapterId = payloadAdapterId,
            payloadAdapterSource = payloadAdapterSource,
            connectorClassName = connectorClassName,
            connectorClassSource = connectorClassSource,
        )
    }
}

class HikvisionRuntimeConfigResolver(private val context: Context) {
    fun resolve(adapterRegistry: FskPayloadAdapterRegistry): FskRuntimeConfig {
        val appInfo = try {
            context.packageManager.getApplicationInfo(
                context.packageName,
                android.content.pm.PackageManager.GET_META_DATA,
            )
        } catch (_: Exception) {
            null
        }
        val metaData = appInfo?.metaData

        val buildUseLive = BuildConfig.USE_LIVE_HIKVISION_SDK
        val metaUseLive = toBooleanOrNull(metaData?.get("onyx.use_live_hikvision_sdk"))
        val (useLiveMode, useLiveModeSource) = if (metaUseLive != null) {
            metaUseLive to "manifest_meta_data"
        } else {
            buildUseLive to "build_config"
        }

        val buildAction = BuildConfig.HIKVISION_SDK_HEARTBEAT_ACTION.trim().ifEmpty {
            "com.onyx.hikvision.SDK_HEARTBEAT"
        }
        val metaAction = toTrimmedStringOrNull(
            metaData?.get("onyx.hikvision_sdk_heartbeat_action"),
        )
        val (heartbeatAction, heartbeatActionSource) = if (metaAction != null) {
            metaAction to "manifest_meta_data"
        } else {
            buildAction to "build_config"
        }

        val availableAdapters = adapterRegistry.availableAdapterIds().toSet()
        val buildAdapterRaw = BuildConfig.HIKVISION_SDK_PAYLOAD_ADAPTER.trim().lowercase()
        val buildAdapter = if (availableAdapters.contains(buildAdapterRaw)) {
            buildAdapterRaw
        } else {
            "hikvision_guardlink"
        }
        val metaAdapterRaw = toTrimmedStringOrNull(
            metaData?.get("onyx.hikvision_sdk_payload_adapter"),
        )?.lowercase()
        val (payloadAdapterId, payloadAdapterSource) = if (metaAdapterRaw != null &&
            availableAdapters.contains(metaAdapterRaw)
        ) {
            metaAdapterRaw to "manifest_meta_data"
        } else {
            buildAdapter to "build_config"
        }

        val buildConnectorClassName = BuildConfig.HIKVISION_SDK_CONNECTOR_CLASS.trim()
        val metaConnectorClassName = toTrimmedStringOrNull(
            metaData?.get("onyx.hikvision_sdk_connector_class"),
        )
        val defaultConnectorClassName = if (useLiveMode) {
            HikvisionReflectiveVendorSdkConnector::class.java.name
        } else {
            null
        }
        val (connectorClassName, connectorClassSource) = if (metaConnectorClassName != null) {
            metaConnectorClassName to "manifest_meta_data"
        } else if (buildConnectorClassName.isNotEmpty()) {
            buildConnectorClassName to "build_config"
        } else if (defaultConnectorClassName != null) {
            defaultConnectorClassName to "platform_builtin_default"
        } else {
            null to null
        }

        return FskRuntimeConfig(
            useLiveMode = useLiveMode,
            useLiveModeSource = useLiveModeSource,
            heartbeatAction = heartbeatAction,
            heartbeatActionSource = heartbeatActionSource,
            payloadAdapterId = payloadAdapterId,
            payloadAdapterSource = payloadAdapterSource,
            connectorClassName = connectorClassName,
            connectorClassSource = connectorClassSource,
        )
    }
}

class FskHeartbeatStore(
    private val preferences: SharedPreferences,
) {
    companion object {
        private const val KEY_WEARABLE_PAYLOAD_JSON = "wearable_payload_json"
        private const val KEY_WEARABLE_HEART_RATE = "wearable_heart_rate"
        private const val KEY_WEARABLE_MOVEMENT_LEVEL = "wearable_movement_level"
        private const val KEY_WEARABLE_ACTIVITY_STATE = "wearable_activity_state"
        private const val KEY_WEARABLE_BATTERY_PERCENT = "wearable_battery_percent"
        private const val KEY_WEARABLE_CAPTURED_AT_UTC = "wearable_captured_at_utc"
        private const val KEY_LAST_GPS_ACCURACY_METERS = "last_gps_accuracy_meters"
    }

    fun saveHeartbeat(payload: Map<String, Any?>) {
        val json = JSONObject(payload).toString()
        val editor = preferences.edit()
        editor.putString(KEY_WEARABLE_PAYLOAD_JSON, json)

        toIntOrNull(payload["heart_rate"])?.let {
            editor.putInt(KEY_WEARABLE_HEART_RATE, it)
        }
        toDoubleOrNull(payload["movement_level"])?.let {
            editor.putFloat(KEY_WEARABLE_MOVEMENT_LEVEL, it.toFloat())
        }
        toTrimmedStringOrNull(payload["activity_state"])?.let {
            editor.putString(KEY_WEARABLE_ACTIVITY_STATE, it)
        }
        toIntOrNull(payload["battery_percent"])?.let {
            editor.putInt(KEY_WEARABLE_BATTERY_PERCENT, it)
        }
        toTrimmedStringOrNull(payload["captured_at_utc"])?.let {
            editor.putString(KEY_WEARABLE_CAPTURED_AT_UTC, it)
        }
        toDoubleOrNull(payload["gps_accuracy_meters"])?.let {
            editor.putFloat(KEY_LAST_GPS_ACCURACY_METERS, it.toFloat())
        }
        editor.apply()
    }

    fun latestWearablePayload(): MutableMap<String, Any?>? {
        val payloadJson = preferences.getString(KEY_WEARABLE_PAYLOAD_JSON, null)
        if (!payloadJson.isNullOrBlank()) {
            return try {
                val json = JSONObject(payloadJson)
                val map = mutableMapOf<String, Any?>()
                val iterator = json.keys()
                while (iterator.hasNext()) {
                    val key = iterator.next()
                    map[key] = json.get(key)
                }
                map
            } catch (_: Exception) {
                null
            }
        }

        if (!preferences.contains(KEY_WEARABLE_HEART_RATE) ||
            !preferences.contains(KEY_WEARABLE_MOVEMENT_LEVEL) ||
            !preferences.contains(KEY_WEARABLE_ACTIVITY_STATE) ||
            !preferences.contains(KEY_WEARABLE_CAPTURED_AT_UTC)
        ) {
            return null
        }

        return mutableMapOf<String, Any?>(
            "heart_rate" to preferences.getInt(KEY_WEARABLE_HEART_RATE, 0),
            "movement_level" to preferences.getFloat(KEY_WEARABLE_MOVEMENT_LEVEL, 0f).toDouble(),
            "activity_state" to preferences.getString(KEY_WEARABLE_ACTIVITY_STATE, "unknown").orEmpty(),
            "captured_at_utc" to preferences.getString(KEY_WEARABLE_CAPTURED_AT_UTC, nowUtcIso()).orEmpty(),
        ).apply {
            if (preferences.contains(KEY_WEARABLE_BATTERY_PERCENT)) {
                this["battery_percent"] = preferences.getInt(KEY_WEARABLE_BATTERY_PERCENT, 0)
            }
            if (preferences.contains(KEY_LAST_GPS_ACCURACY_METERS)) {
                this["gps_accuracy_meters"] =
                    preferences.getFloat(KEY_LAST_GPS_ACCURACY_METERS, 0f).toDouble()
            }
        }
    }

    fun lastGpsAccuracyMeters(): Double? {
        if (!preferences.contains(KEY_LAST_GPS_ACCURACY_METERS)) {
            return null
        }
        return preferences.getFloat(KEY_LAST_GPS_ACCURACY_METERS, 0f).toDouble()
    }
}

class FskSdkBridgeReceiver(
    private val store: FskHeartbeatStore,
    private val adapterRegistry: FskPayloadAdapterRegistry,
    private val defaultAdapterId: String,
) {
    var callbackCount: Int = 0
        private set
    var lastCallbackAtUtc: String? = null
        private set
    var lastCallbackMessage: String? = null
        private set
    var callbackErrorCount: Int = 0
        private set
    var lastCallbackErrorAtUtc: String? = null
        private set
    var lastCallbackErrorMessage: String? = null
        private set

    fun ingestHeartbeatFromSdk(
        providerId: String,
        payload: Map<String, Any?>,
        requestedAdapterId: String?,
        sdkStatus: String,
        source: String,
    ): Map<String, Any?> {
        val adapterInput = requestedAdapterId?.trim()?.ifEmpty { null } ?: defaultAdapterId
        val (adapter, requestedOverride) = adapterRegistry.resolve(adapterInput)

        Log.i(
            ONYX_TELEMETRY_TAG,
            "facade_ingest adapter=${adapter.id} payloadKeys=${mapPayloadKeys(payload)}",
        )

        val validation = adapter.normalize(payload)
        if (!validation.accepted || validation.normalized == null) {
            callbackErrorCount += 1
            val atUtc = nowUtcIso()
            lastCallbackErrorAtUtc = atUtc
            lastCallbackErrorMessage = validation.message
            Log.e(
                ONYX_TELEMETRY_TAG,
                "sdk_callback_error adapter=${adapter.id} error=${validation.message}",
            )
            return mapOf(
                "provider_id" to providerId,
                "accepted" to false,
                "captured_at_utc" to atUtc,
                "adapter_requested" to (requestedOverride ?: adapter.id),
                "adapter_resolved" to adapter.id,
                "available_fsk_payload_adapters" to adapterRegistry.availableAdapterIds(),
                "message" to validation.message,
            )
        }

        val normalizedMap = validation.normalized.toMap(
            providerId = providerId,
            sdkStatus = sdkStatus,
            source = source,
        )
        store.saveHeartbeat(normalizedMap)

        callbackCount += 1
        val callbackAtUtc = validation.normalized.capturedAtUtc
        lastCallbackAtUtc = callbackAtUtc
        lastCallbackMessage = validation.message

        Log.i(
            ONYX_TELEMETRY_TAG,
            "sdk_callback_received adapter=${adapter.id} callback_count=$callbackCount captured_at_utc=$callbackAtUtc",
        )

        return mapOf(
            "provider_id" to providerId,
            "accepted" to true,
            "captured_at_utc" to callbackAtUtc,
            "adapter_requested" to (requestedOverride ?: adapter.id),
            "adapter_resolved" to adapter.id,
            "available_fsk_payload_adapters" to adapterRegistry.availableAdapterIds(),
            "message" to "Wearable heartbeat bridge payload ingested.",
        )
    }
}

interface TelemetrySdkFacade {
    val facadeId: String
    val liveMode: Boolean
    val toggleSource: String
    val runtimeMode: String
    val heartbeatAction: String
    val heartbeatSource: String
    val heartbeatActionSource: String
    val payloadAdapterId: String
    val payloadAdapterSource: String
    val availablePayloadAdapters: List<String>
    val vendorConnectorId: String?
    val vendorConnectorSource: String?
    val vendorConnectorErrorMessage: String?
    val vendorConnectorFallbackActive: Boolean
    val callbackCount: Int
    val lastCallbackAtUtc: String?
    val lastCallbackMessage: String?
    val callbackErrorCount: Int
    val lastCallbackErrorAtUtc: String?
    val lastCallbackErrorMessage: String?
    val sourceActive: Boolean

    fun start()
    fun stop()
}

class FskSdkFacadeStub(
    private val bridgeReceiver: FskSdkBridgeReceiver,
    private val runtimeConfig: FskRuntimeConfig,
    private val adapterRegistry: FskPayloadAdapterRegistry,
    private val facadeIdValue: String = "fsk_sdk_facade_stub",
) : TelemetrySdkFacade {
    override val facadeId: String = facadeIdValue
    override val liveMode: Boolean = false
    override val toggleSource: String = runtimeConfig.useLiveModeSource
    override val runtimeMode: String = "stub"
    override val heartbeatAction: String = runtimeConfig.heartbeatAction
    override val heartbeatSource: String = "stub"
    override val heartbeatActionSource: String = runtimeConfig.heartbeatActionSource
    override val payloadAdapterId: String = runtimeConfig.payloadAdapterId
    override val payloadAdapterSource: String = runtimeConfig.payloadAdapterSource
    override val availablePayloadAdapters: List<String> = adapterRegistry.availableAdapterIds()
    override val vendorConnectorId: String? = null
    override val vendorConnectorSource: String? = null
    override val vendorConnectorErrorMessage: String? = null
    override val vendorConnectorFallbackActive: Boolean = false
    override val callbackCount: Int
        get() = bridgeReceiver.callbackCount
    override val lastCallbackAtUtc: String?
        get() = bridgeReceiver.lastCallbackAtUtc
    override val lastCallbackMessage: String?
        get() = bridgeReceiver.lastCallbackMessage
    override val callbackErrorCount: Int
        get() = bridgeReceiver.callbackErrorCount
    override val lastCallbackErrorAtUtc: String?
        get() = bridgeReceiver.lastCallbackErrorAtUtc
    override val lastCallbackErrorMessage: String?
        get() = bridgeReceiver.lastCallbackErrorMessage
    override val sourceActive: Boolean = false

    override fun start() {
        // Stub facade has no native receiver.
    }

    override fun stop() {
        // Stub facade has no native receiver.
    }
}

class FskSdkFacadeLive(
    private val context: Context,
    private val providerId: String,
    private val bridgeReceiver: FskSdkBridgeReceiver,
    private val runtimeConfig: FskRuntimeConfig,
    private val adapterRegistry: FskPayloadAdapterRegistry,
    private val vendorConnector: FskVendorSdkConnector,
    private val vendorConnectorLoadErrorMessage: String?,
    private val facadeIdValue: String = "fsk_sdk_facade_live",
    private val callbackSource: String = "fsk_sdk_live_callback",
    private val logPrefix: String = "fsk",
) : TelemetrySdkFacade {
    override val facadeId: String = facadeIdValue
    override val liveMode: Boolean = true
    override val toggleSource: String = runtimeConfig.useLiveModeSource
    override val runtimeMode: String = "live"
    override val heartbeatAction: String = runtimeConfig.heartbeatAction
    override val heartbeatSource: String = vendorConnector.heartbeatSource
    override val heartbeatActionSource: String = runtimeConfig.heartbeatActionSource
    override val payloadAdapterId: String = runtimeConfig.payloadAdapterId
    override val payloadAdapterSource: String = runtimeConfig.payloadAdapterSource
    override val availablePayloadAdapters: List<String> = adapterRegistry.availableAdapterIds()
    override val vendorConnectorId: String = vendorConnector.connectorId
    override val vendorConnectorSource: String = vendorConnector.connectorSource
    override val vendorConnectorErrorMessage: String? = vendorConnectorLoadErrorMessage
    override val vendorConnectorFallbackActive: Boolean
        get() = !vendorConnectorLoadErrorMessage.isNullOrBlank() ||
            heartbeatSource.contains("fallback", ignoreCase = true)
    override val callbackCount: Int
        get() = bridgeReceiver.callbackCount
    override val lastCallbackAtUtc: String?
        get() = bridgeReceiver.lastCallbackAtUtc
    override val lastCallbackMessage: String?
        get() = bridgeReceiver.lastCallbackMessage
    override val callbackErrorCount: Int
        get() = bridgeReceiver.callbackErrorCount
    override val lastCallbackErrorAtUtc: String?
        get() = bridgeReceiver.lastCallbackErrorAtUtc
    override val lastCallbackErrorMessage: String?
        get() = bridgeReceiver.lastCallbackErrorMessage

    override val sourceActive: Boolean
        get() = vendorConnector.isActive

    override fun start() {
        vendorConnector.start(context, heartbeatAction) { payload ->
            val requestedAdapterId = toTrimmedStringOrNull(payload["payload_adapter"])
                ?: toTrimmedStringOrNull(payload["payloadAdapter"])
                ?: toTrimmedStringOrNull(payload["adapter_id"])
                ?: toTrimmedStringOrNull(payload["adapterId"])
            bridgeReceiver.ingestHeartbeatFromSdk(
                providerId = providerId,
                payload = payload,
                requestedAdapterId = requestedAdapterId,
                sdkStatus = "live",
                source = callbackSource,
            )
        }
        Log.i(
            ONYX_TELEMETRY_TAG,
            "${logPrefix}_live_facade_started action=$heartbeatAction connector=${vendorConnector.connectorId} connector_source=${vendorConnector.connectorSource} heartbeat_source=$heartbeatSource fallback_active=$vendorConnectorFallbackActive",
        )
    }

    override fun stop() {
        vendorConnector.stop()
    }
}

class DeviceHealthSampler(
    private val context: Context,
    private val store: FskHeartbeatStore,
) {
    fun capture(providerId: String, sdkStatus: String, source: String): Map<String, Any?> {
        val batteryIntent = context.registerReceiver(
            null,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED),
        )
        val batteryLevel = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val batteryScale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPercent = if (batteryLevel >= 0 && batteryScale > 0) {
            ((batteryLevel.toDouble() / batteryScale.toDouble()) * 100.0).toInt().coerceIn(0, 100)
        } else {
            0
        }

        val batteryTempRaw = batteryIntent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1) ?: -1
        val deviceTemperatureC = if (batteryTempRaw > 0) {
            batteryTempRaw.toDouble() / 10.0
        } else {
            0.0
        }

        val statFs = StatFs(context.filesDir.absolutePath)
        val storageAvailableMb =
            ((statFs.availableBytes / 1024.0 / 1024.0).toInt()).coerceAtLeast(0)

        val networkState = resolveNetworkState()
        val gpsAccuracyMeters = store.lastGpsAccuracyMeters() ?: 5.0

        return mapOf(
            "battery_percent" to batteryPercent,
            "gps_accuracy_meters" to gpsAccuracyMeters,
            "storage_available_mb" to storageAvailableMb,
            "network_state" to networkState,
            "device_temperature_c" to deviceTemperatureC,
            "captured_at_utc" to nowUtcIso(),
            "source" to source,
            "provider_id" to providerId,
            "sdk_status" to sdkStatus,
        )
    }

    private fun resolveNetworkState(): String {
        val connectivity =
            context.getSystemService(Context.CONNECTIVITY_SERVICE) as? android.net.ConnectivityManager
                ?: return "unknown"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val activeNetwork = connectivity.activeNetwork ?: return "offline"
            val capabilities = connectivity.getNetworkCapabilities(activeNetwork) ?: return "offline"
            return when {
                capabilities.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                capabilities.hasTransport(android.net.NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                capabilities.hasTransport(android.net.NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                else -> "unknown"
            }
        }

        @Suppress("DEPRECATION")
        val networkInfo = connectivity.activeNetworkInfo
        @Suppress("DEPRECATION")
        return when {
            networkInfo == null || !networkInfo.isConnected -> "offline"
            networkInfo.type == android.net.ConnectivityManager.TYPE_WIFI -> "wifi"
            networkInfo.type == android.net.ConnectivityManager.TYPE_MOBILE -> "cellular"
            else -> "unknown"
        }
    }
}

interface TelemetryProvider {
    val id: String
    fun status(): Map<String, Any?>
    fun captureWearableHeartbeat(): Map<String, Any?>
    fun captureDeviceHealth(): Map<String, Any?>
}

class StubTelemetryProvider(
    override val id: String,
    private val random: Random = Random(),
) : TelemetryProvider {
    override fun status(): Map<String, Any?> = mapOf(
        "provider_id" to id,
        "readiness" to "degraded",
        "message" to "Native provider is running in stub mode.",
        "sdk_status" to "stub",
    )

    override fun captureWearableHeartbeat(): Map<String, Any?> {
        return mapOf(
            "heart_rate" to (68 + random.nextInt(20)),
            "movement_level" to (0.15 + random.nextDouble() * 0.95),
            "activity_state" to if (random.nextBoolean()) "patrolling" else "stationary",
            "battery_percent" to (45 + random.nextInt(50)),
            "captured_at_utc" to nowUtcIso(),
            "source" to id,
            "provider_id" to id,
            "sdk_status" to "stub",
        )
    }

    override fun captureDeviceHealth(): Map<String, Any?> {
        return mapOf(
            "battery_percent" to (40 + random.nextInt(60)),
            "gps_accuracy_meters" to (3.0 + random.nextDouble() * 6.0),
            "storage_available_mb" to (1024 + random.nextInt(4096)),
            "network_state" to "wifi",
            "device_temperature_c" to (31.0 + random.nextDouble() * 5.0),
            "captured_at_utc" to nowUtcIso(),
            "source" to id,
            "provider_id" to id,
            "sdk_status" to "stub",
        )
    }
}

class FskTelemetryProvider(
    override val id: String,
    private val facade: TelemetrySdkFacade,
    private val store: FskHeartbeatStore,
    private val deviceHealthSampler: DeviceHealthSampler,
    private val random: Random = Random(),
) : TelemetryProvider {
    override fun status(): Map<String, Any?> {
        val fallbackActive = facade.vendorConnectorFallbackActive ||
            facade.heartbeatSource.contains("fallback", ignoreCase = true)
        val readiness = when {
            facade.liveMode && !fallbackActive -> "ready"
            else -> "degraded"
        }
        val message = when {
            facade.liveMode && !fallbackActive -> "Native provider connected."
            facade.liveMode && fallbackActive ->
                "Native provider connected with connector fallback active."
            else -> "Native provider is running in stub mode."
        }
        val sdkStatus = when {
            facade.liveMode && !fallbackActive -> "live"
            facade.liveMode && fallbackActive -> "degraded"
            else -> "stub"
        }

        return mapOf(
            "provider_id" to id,
            "readiness" to readiness,
            "message" to message,
            "sdk_status" to sdkStatus,
            "facade_id" to facade.facadeId,
            "facade_live_mode" to facade.liveMode,
            "facade_toggle_source" to facade.toggleSource,
            "facade_runtime_mode" to facade.runtimeMode,
            "facade_heartbeat_source" to facade.heartbeatSource,
            "facade_heartbeat_action" to facade.heartbeatAction,
            "facade_source_active" to facade.sourceActive,
            "facade_callback_count" to facade.callbackCount,
            "facade_last_callback_at_utc" to facade.lastCallbackAtUtc,
            "facade_last_callback_message" to facade.lastCallbackMessage,
            "facade_callback_error_count" to facade.callbackErrorCount,
            "facade_last_callback_error_at_utc" to facade.lastCallbackErrorAtUtc,
            "facade_last_callback_error_message" to facade.lastCallbackErrorMessage,
            "fsk_vendor_connector" to facade.vendorConnectorId,
            "fsk_vendor_connector_source" to facade.vendorConnectorSource,
            "fsk_vendor_connector_error" to facade.vendorConnectorErrorMessage,
            "fsk_vendor_connector_fallback_active" to fallbackActive,
            "fsk_heartbeat_action" to facade.heartbeatAction,
            "fsk_heartbeat_action_source" to facade.heartbeatActionSource,
            "fsk_payload_adapter" to facade.payloadAdapterId,
            "fsk_payload_adapter_source" to facade.payloadAdapterSource,
            "available_fsk_payload_adapters" to facade.availablePayloadAdapters,
        )
    }

    override fun captureWearableHeartbeat(): Map<String, Any?> {
        val cached = store.latestWearablePayload()
        if (cached != null) {
            val mutable = cached.toMutableMap()
            mutable["source"] = toTrimmedStringOrNull(mutable["source"]) ?: id
            mutable["provider_id"] = id
            mutable["sdk_status"] = if (facade.liveMode) "live" else "stub"
            return mutable
        }

        val sdkStatus = if (facade.liveMode) "degraded" else "stub"
        return mapOf(
            "heart_rate" to (72 + random.nextInt(18)),
            "movement_level" to (0.10 + random.nextDouble() * 0.70),
            "activity_state" to "patrolling",
            "battery_percent" to (55 + random.nextInt(35)),
            "captured_at_utc" to nowUtcIso(),
            "source" to "${id}_bridge_cache_miss",
            "provider_id" to id,
            "sdk_status" to sdkStatus,
        )
    }

    override fun captureDeviceHealth(): Map<String, Any?> =
        deviceHealthSampler.capture(
            providerId = id,
            sdkStatus = if (facade.liveMode) "live" else "stub",
            source = id,
        )
}
