package com.example.omnix_dashboard.telemetry

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.util.Log
import com.example.omnix_dashboard.BuildConfig
import org.json.JSONObject
import java.lang.reflect.InvocationHandler
import java.lang.reflect.Method
import java.lang.reflect.Modifier
import java.lang.reflect.Proxy

interface FskVendorSdkConnector {
    val connectorId: String
    val connectorSource: String
    val heartbeatSource: String
    val isActive: Boolean

    fun start(
        context: Context,
        heartbeatAction: String,
        onHeartbeatPayload: (Map<String, Any?>) -> Unit,
    )

    fun stop()
}

class BroadcastFskVendorSdkConnector : FskVendorSdkConnector {
    override val connectorId: String = "broadcast_intent_connector"
    override val connectorSource: String = "platform_default"
    override val heartbeatSource: String = "broadcast"

    @Volatile
    private var registered: Boolean = false

    private var appContext: Context? = null
    private var callback: ((Map<String, Any?>) -> Unit)? = null

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val payload = mutableMapOf<String, Any?>()
            val extras: Bundle? = intent.extras
            if (extras != null) {
                for (key in extras.keySet()) {
                    payload[key] = extras.get(key)
                }
            }
            callback?.invoke(payload)
        }
    }

    override val isActive: Boolean
        get() = registered

    override fun start(
        context: Context,
        heartbeatAction: String,
        onHeartbeatPayload: (Map<String, Any?>) -> Unit,
    ) {
        if (registered) return
        val applicationContext = context.applicationContext
        val intentFilter = IntentFilter(heartbeatAction)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val receiverExportFlag = if (BuildConfig.DEBUG) {
                Context.RECEIVER_EXPORTED
            } else {
                Context.RECEIVER_NOT_EXPORTED
            }
            applicationContext.registerReceiver(
                receiver,
                intentFilter,
                receiverExportFlag,
            )
        } else {
            @Suppress("DEPRECATION")
            applicationContext.registerReceiver(receiver, intentFilter)
        }
        appContext = applicationContext
        callback = onHeartbeatPayload
        registered = true
    }

    override fun stop() {
        if (!registered) return
        try {
            appContext?.unregisterReceiver(receiver)
        } catch (_: Exception) {
            // Keep disposal resilient.
        }
        callback = null
        appContext = null
        registered = false
    }
}

abstract class ReflectiveVendorSdkConnectorBase : FskVendorSdkConnector {
    override val connectorSource: String = "platform_builtin_reflective"
    override val heartbeatSource: String
        get() = if (usingFallbackBroadcast) "broadcast_fallback" else "vendor_reflection"

    protected abstract val managerClassCandidates: List<String>
    protected abstract val callbackInterfaceCandidates: List<String>
    protected abstract val registerMethodCandidates: List<String>
    protected abstract val unregisterMethodCandidates: List<String>
    protected abstract val callbackMethodCandidates: Set<String>

    private val fallbackBroadcastConnector = BroadcastFskVendorSdkConnector()
    private var managerInstance: Any? = null
    private var callbackProxy: Any? = null
    private var unregisterMethod: Method? = null
    private var contextForUnregister: Context? = null
    private var usingFallbackBroadcast: Boolean = false

    override val isActive: Boolean
        get() = if (usingFallbackBroadcast) {
            fallbackBroadcastConnector.isActive
        } else {
            managerInstance != null && callbackProxy != null
        }

    override fun start(
        context: Context,
        heartbeatAction: String,
        onHeartbeatPayload: (Map<String, Any?>) -> Unit,
    ) {
        if (isActive) return
        try {
            startReflective(context.applicationContext, onHeartbeatPayload)
            usingFallbackBroadcast = false
        } catch (error: Throwable) {
            Log.e(
                ONYX_TELEMETRY_TAG,
                "$connectorId reflective start failed: ${error.message}. Falling back to broadcast.",
                error,
            )
            usingFallbackBroadcast = true
            fallbackBroadcastConnector.start(context, heartbeatAction, onHeartbeatPayload)
        }
    }

    override fun stop() {
        if (usingFallbackBroadcast) {
            fallbackBroadcastConnector.stop()
            usingFallbackBroadcast = false
            return
        }
        val manager = managerInstance
        val callback = callbackProxy
        val unregister = unregisterMethod
        val context = contextForUnregister
        try {
            if (manager != null && callback != null && unregister != null) {
                invokeCallbackMethod(unregister, manager, callback, context)
            }
        } catch (error: Throwable) {
            Log.e(
                ONYX_TELEMETRY_TAG,
                "$connectorId reflective stop failed: ${error.message}",
                error,
            )
        } finally {
            managerInstance = null
            callbackProxy = null
            unregisterMethod = null
            contextForUnregister = null
        }
    }

    private fun startReflective(
        context: Context,
        onHeartbeatPayload: (Map<String, Any?>) -> Unit,
    ) {
        val managerClass = resolveManagerClass()
        val manager = instantiateManager(managerClass, context)
        val callbackInterface = resolveCallbackInterface(managerClass)
        val callback = createCallbackProxy(
            callbackInterface = callbackInterface,
            onHeartbeatPayload = onHeartbeatPayload,
        )
        val registerMethod = resolveCallbackMethod(
            managerClass = managerClass,
            methodNames = registerMethodCandidates,
            callbackInterface = callbackInterface,
            required = true,
        ) ?: throw NoSuchMethodException(
            "No register method found for ${managerClass.name} and ${callbackInterface.name}.",
        )
        val unregister = resolveCallbackMethod(
            managerClass = managerClass,
            methodNames = unregisterMethodCandidates,
            callbackInterface = callbackInterface,
            required = false,
        )
        invokeCallbackMethod(registerMethod, manager, callback, context)
        managerInstance = manager
        callbackProxy = callback
        unregisterMethod = unregister
        contextForUnregister = context
    }

    private fun resolveManagerClass(): Class<*> {
        val errors = mutableListOf<String>()
        for (className in managerClassCandidates) {
            try {
                return Class.forName(className)
            } catch (error: Throwable) {
                errors.add("${className}: ${error.message}")
            }
        }
        throw ClassNotFoundException(
            "No vendor manager class found for $connectorId. Tried: ${errors.joinToString("; ")}",
        )
    }

    private fun instantiateManager(managerClass: Class<*>, context: Context): Any {
        val staticFactoryNames = listOf("getInstance", "create", "instance")
        for (methodName in staticFactoryNames) {
            val withContext = managerClass.methods.firstOrNull { method ->
                method.name == methodName &&
                    Modifier.isStatic(method.modifiers) &&
                    method.parameterTypes.size == 1 &&
                    Context::class.java.isAssignableFrom(method.parameterTypes[0])
            }
            if (withContext != null) {
                withContext.isAccessible = true
                return withContext.invoke(null, context)
                    ?: throw IllegalStateException("Factory $methodName returned null.")
            }
            val withoutArgs = managerClass.methods.firstOrNull { method ->
                method.name == methodName &&
                    Modifier.isStatic(method.modifiers) &&
                    method.parameterTypes.isEmpty()
            }
            if (withoutArgs != null) {
                withoutArgs.isAccessible = true
                return withoutArgs.invoke(null)
                    ?: throw IllegalStateException("Factory $methodName returned null.")
            }
        }

        try {
            val contextCtor = managerClass.getDeclaredConstructor(Context::class.java)
            contextCtor.isAccessible = true
            return contextCtor.newInstance(context)
        } catch (_: NoSuchMethodException) {
            // Fall through to no-arg constructor.
        }

        val noArgCtor = managerClass.getDeclaredConstructor()
        noArgCtor.isAccessible = true
        return noArgCtor.newInstance()
    }

    private fun resolveCallbackInterface(managerClass: Class<*>): Class<*> {
        for (interfaceClassName in callbackInterfaceCandidates) {
            try {
                return Class.forName(
                    interfaceClassName,
                    false,
                    managerClass.classLoader ?: javaClass.classLoader,
                )
            } catch (_: Throwable) {
                // Continue to fallback probing.
            }
        }

        val callbackParam = managerClass.methods.firstNotNullOfOrNull { method ->
            if (!registerMethodCandidates.contains(method.name)) {
                return@firstNotNullOfOrNull null
            }
            method.parameterTypes.firstOrNull { type ->
                type.isInterface && !Context::class.java.isAssignableFrom(type)
            }
        }
        if (callbackParam != null) {
            return callbackParam
        }

        throw ClassNotFoundException(
            "No callback interface found for $connectorId on ${managerClass.name}.",
        )
    }

    private fun resolveCallbackMethod(
        managerClass: Class<*>,
        methodNames: List<String>,
        callbackInterface: Class<*>,
        required: Boolean,
    ): Method? {
        val method = managerClass.methods
            .filter { candidate -> methodNames.contains(candidate.name) }
            .sortedBy { candidate -> candidate.parameterTypes.size }
            .firstOrNull { candidate ->
                candidate.parameterTypes.any { parameterType ->
                    parameterType.isAssignableFrom(callbackInterface) ||
                        callbackInterface.isAssignableFrom(parameterType)
                }
            }

        if (method == null && required) {
            throw NoSuchMethodException(
                "No method found in ${managerClass.name} for names=${methodNames.joinToString()} callback=${callbackInterface.name}.",
            )
        }
        return method
    }

    private fun createCallbackProxy(
        callbackInterface: Class<*>,
        onHeartbeatPayload: (Map<String, Any?>) -> Unit,
    ): Any {
        val handler = InvocationHandler { _, method, args ->
            val callbackArgs = args ?: emptyArray()
            if (method.declaringClass == Any::class.java) {
                return@InvocationHandler when (method.name) {
                    "toString" -> "$connectorId-callback-proxy"
                    "hashCode" -> System.identityHashCode(this)
                    "equals" -> false
                    else -> null
                }
            }

            if (callbackArgs.isNotEmpty() &&
                (callbackMethodCandidates.contains(method.name) || callbackArgs.size == 1)
            ) {
                val payload = normalizeCallbackPayload(callbackArgs[0])
                if (payload.isNotEmpty()) {
                    onHeartbeatPayload(payload)
                }
            }
            defaultPrimitiveValue(method.returnType)
        }
        return Proxy.newProxyInstance(
            callbackInterface.classLoader ?: javaClass.classLoader,
            arrayOf(callbackInterface),
            handler,
        )
    }

    private fun invokeCallbackMethod(
        method: Method,
        manager: Any,
        callback: Any,
        context: Context?,
    ) {
        method.isAccessible = true
        val args = method.parameterTypes.map { parameterType ->
            when {
                parameterType.isAssignableFrom(callback.javaClass) -> callback
                context != null && Context::class.java.isAssignableFrom(parameterType) -> context
                else -> null
            }
        }
        method.invoke(manager, *args.toTypedArray())
    }

    private fun normalizeCallbackPayload(value: Any?): Map<String, Any?> {
        if (value == null) return emptyMap()
        if (value is Map<*, *>) {
            return value.entries.associate { (key, entry) -> key.toString() to entry }
        }
        if (value is Bundle) {
            val payload = mutableMapOf<String, Any?>()
            for (key in value.keySet()) {
                payload[key] = value.get(key)
            }
            return payload
        }
        if (value is String) {
            val trimmed = value.trim()
            if (trimmed.isEmpty()) return emptyMap()
            return try {
                jsonObjectToMap(JSONObject(trimmed))
            } catch (_: Throwable) {
                mapOf("raw_payload" to trimmed)
            }
        }

        val toMapMethodNames = listOf("toMap", "asMap", "toJsonMap")
        for (methodName in toMapMethodNames) {
            val method = value.javaClass.methods.firstOrNull { candidate ->
                candidate.name == methodName && candidate.parameterTypes.isEmpty()
            } ?: continue
            try {
                val methodResult = method.invoke(value)
                val normalized = normalizeCallbackPayload(methodResult)
                if (normalized.isNotEmpty()) {
                    return normalized
                }
            } catch (_: Throwable) {
                // Continue fallback extraction.
            }
        }

        val getterAliases = linkedMapOf(
            "heart_rate" to listOf("getHeartRate", "getHr", "getVitalsHr", "getHeartbeatBpm"),
            "movement_level" to
                listOf(
                    "getMovementLevel",
                    "getMotionIndex",
                    "getMotionScore",
                    "getImuMotionLevel",
                ),
            "activity_state" to listOf("getActivityState", "getDutyState", "getGuardState", "getState"),
            "battery_percent" to
                listOf(
                    "getBatteryPercent",
                    "getWatchBatteryPercent",
                    "getBatteryLevel",
                    "getWearableBattery",
                ),
            "captured_at_utc" to
                listOf(
                    "getCapturedAtUtc",
                    "getEventUtc",
                    "getTimestamp",
                    "getTimeUtc",
                    "getCapturedTimeUtc",
                ),
            "gps_accuracy_meters" to
                listOf(
                    "getGpsAccuracyMeters",
                    "getGpsHdopM",
                    "getLocationAccuracy",
                    "getLocationAccuracyMeters",
                ),
            "payload_adapter" to listOf("getPayloadAdapter", "getAdapterId"),
        )
        val extracted = mutableMapOf<String, Any?>()
        for ((field, methodNames) in getterAliases) {
            val getter = methodNames.firstNotNullOfOrNull { methodName ->
                value.javaClass.methods.firstOrNull { method ->
                    method.name == methodName && method.parameterTypes.isEmpty()
                }
            } ?: continue
            try {
                val getterValue = getter.invoke(value)
                if (getterValue != null) {
                    extracted[field] = getterValue
                }
            } catch (_: Throwable) {
                // Ignore failed getter.
            }
        }
        return extracted
    }

    private fun jsonObjectToMap(json: JSONObject): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        val iterator = json.keys()
        while (iterator.hasNext()) {
            val key = iterator.next()
            map[key] = json.get(key)
        }
        return map
    }

    private fun defaultPrimitiveValue(returnType: Class<*>): Any? {
        return when (returnType) {
            java.lang.Boolean.TYPE -> false
            java.lang.Integer.TYPE -> 0
            java.lang.Long.TYPE -> 0L
            java.lang.Float.TYPE -> 0f
            java.lang.Double.TYPE -> 0.0
            java.lang.Short.TYPE -> 0.toShort()
            java.lang.Byte.TYPE -> 0.toByte()
            java.lang.Character.TYPE -> 0.toChar()
            else -> null
        }
    }
}

class FskReflectiveVendorSdkConnector : ReflectiveVendorSdkConnectorBase() {
    override val connectorId: String = "fsk_reflective_vendor_connector"

    override val managerClassCandidates: List<String> = listOf(
        "com.onyx.vendor.fsk.LiveSdkManager",
        "com.onyx.vendor.fsk.TelemetryManager",
        "com.onyx.fsk.sdk.TelemetryManager",
    )
    override val callbackInterfaceCandidates: List<String> = listOf(
        "com.onyx.vendor.fsk.HeartbeatListener",
        "com.onyx.vendor.fsk.TelemetryListener",
        "com.onyx.fsk.sdk.HeartbeatListener",
    )
    override val registerMethodCandidates: List<String> = listOf(
        "setHeartbeatListener",
        "registerHeartbeatListener",
        "setTelemetryListener",
        "registerTelemetryListener",
        "addHeartbeatListener",
        "setCallback",
        "registerCallback",
    )
    override val unregisterMethodCandidates: List<String> = listOf(
        "clearHeartbeatListener",
        "unregisterHeartbeatListener",
        "clearTelemetryListener",
        "unregisterTelemetryListener",
        "removeHeartbeatListener",
        "clearCallback",
        "unregisterCallback",
    )
    override val callbackMethodCandidates: Set<String> = setOf(
        "onHeartbeat",
        "onHeartbeatUpdate",
        "onTelemetry",
        "onTelemetryUpdate",
        "onData",
    )
}

class HikvisionReflectiveVendorSdkConnector : ReflectiveVendorSdkConnectorBase() {
    override val connectorId: String = "hikvision_reflective_vendor_connector"

    override val managerClassCandidates: List<String> = listOf(
        "com.onyx.vendor.hikvision.LiveSdkManager",
        "com.hikvision.guardlink.TelemetryManager",
        "com.hikvision.sdk.guard.TelemetryService",
    )
    override val callbackInterfaceCandidates: List<String> = listOf(
        "com.onyx.vendor.hikvision.HeartbeatListener",
        "com.hikvision.guardlink.TelemetryListener",
        "com.hikvision.sdk.guard.HeartbeatCallback",
    )
    override val registerMethodCandidates: List<String> = listOf(
        "setTelemetryListener",
        "registerTelemetryListener",
        "setHeartbeatListener",
        "registerHeartbeatListener",
        "setGuardLinkListener",
        "registerGuardLinkListener",
        "setCallback",
        "registerCallback",
    )
    override val unregisterMethodCandidates: List<String> = listOf(
        "clearTelemetryListener",
        "unregisterTelemetryListener",
        "clearHeartbeatListener",
        "unregisterHeartbeatListener",
        "clearGuardLinkListener",
        "unregisterGuardLinkListener",
        "clearCallback",
        "unregisterCallback",
    )
    override val callbackMethodCandidates: Set<String> = setOf(
        "onTelemetry",
        "onTelemetryUpdate",
        "onHeartbeat",
        "onGuardHeartbeat",
        "onData",
    )
}

class ReflectiveFskVendorSdkConnector(
    private val delegate: FskVendorSdkConnector,
    override val connectorSource: String,
) : FskVendorSdkConnector {
    override val connectorId: String
        get() = delegate.connectorId

    override val heartbeatSource: String
        get() = delegate.heartbeatSource

    override val isActive: Boolean
        get() = delegate.isActive

    override fun start(
        context: Context,
        heartbeatAction: String,
        onHeartbeatPayload: (Map<String, Any?>) -> Unit,
    ) {
        delegate.start(context, heartbeatAction, onHeartbeatPayload)
    }

    override fun stop() {
        delegate.stop()
    }
}

data class FskVendorSdkConnectorLoadResult(
    val connector: FskVendorSdkConnector,
    val errorMessage: String?,
)

object FskVendorSdkConnectorLoader {
    fun resolve(
        context: Context,
        connectorClassName: String?,
        connectorClassSource: String?,
    ): FskVendorSdkConnectorLoadResult {
        val className = connectorClassName?.trim().orEmpty()
        if (className.isEmpty()) {
            return FskVendorSdkConnectorLoadResult(
                connector = BroadcastFskVendorSdkConnector(),
                errorMessage = null,
            )
        }

        return try {
            val clazz = Class.forName(className)
            val instance = instantiateConnector(clazz, context.applicationContext)
            if (instance !is FskVendorSdkConnector) {
                val message =
                    "Configured vendor connector $className does not implement FskVendorSdkConnector. Falling back to broadcast connector."
                Log.e(ONYX_TELEMETRY_TAG, message)
                FskVendorSdkConnectorLoadResult(
                    connector = BroadcastFskVendorSdkConnector(),
                    errorMessage = message,
                )
            } else {
                FskVendorSdkConnectorLoadResult(
                    connector = ReflectiveFskVendorSdkConnector(
                        delegate = instance,
                        connectorSource = connectorClassSource?.trim().orEmpty().ifEmpty {
                            "runtime_config"
                        },
                    ),
                    errorMessage = null,
                )
            }
        } catch (error: Throwable) {
            val message =
                "Failed to initialize vendor connector $className: ${error.message}. Falling back to broadcast connector."
            Log.e(ONYX_TELEMETRY_TAG, message, error)
            FskVendorSdkConnectorLoadResult(
                connector = BroadcastFskVendorSdkConnector(),
                errorMessage = message,
            )
        }
    }

    private fun instantiateConnector(clazz: Class<*>, context: Context): Any? {
        // Preferred path: connector class can receive app Context in ctor.
        try {
            val contextCtor = clazz.getDeclaredConstructor(Context::class.java)
            contextCtor.isAccessible = true
            return contextCtor.newInstance(context)
        } catch (_: NoSuchMethodException) {
            // Fall through to next constructor strategy.
        }

        // Fallback: no-arg ctor for simple connectors.
        try {
            val noArgCtor = clazz.getDeclaredConstructor()
            noArgCtor.isAccessible = true
            return noArgCtor.newInstance()
        } catch (_: NoSuchMethodException) {
            // Fall through to factory-method strategy.
        }

        // Final fallback: static create(Context) factory.
        val factoryMethod = clazz.methods.firstOrNull { method ->
            method.name == "create" &&
                method.parameterTypes.size == 1 &&
                Context::class.java.isAssignableFrom(method.parameterTypes[0])
        }
        if (factoryMethod != null) {
            return factoryMethod.invoke(null, context)
        }
        throw NoSuchMethodException(
            "No supported constructor/factory found for ${clazz.name}. " +
                "Expected (Context), (), or static create(Context).",
        )
    }
}
