package com.spendwiser.spendwiser_app

/// A deliberately small gate in front of the local queue: only bank senders
/// with transaction-like content are stored at all. The Dart parser does the
/// precise extraction; this keeps OTPs and personal SMS out of storage.
object SmsFilter {
    private val bankTokens = listOf(
        "HDFC", "ICICI", "AXIS", "SBI", "KOTAK", "IDFC", "YESBNK", "YESBANK",
        "INDUS", "RBL", "FEDERAL", "CANARA", "BOB", "PNB", "UNION", "IDBI",
        "CITI", "HSBC", "SCB", "DBS", "AUBANK", "AMEX", "BAJAJ", "TATA", "PAYTM",
    )

    private val otp = Regex(
        "(?i)\\b(otp|one[- ]time password|verification code|do not share|never share)\\b",
    )
    private val transaction = Regex(
        "(?i)\\b(debit(ed)?|credit(ed)?|withdraw(n|al)?|spent|paid|purchase|deposit(ed)?|received|refund)\\b",
    )
    private val amount = Regex(
        "(?i)(?:inr|rs\\.?|₹)\\s*[\\d,]+(?:\\.\\d{1,2})?",
    )

    fun isCandidate(sender: String, body: String): Boolean {
        val normalized = sender.uppercase()
        if (bankTokens.none { normalized.contains(it) }) return false
        if (otp.containsMatchIn(body)) return false
        return transaction.containsMatchIn(body) && amount.containsMatchIn(body)
    }
}
