package com.example.omnix_dashboard.telemetry

import java.time.Instant
import java.time.format.DateTimeParseException

const val ONYX_TELEMETRY_TAG: String = "ONYX_TELEMETRY"

fun nowUtcIso(): String = Instant.now().toString()

fun parseUtcIsoOrNow(value: Any?): String {
    if (value is String) {
        val normalized = value.trim()
        if (normalized.isNotEmpty()) {
            return try {
                Instant.parse(normalized).toString()
            } catch (_: DateTimeParseException) {
                nowUtcIso()
            }
        }
    }
    return nowUtcIso()
}

fun toIntOrNull(value: Any?): Int? = when (value) {
    is Int -> value
    is Long -> value.toInt()
    is Float -> value.toInt()
    is Double -> value.toInt()
    is Number -> value.toInt()
    is String -> value.trim().toIntOrNull()
    else -> null
}

fun toDoubleOrNull(value: Any?): Double? = when (value) {
    is Double -> value
    is Float -> value.toDouble()
    is Int -> value.toDouble()
    is Long -> value.toDouble()
    is Number -> value.toDouble()
    is String -> value.trim().toDoubleOrNull()
    else -> null
}

fun toBooleanOrNull(value: Any?): Boolean? = when (value) {
    is Boolean -> value
    is String -> when (value.trim().lowercase()) {
        "true" -> true
        "false" -> false
        else -> null
    }
    else -> null
}

fun toTrimmedStringOrNull(value: Any?): String? {
    if (value == null) return null
    return value.toString().trim().takeIf { it.isNotEmpty() }
}

fun mapPayloadKeys(payload: Map<String, Any?>): String =
    payload.keys.sorted().joinToString(",", prefix = "[", postfix = "]")

fun asStringMap(value: Any?): Map<String, Any?> {
    if (value !is Map<*, *>) {
        return emptyMap()
    }
    return value.entries.associate { (key, entry) -> key.toString() to entry }
}
