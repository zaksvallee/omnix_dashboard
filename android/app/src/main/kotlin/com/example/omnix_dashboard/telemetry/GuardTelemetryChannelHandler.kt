package com.example.omnix_dashboard.telemetry

import android.content.Context
import android.content.Intent
import android.util.Log
import com.example.omnix_dashboard.BuildConfig
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class GuardTelemetryChannelHandler(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "onyx/guard_telemetry"
        private const val DEFAULT_PROVIDER_ID = "android_native_sdk_stub"
        private const val FSK_PROVIDER_ID = "fsk_sdk"
        private const val FSK_STUB_PROVIDER_ID = "fsk_sdk_stub"
        private const val HIKVISION_PROVIDER_ID = "hikvision_sdk"
        private const val HIKVISION_STUB_PROVIDER_ID = "hikvision_sdk_stub"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val adapterRegistry = FskPayloadAdapterRegistry()

    private val fskRuntimeConfig = FskRuntimeConfigResolver(context).resolve(adapterRegistry)
    private val fskStore = FskHeartbeatStore(
        context.getSharedPreferences("onyx_guard_telemetry", Context.MODE_PRIVATE),
    )
    private val fskBridgeReceiver = FskSdkBridgeReceiver(
        store = fskStore,
        adapterRegistry = adapterRegistry,
        defaultAdapterId = fskRuntimeConfig.payloadAdapterId,
    )
    private val fskVendorConnectorLoadResult = FskVendorSdkConnectorLoader.resolve(
        context = context,
        connectorClassName = fskRuntimeConfig.connectorClassName,
        connectorClassSource = fskRuntimeConfig.connectorClassSource,
    )
    private val fskStubFacade = FskSdkFacadeStub(
        bridgeReceiver = fskBridgeReceiver,
        runtimeConfig = fskRuntimeConfig,
        adapterRegistry = adapterRegistry,
    )
    private val fskLiveFacade = FskSdkFacadeLive(
        context = context.applicationContext,
        providerId = FSK_PROVIDER_ID,
        bridgeReceiver = fskBridgeReceiver,
        runtimeConfig = fskRuntimeConfig,
        adapterRegistry = adapterRegistry,
        vendorConnector = fskVendorConnectorLoadResult.connector,
        vendorConnectorLoadErrorMessage = fskVendorConnectorLoadResult.errorMessage,
    )
    private val activeFskFacade: TelemetrySdkFacade =
        if (fskRuntimeConfig.useLiveMode) fskLiveFacade else fskStubFacade
    private val fskDeviceHealthSampler = DeviceHealthSampler(context, fskStore)

    private val hikvisionRuntimeConfig = HikvisionRuntimeConfigResolver(context).resolve(adapterRegistry)
    private val hikvisionStore = FskHeartbeatStore(
        context.getSharedPreferences("onyx_guard_telemetry_hikvision", Context.MODE_PRIVATE),
    )
    private val hikvisionBridgeReceiver = FskSdkBridgeReceiver(
        store = hikvisionStore,
        adapterRegistry = adapterRegistry,
        defaultAdapterId = hikvisionRuntimeConfig.payloadAdapterId,
    )
    private val hikvisionVendorConnectorLoadResult = FskVendorSdkConnectorLoader.resolve(
        context = context,
        connectorClassName = hikvisionRuntimeConfig.connectorClassName,
        connectorClassSource = hikvisionRuntimeConfig.connectorClassSource,
    )
    private val hikvisionStubFacade = FskSdkFacadeStub(
        bridgeReceiver = hikvisionBridgeReceiver,
        runtimeConfig = hikvisionRuntimeConfig,
        adapterRegistry = adapterRegistry,
        facadeIdValue = "hikvision_sdk_facade_stub",
    )
    private val hikvisionLiveFacade = FskSdkFacadeLive(
        context = context.applicationContext,
        providerId = HIKVISION_PROVIDER_ID,
        bridgeReceiver = hikvisionBridgeReceiver,
        runtimeConfig = hikvisionRuntimeConfig,
        adapterRegistry = adapterRegistry,
        vendorConnector = hikvisionVendorConnectorLoadResult.connector,
        vendorConnectorLoadErrorMessage = hikvisionVendorConnectorLoadResult.errorMessage,
        facadeIdValue = "hikvision_sdk_facade_live",
        callbackSource = "hikvision_sdk_live_callback",
        logPrefix = "hikvision",
    )
    private val activeHikvisionFacade: TelemetrySdkFacade =
        if (hikvisionRuntimeConfig.useLiveMode) hikvisionLiveFacade else hikvisionStubFacade
    private val hikvisionDeviceHealthSampler = DeviceHealthSampler(context, hikvisionStore)

    private val providers: Map<String, TelemetryProvider> = mapOf(
        "android_native_sdk_stub" to StubTelemetryProvider(id = "android_native_sdk_stub"),
        FSK_STUB_PROVIDER_ID to FskTelemetryProvider(
            id = FSK_STUB_PROVIDER_ID,
            facade = fskStubFacade,
            store = fskStore,
            deviceHealthSampler = fskDeviceHealthSampler,
        ),
        FSK_PROVIDER_ID to FskTelemetryProvider(
            id = FSK_PROVIDER_ID,
            facade = activeFskFacade,
            store = fskStore,
            deviceHealthSampler = fskDeviceHealthSampler,
        ),
        HIKVISION_STUB_PROVIDER_ID to FskTelemetryProvider(
            id = HIKVISION_STUB_PROVIDER_ID,
            facade = hikvisionStubFacade,
            store = hikvisionStore,
            deviceHealthSampler = hikvisionDeviceHealthSampler,
        ),
        HIKVISION_PROVIDER_ID to FskTelemetryProvider(
            id = HIKVISION_PROVIDER_ID,
            facade = activeHikvisionFacade,
            store = hikvisionStore,
            deviceHealthSampler = hikvisionDeviceHealthSampler,
        ),
    )

    init {
        channel.setMethodCallHandler(this)
        activeFskFacade.start()
        activeHikvisionFacade.start()
    }

    fun dispose() {
        activeFskFacade.stop()
        activeHikvisionFacade.stop()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = asStringMap(call.arguments)
        when (call.method) {
            "getTelemetryProviderStatus" -> {
                result.success(getTelemetryProviderStatus(readProviderId(args)))
            }
            "listTelemetryProviders" -> {
                result.success(listTelemetryProviders(readProviderId(args)))
            }
            "captureWearableHeartbeat" -> {
                val providerId = readProviderId(args)
                val provider = providers[providerId]
                if (provider == null) {
                    result.error(
                        "unknown_provider",
                        "No telemetry provider registered for $providerId.",
                        listTelemetryProviders(providerId),
                    )
                } else {
                    result.success(provider.captureWearableHeartbeat())
                }
            }
            "captureDeviceHealth" -> {
                val providerId = readProviderId(args)
                val provider = providers[providerId]
                if (provider == null) {
                    result.error(
                        "unknown_provider",
                        "No telemetry provider registered for $providerId.",
                        listTelemetryProviders(providerId),
                    )
                } else {
                    result.success(provider.captureDeviceHealth())
                }
            }
            "ingestWearableHeartbeatBridge" -> {
                val providerId = readProviderId(args)
                val facade = facadeForProvider(providerId)
                val bridgeReceiver = bridgeReceiverForProvider(providerId)
                val response = bridgeReceiver.ingestHeartbeatFromSdk(
                    providerId = providerId,
                    payload = args,
                    requestedAdapterId =
                        toTrimmedStringOrNull(args["payload_adapter"])
                            ?: toTrimmedStringOrNull(args["payloadAdapter"])
                            ?: toTrimmedStringOrNull(args["adapter_id"])
                            ?: toTrimmedStringOrNull(args["adapterId"]),
                    sdkStatus = toTrimmedStringOrNull(args["sdk_status"])
                        ?: if (facade?.liveMode == true) "live" else "stub",
                    source = toTrimmedStringOrNull(args["source"]) ?: "onyx_guard_bridge_seed",
                )
                result.success(response)
            }
            "ingestFskSdkHeartbeat" -> {
                val providerId = readProviderId(args, defaultValue = FSK_PROVIDER_ID)
                result.success(
                    ingestSdkHeartbeat(
                        providerId = providerId,
                        payload = args,
                        source = "fsk_sdk_callback_api",
                        logMethodName = "ingestFskSdkHeartbeat",
                    ),
                )
            }
            "ingestHikvisionSdkHeartbeat" -> {
                val providerId = readProviderId(args, defaultValue = HIKVISION_PROVIDER_ID)
                result.success(
                    ingestSdkHeartbeat(
                        providerId = providerId,
                        payload = args,
                        source = "hikvision_sdk_callback_api",
                        logMethodName = "ingestHikvisionSdkHeartbeat",
                    ),
                )
            }
            "emitDebugFskSdkHeartbeatBroadcast" -> {
                val providerId = readProviderId(args, defaultValue = FSK_PROVIDER_ID)
                result.success(emitDebugSdkHeartbeatBroadcast(providerId, args))
            }
            "emitDebugHikvisionSdkHeartbeatBroadcast" -> {
                val providerId = readProviderId(args, defaultValue = HIKVISION_PROVIDER_ID)
                result.success(emitDebugSdkHeartbeatBroadcast(providerId, args))
            }
            "validateFskPayloadMapping" -> {
                val providerId = readProviderId(args, defaultValue = FSK_PROVIDER_ID)
                result.success(validatePayloadMapping(providerId, args))
            }
            "validateHikvisionPayloadMapping" -> {
                val providerId = readProviderId(args, defaultValue = HIKVISION_PROVIDER_ID)
                result.success(validatePayloadMapping(providerId, args))
            }
            else -> result.notImplemented()
        }
    }

    private fun ingestSdkHeartbeat(
        providerId: String,
        payload: Map<String, Any?>,
        source: String,
        logMethodName: String,
    ): Map<String, Any?> {
        if (!providers.containsKey(providerId)) {
            return mapOf(
                "provider_id" to providerId,
                "accepted" to false,
                "captured_at_utc" to nowUtcIso(),
                "message" to "No telemetry provider registered for $providerId.",
            )
        }
        val facade = facadeForProvider(providerId)
        val bridgeReceiver = bridgeReceiverForProvider(providerId)
        Log.i(
            ONYX_TELEMETRY_TAG,
            "$logMethodName requested provider=$providerId payloadKeys=${mapPayloadKeys(payload)}",
        )
        val response = bridgeReceiver.ingestHeartbeatFromSdk(
            providerId = providerId,
            payload = payload,
            requestedAdapterId =
                toTrimmedStringOrNull(payload["payload_adapter"])
                    ?: toTrimmedStringOrNull(payload["payloadAdapter"])
                    ?: toTrimmedStringOrNull(payload["adapter_id"])
                    ?: toTrimmedStringOrNull(payload["adapterId"]),
            sdkStatus = if (facade?.liveMode == true) "live" else "stub",
            source = source,
        )
        Log.i(
            ONYX_TELEMETRY_TAG,
            "$logMethodName result accepted=${response["accepted"]} captured_at_utc=${response["captured_at_utc"]} message=${response["message"]}",
        )
        return response
    }

    private fun emitDebugSdkHeartbeatBroadcast(
        providerId: String,
        payload: Map<String, Any?>,
    ): Map<String, Any?> {
        if (!providers.containsKey(providerId)) {
            return mapOf(
                "provider_id" to providerId,
                "accepted" to false,
                "captured_at_utc" to nowUtcIso(),
                "action" to "",
                "message" to "No telemetry provider registered for $providerId.",
            )
        }
        val facade = facadeForProvider(providerId)
        val action = facade?.heartbeatAction ?: ""
        if (action.isBlank()) {
            return mapOf(
                "provider_id" to providerId,
                "accepted" to false,
                "captured_at_utc" to nowUtcIso(),
                "action" to action,
                "message" to "No heartbeat action configured for $providerId.",
            )
        }
        if (!BuildConfig.DEBUG) {
            return mapOf(
                "provider_id" to providerId,
                "accepted" to false,
                "captured_at_utc" to nowUtcIso(),
                "action" to action,
                "message" to "Debug heartbeat broadcast is available only in debug builds.",
            )
        }

        val intentPayload = mutableMapOf<String, Any?>().apply {
            putAll(payload)
            put("provider_id", providerId)
            putIfAbsent("captured_at_utc", nowUtcIso())
        }
        val intent = Intent(action)
        for ((key, value) in intentPayload) {
            when (value) {
                null -> Unit
                is Int -> intent.putExtra(key, value)
                is Long -> intent.putExtra(key, value)
                is Float -> intent.putExtra(key, value)
                is Double -> intent.putExtra(key, value)
                is Boolean -> intent.putExtra(key, value)
                is String -> intent.putExtra(key, value)
                else -> intent.putExtra(key, value.toString())
            }
        }
        context.sendBroadcast(intent)
        return mapOf(
            "provider_id" to providerId,
            "accepted" to true,
            "captured_at_utc" to intentPayload["captured_at_utc"],
            "action" to action,
            "message" to "Debug SDK heartbeat broadcast emitted.",
        )
    }

    private fun validatePayloadMapping(
        providerId: String,
        args: Map<String, Any?>,
    ): Map<String, Any?> {
        if (!providers.containsKey(providerId)) {
            return mapOf(
                "accepted" to false,
                "message" to "No telemetry provider registered for $providerId.",
                "provider_id" to providerId,
                "available_fsk_payload_adapters" to adapterRegistry.availableAdapterIds(),
            )
        }
        val rawPayload = asStringMap(args["payload"])
        val requestedAdapter = toTrimmedStringOrNull(args["payload_adapter"])
            ?: toTrimmedStringOrNull(args["payloadAdapter"])
            ?: toTrimmedStringOrNull(args["adapter_id"])
            ?: toTrimmedStringOrNull(args["adapterId"])

        val facade = facadeForProvider(providerId)
        val adapterInput = requestedAdapter ?: facade?.payloadAdapterId ?: "standard"
        val (adapter, resolvedRequested) = adapterRegistry.resolve(adapterInput)
        val validation = adapter.normalize(rawPayload)

        val response = mutableMapOf<String, Any?>(
            "accepted" to validation.accepted,
            "message" to validation.message,
            "adapter_requested" to (requestedAdapter ?: (facade?.payloadAdapterId ?: "standard")),
            "adapter_resolved" to adapter.id,
            "available_fsk_payload_adapters" to adapterRegistry.availableAdapterIds(),
            "provider_id" to providerId,
        )
        if (resolvedRequested != null && resolvedRequested != adapter.id) {
            response["message"] =
                "${validation.message} Unknown adapter '$resolvedRequested' was ignored."
        }
        if (validation.accepted && validation.normalized != null) {
            response["normalized_payload"] = mapOf(
                "heart_rate" to validation.normalized.heartRate,
                "movement_level" to validation.normalized.movementLevel,
                "activity_state" to validation.normalized.activityState,
                "captured_at_utc" to validation.normalized.capturedAtUtc,
            )
        }
        return response
    }

    private fun getTelemetryProviderStatus(providerId: String): Map<String, Any?> {
        val provider = providers[providerId]
        if (provider == null) {
            return mapOf(
                "provider_id" to providerId,
                "readiness" to "error",
                "message" to "No telemetry provider registered for $providerId.",
                "sdk_status" to "error",
            )
        }
        return provider.status()
    }

    private fun listTelemetryProviders(requestedProviderId: String): Map<String, Any?> {
        val availableIds = providers.keys.sorted()
        val providerExists = providers.containsKey(requestedProviderId)
        val selectedFacade = facadeForProvider(requestedProviderId) ?: activeFskFacade

        return mutableMapOf<String, Any?>(
            "requested_provider_id" to requestedProviderId,
            "default_provider_id" to DEFAULT_PROVIDER_ID,
            "available_provider_ids" to availableIds,
            "provider_exists" to providerExists,
            "requested_provider_family" to providerFamily(requestedProviderId),
            "facade_id" to selectedFacade.facadeId,
            "facade_live_mode" to selectedFacade.liveMode,
            "facade_toggle_source" to selectedFacade.toggleSource,
            "fsk_heartbeat_action" to selectedFacade.heartbeatAction,
            "fsk_heartbeat_action_source" to selectedFacade.heartbeatActionSource,
            "fsk_payload_adapter" to selectedFacade.payloadAdapterId,
            "fsk_payload_adapter_source" to selectedFacade.payloadAdapterSource,
            "available_fsk_payload_adapters" to selectedFacade.availablePayloadAdapters,
            "fsk_vendor_connector" to selectedFacade.vendorConnectorId,
            "fsk_vendor_connector_source" to selectedFacade.vendorConnectorSource,
            "fsk_vendor_connector_error" to selectedFacade.vendorConnectorErrorMessage,
            "fsk_vendor_connector_fallback_active" to selectedFacade.vendorConnectorFallbackActive,
            "facade_callback_count" to selectedFacade.callbackCount,
            "facade_last_callback_at_utc" to selectedFacade.lastCallbackAtUtc,
            "facade_last_callback_message" to selectedFacade.lastCallbackMessage,
            "facade_callback_error_count" to selectedFacade.callbackErrorCount,
            "facade_last_callback_error_at_utc" to selectedFacade.lastCallbackErrorAtUtc,
            "facade_last_callback_error_message" to selectedFacade.lastCallbackErrorMessage,
            "fsk_provider_live_enabled" to fskRuntimeConfig.useLiveMode,
            "hikvision_provider_live_enabled" to hikvisionRuntimeConfig.useLiveMode,
            "hikvision_heartbeat_action" to activeHikvisionFacade.heartbeatAction,
            "hikvision_heartbeat_action_source" to activeHikvisionFacade.heartbeatActionSource,
            "hikvision_payload_adapter" to activeHikvisionFacade.payloadAdapterId,
            "hikvision_payload_adapter_source" to activeHikvisionFacade.payloadAdapterSource,
            "hikvision_vendor_connector" to activeHikvisionFacade.vendorConnectorId,
            "hikvision_vendor_connector_source" to activeHikvisionFacade.vendorConnectorSource,
            "hikvision_vendor_connector_error" to activeHikvisionFacade.vendorConnectorErrorMessage,
            "hikvision_vendor_connector_fallback_active" to
                activeHikvisionFacade.vendorConnectorFallbackActive,
        )
    }

    private fun facadeForProvider(providerId: String): TelemetrySdkFacade? {
        return when (providerId) {
            FSK_PROVIDER_ID -> activeFskFacade
            FSK_STUB_PROVIDER_ID -> fskStubFacade
            HIKVISION_PROVIDER_ID -> activeHikvisionFacade
            HIKVISION_STUB_PROVIDER_ID -> hikvisionStubFacade
            else -> null
        }
    }

    private fun bridgeReceiverForProvider(providerId: String): FskSdkBridgeReceiver {
        return when (providerId) {
            HIKVISION_PROVIDER_ID, HIKVISION_STUB_PROVIDER_ID -> hikvisionBridgeReceiver
            else -> fskBridgeReceiver
        }
    }

    private fun providerFamily(providerId: String): String {
        return when (providerId) {
            FSK_PROVIDER_ID, FSK_STUB_PROVIDER_ID -> "fsk"
            HIKVISION_PROVIDER_ID, HIKVISION_STUB_PROVIDER_ID -> "hikvision"
            DEFAULT_PROVIDER_ID -> "stub"
            else -> "unknown"
        }
    }

    private fun readProviderId(
        args: Map<String, Any?>,
        defaultValue: String = DEFAULT_PROVIDER_ID,
    ): String {
        return toTrimmedStringOrNull(args["provider_id"])
            ?: toTrimmedStringOrNull(args["providerId"])
            ?: defaultValue
    }
}
