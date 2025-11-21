//
//  ProfanityList.swift
//  Molten
//
//  Comprehensive profanity detection using community-maintained word list
//  Based on LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words
//

import Foundation

/// Comprehensive profanity word list for client-side filtering
///
/// This provides first-line defense against obviously inappropriate submissions.
/// Server-side batch moderation with ML (Perspective API) provides second-line defense.
public enum ProfanityList {

    /// Comprehensive set of profane/inappropriate words
    /// Organized by category for maintainability
    public nonisolated static let words: Set<String> = {
        var allWords: Set<String> = []

        // MARK: - Strong Profanity
        allWords.formUnion([
            "fuck", "fucked", "fucker", "fucking", "fucks", "motherfucker",
            "shit", "shitty", "shits", "bullshit", "horseshit",
            "cunt", "cunts",
            "cock", "cocks", "cocksucker",
            "pussy", "pussies",
            "asshole", "assholes",
        ])

        // MARK: - Moderate Profanity
        allWords.formUnion([
            "damn", "goddamn", "dammit",
            "hell",
            "ass", "asses",
            "bitch", "bitches", "bitchy",
            "bastard", "bastards",
            "crap", "crappy",
            "piss", "pissed", "pissing",
            "dick", "dicks",
        ])

        // MARK: - Racial/Ethnic Slurs (zero tolerance)
        allWords.formUnion([
            "nigger", "nigga", "nig",
            "chink", "gook", "jap",
            "kike", "spic", "wetback",
            "towelhead", "raghead",
            "beaner", "cracker",
        ])

        // MARK: - Sexual Orientation/Gender Slurs (zero tolerance)
        allWords.formUnion([
            "fag", "faggot", "fags",
            "dyke", "dykes",
            "tranny", "trannies",
            "shemale",
        ])

        // MARK: - Disability Slurs (zero tolerance)
        allWords.formUnion([
            "retard", "retarded", "retards",
            "tard", "libtard",
            "spaz", "spastic",
        ])

        // MARK: - Sexual/Explicit
        allWords.formUnion([
            "porn", "porno",
            "whore", "whores",
            "slut", "sluts", "slutty",
            "rape", "raping", "rapist",
            "penis", "vagina", "testicle",
            "orgasm", "masturbate",
        ])

        // MARK: - Spam/Commercial (common spam words)
        allWords.formUnion([
            "viagra", "cialis",
            "casino", "poker",
            "lottery", "jackpot",
            "bitcoin", "crypto",
            "forex", "trading",
            "enlargement",
        ])

        // MARK: - Common Obfuscations
        allWords.formUnion([
            "f**k", "f***", "fuk", "fck",
            "sh*t", "sht",
            "b*tch", "btch",
            "a**", "a**hole",
            "d*mn", "dmn",
            "p*ss",
        ])

        return allWords
    }()

    /// Check if a word is in the profanity list
    /// - Parameter word: The word to check (case-insensitive)
    /// - Returns: True if the word is profane
    public nonisolated static func isProfane(_ word: String) -> Bool {
        let normalized = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Exact match
        if words.contains(normalized) {
            return true
        }

        // Substring match for profanity embedded in other text
        // e.g., catches "fuckface", "shithead", etc.
        for profane in words where profane.count >= 4 { // Only check substantial words
            if normalized.contains(profane) {
                return true
            }
        }

        return false
    }

    /// Check if any word in a collection is profane
    /// - Parameter words: Array of words to check
    /// - Returns: True if any word is profane
    public nonisolated static func containsProfanity(in words: [String]) -> Bool {
        return words.contains { isProfane($0) }
    }
}
