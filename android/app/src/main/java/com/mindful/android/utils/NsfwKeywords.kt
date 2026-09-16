package com.mindful.android.utils

import java.net.URLDecoder

/**
 * Decides whether a search query is looking for adult content.
 *
 * Queries are split into whole words so innocent words that merely contain a
 * keyword ("class", "analyse", "Stripe", "canteen") never match. Explicit terms
 * are enough on their own; ambiguous ones only count when the query carries
 * another adult signal.
 */
object NsfwKeywords {

    /** Unambiguous terms: one is enough. */
    private val explicit = hashSetOf(
        "anal",
        "bdsm",
        "blowjob",
        "boobs",
        "buceta",
        "camgirl",
        "camsex",
        "cock",
        "creampie",
        "cumshot",
        "deepthroat",
        "dominatrix",
        "erotic",
        "erotique",
        "fetish",
        "foursome",
        "gangbang",
        "gozar",
        "gozei",
        "gozo",
        "handjob",
        "hentai",
        "incest",
        "masturbate",
        "masturbation",
        "milf",
        "naked",
        "nude",
        "nudes",
        "nudity",
        "onlyfans",
        "orgasm",
        "orgy",
        "partouze",
        "pelada",
        "penis",
        "porn",
        "porno",
        "pornhub",
        "pornographie",
        "pornography",
        "pussy",
        "redtube",
        "salope",
        "sex",
        "siririca",
        "softcore",
        "striptease",
        "stripper",
        "threesome",
        "tits",
        "vagina",
        "xhamster",
        "xnxx",
        "xvideos",
        "xxx",
        "youporn",
    )

    /** Terms with innocent meanings: they need a second adult signal. */
    private val ambiguous = hashSetOf(
        "18+",
        "adult",
        "adulte",
        "amateur",
        "arousal",
        "dick",
        "ass",
        "bondage",
        "breasts",
        "cam",
        "desire",
        "ebony",
        "escort",
        "gay",
        "hardcore",
        "hookup",
        "hot",
        "kink",
        "latina",
        "leaked",
        "lesbian",
        "lingerie",
        "lust",
        "naughty",
        "nu",
        "nue",
        "nus",
        "oral",
        "sexe",
        "sexual",
        "sexuel",
        "sexy",
        "strip",
        "teen",
        "teens",
        "uncensored",
        "voyeur",
        "webcam",
    )

    /** Multi-word expressions, matched on the normalised query. */
    private val explicitPhrases = listOf(
        "oral sex",
        "sex tape",
        "sextape",
        "video x",
        "film x",
    )

    private val separators = Regex("[^\\p{L}\\p{N}+]+")

    fun isAdultQuery(rawQuery: String): Boolean {
        val query = normalise(rawQuery)
        if (query.isBlank()) return false
        if (explicitPhrases.any { " $query ".contains(" $it ") }) return true

        var ambiguousHits = 0
        for (word in query.split(' ')) {
            if (word in explicit) return true
            if (word in ambiguous) ambiguousHits++
        }
        return ambiguousHits >= 2
    }

    private fun normalise(rawQuery: String): String {
        val decoded = runCatching { URLDecoder.decode(rawQuery, "UTF-8") }
            .getOrDefault(rawQuery)
        return decoded.lowercase()
            .replace(separators, " ")
            .trim()
    }
}
