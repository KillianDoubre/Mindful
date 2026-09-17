package com.mindful.android.utils

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NsfwKeywordsTest {

    private fun adult(query: String) = assertTrue(query, NsfwKeywords.isAdultQuery(query))
    private fun safe(query: String) = assertFalse(query, NsfwKeywords.isAdultQuery(query))

    @Test
    fun `explicit words are caught alone`() {
        adult("porn")
        adult("free porn videos")
        adult("hentai anime")
        adult("XXX")
        adult("nudes leak")
    }

    @Test
    fun `innocent words containing a keyword are not caught`() {
        safe("class schedule")
        safe("passeport renouvellement")
        safe("analyse de données")
        safe("stripe payment api")
        safe("canteen menu")
        safe("assurance voiture")
        safe("sussex university")
        safe("cocktail recipe")
        safe("essex weather")
    }

    @Test
    fun `a single ambiguous word is not enough`() {
        safe("gay rights history")
        safe("lesbian film festival")
        safe("teen movies 2024")
        safe("adult education courses")
        safe("escort mission game")
        safe("webcam driver")
        safe("sexe du bébé échographie")
        safe("pieds nus plage")
        safe("philip k dick books")
        safe("hot chocolate")
    }

    @Test
    fun `two ambiguous words are caught`() {
        adult("teen webcam")
        adult("hot lesbian")
        adult("sexy lingerie")
    }

    @Test
    fun `phrases are caught`() {
        adult("oral sex tips")
        adult("regarder un film x")
        adult("sextape leak")
    }

    @Test
    fun `url encoded and punctuated queries are normalised`() {
        adult("free%20porn")
        adult("PORN!!!")
        adult("xxx,videos")
        safe("hello%20world")
    }

    @Test
    fun `empty and malformed queries are safe`() {
        safe("")
        safe("   ")
        safe("%E0%A4%A")
        safe("100% legit")
    }
}
