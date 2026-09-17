package com.deploydulupulangnanti.fake_gps_pro

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/** Uses bundled Android resources so notification actions also work without Flutter. */
object NotificationLanguage {
    private const val PREFERENCES = "notification_language"
    private const val LANGUAGE = "language_tag"

    fun set(context: Context, tag: String?) {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        preferences.edit().apply {
            if (tag.isNullOrBlank()) remove(LANGUAGE) else putString(LANGUAGE, tag)
        }.apply()
        MockLocationService.refreshNotificationLabels()
    }

    fun localizedContext(context: Context): Context {
        val tag = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).getString(LANGUAGE, null)
        val configuration = Configuration(context.resources.configuration)
        val locale = if (tag.isNullOrBlank()) resolveSystemLocale(configuration) else Locale.forLanguageTag(tag)
        configuration.setLocale(locale)
        return context.createConfigurationContext(configuration)
    }

    private fun resolveSystemLocale(configuration: Configuration): Locale {
        for (index in 0 until configuration.locales.size()) {
            val requested = configuration.locales[index]
            val language = when (requested.language) {
                "tl" -> "fil"
                "no", "nn" -> "nb"
                "gsw" -> "de"
                "in" -> "id"
                "iw" -> "he"
                else -> requested.language
            }
            if (language !in AppLanguageCodes.supported) continue
            if (language == "zh") {
                val traditional = requested.script == "Hant" ||
                    (requested.script.isBlank() && requested.country in listOf("TW", "HK", "MO"))
                return Locale.forLanguageTag(if (traditional) "zh-Hant" else "zh")
            }
            return Locale.forLanguageTag(language)
        }
        return Locale.ENGLISH
    }
}
