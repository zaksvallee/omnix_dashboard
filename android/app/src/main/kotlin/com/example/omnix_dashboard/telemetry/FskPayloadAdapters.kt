package com.example.omnix_dashboard.telemetry

data class NormalizedHeartbeat(
    val heartRate: Int,
    val movementLevel: Double,
    val activityState: String,
    val batteryPercent: Int?,
    val capturedAtUtc: String,
    val gpsAccuracyMeters: Double?,
    val adapterId: String,
) {
    fun toMap(
        providerId: String,
        sdkStatus: String,
        source: String,
    ): MutableMap<String, Any?> = mutableMapOf<String, Any?>(
        "heart_rate" to heartRate,
        "movement_level" to movementLevel,
        "activity_state" to activityState,
        "captured_at_utc" to capturedAtUtc,
        "source" to source,
        "provider_id" to providerId,
        "sdk_status" to sdkStatus,
    ).apply {
        if (batteryPercent != null) {
            this["battery_percent"] = batteryPercent
        }
        if (gpsAccuracyMeters != null) {
            this["gps_accuracy_meters"] = gpsAccuracyMeters
        }
    }
}

data class FskPayloadValidation(
    val accepted: Boolean,
    val message: String,
    val normalized: NormalizedHeartbeat?,
)

interface FskPayloadAdapter {
    val id: String
    fun normalize(payload: Map<String, Any?>): FskPayloadValidation
}

private class AliasPayloadAdapter(
    override val id: String,
    private val aliases: Map<String, List<String>>,
) : FskPayloadAdapter {
    override fun normalize(payload: Map<String, Any?>): FskPayloadValidation {
        val lowered = payload.entries.associate { (key, value) -> key.lowercase() to value }

        fun pick(field: String): Any? {
            val keys = aliases[field] ?: return null
            for (key in keys) {
                val value = lowered[key.lowercase()]
                if (value != null) {
                    return value
                }
            }
            return null
        }

        val heartRate = toIntOrNull(pick("heart_rate"))
        val movementLevel = toDoubleOrNull(pick("movement_level"))
        val activityState = toTrimmedStringOrNull(pick("activity_state"))
        val capturedAtUtc = parseUtcIsoOrNow(pick("captured_at_utc"))
        val batteryPercent = toIntOrNull(pick("battery_percent"))
        val gpsAccuracyMeters = toDoubleOrNull(pick("gps_accuracy_meters"))

        if (heartRate == null || heartRate <= 0) {
            return FskPayloadValidation(
                accepted = false,
                message = "Missing or invalid heart_rate.",
                normalized = null,
            )
        }
        if (movementLevel == null) {
            return FskPayloadValidation(
                accepted = false,
                message = "Missing or invalid movement_level.",
                normalized = null,
            )
        }
        if (activityState == null) {
            return FskPayloadValidation(
                accepted = false,
                message = "Missing or invalid activity_state.",
                normalized = null,
            )
        }

        return FskPayloadValidation(
            accepted = true,
            message = "Payload mapped successfully.",
            normalized = NormalizedHeartbeat(
                heartRate = heartRate,
                movementLevel = movementLevel,
                activityState = activityState,
                batteryPercent = batteryPercent,
                capturedAtUtc = capturedAtUtc,
                gpsAccuracyMeters = gpsAccuracyMeters,
                adapterId = id,
            ),
        )
    }
}

class FskPayloadAdapterRegistry {
    private val adapters: Map<String, FskPayloadAdapter> = mapOf(
        "standard" to AliasPayloadAdapter(
            id = "standard",
            aliases = mapOf(
                "heart_rate" to listOf(
                    "heart_rate",
                    "heartrate",
                    "heart_rate_bpm",
                    "hr",
                    "heartRate",
                ),
                "movement_level" to listOf(
                    "movement_level",
                    "movementlevel",
                    "motion_level",
                    "movement",
                    "activity_level",
                    "motion_score",
                ),
                "activity_state" to listOf(
                    "activity_state",
                    "activitystate",
                    "state",
                    "activity",
                ),
                "battery_percent" to listOf(
                    "battery_percent",
                    "batterypercent",
                    "battery",
                    "battery_level",
                ),
                "captured_at_utc" to listOf(
                    "captured_at_utc",
                    "capturedatutc",
                    "captured_at",
                    "timestamp",
                    "time_utc",
                ),
                "gps_accuracy_meters" to listOf(
                    "gps_accuracy_meters",
                    "gpsaccuracymeters",
                    "gps_accuracy",
                    "accuracy",
                    "location_accuracy",
                ),
            ),
        ),
        "legacy_ptt" to AliasPayloadAdapter(
            id = "legacy_ptt",
            aliases = mapOf(
                "heart_rate" to listOf(
                    "pulse",
                    "hr",
                    "heart_rate",
                    "heartrate",
                    "heart_rate_bpm",
                    "heartRate",
                ),
                "movement_level" to listOf(
                    "motion_score",
                    "motion_level",
                    "movement",
                    "movement_level",
                    "movementlevel",
                    "activity_level",
                ),
                "activity_state" to listOf(
                    "state",
                    "activity",
                    "activity_state",
                    "activitystate",
                ),
                "battery_percent" to listOf(
                    "battery",
                    "battery_level",
                    "battery_percent",
                    "batterypercent",
                ),
                "captured_at_utc" to listOf(
                    "time_utc",
                    "timestamp",
                    "captured_at",
                    "captured_at_utc",
                    "capturedatutc",
                ),
                "gps_accuracy_meters" to listOf(
                    "location_accuracy",
                    "accuracy",
                    "gps_accuracy",
                    "gps_accuracy_meters",
                    "gpsaccuracymeters",
                ),
            ),
        ),
        "hikvision_guardlink" to AliasPayloadAdapter(
            id = "hikvision_guardlink",
            aliases = mapOf(
                "heart_rate" to listOf(
                    "vitals_hr",
                    "heartbeat_bpm",
                    "watch_hr",
                    "heart_rate",
                    "heartRate",
                    "hr",
                ),
                "movement_level" to listOf(
                    "motion_index",
                    "movement_score",
                    "imu_motion_level",
                    "movement_level",
                    "movementLevel",
                    "motion_level",
                ),
                "activity_state" to listOf(
                    "duty_state",
                    "guard_state",
                    "activity_label",
                    "activity_state",
                    "activityState",
                    "state",
                ),
                "battery_percent" to listOf(
                    "watch_battery_percent",
                    "wearable_battery",
                    "watch_battery",
                    "battery_percent",
                    "batteryPercent",
                    "battery_level",
                ),
                "captured_at_utc" to listOf(
                    "event_utc",
                    "event_time_utc",
                    "captured_time_utc",
                    "captured_at_utc",
                    "capturedAtUtc",
                    "timestamp",
                ),
                "gps_accuracy_meters" to listOf(
                    "gps_hdop_m",
                    "location_accuracy_meters",
                    "fix_accuracy_m",
                    "gps_accuracy_meters",
                    "gpsAccuracyMeters",
                    "location_accuracy",
                ),
            ),
        ),
    )

    fun availableAdapterIds(): List<String> = adapters.keys.sorted()

    fun resolve(requested: String?): Pair<FskPayloadAdapter, String?> {
        val normalizedRequest = requested?.trim()?.lowercase().orEmpty()
        if (normalizedRequest.isEmpty()) {
            return adapters.getValue("standard") to null
        }
        val adapter = adapters[normalizedRequest]
        return if (adapter != null) {
            adapter to normalizedRequest
        } else {
            adapters.getValue("standard") to normalizedRequest
        }
    }
}
