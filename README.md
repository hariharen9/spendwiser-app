<div align="center">

<img src="assets/branding/icon-money.svg" width="112" alt="SpendWiser" />

# SpendWiser

**Your bank app shows what’s left. SpendWiser shows what happens next.**

A local-first, India-native **Financial OS** built in Flutter — combining a phase-aware Cash Runway engine, 2-second capture (text, voice, receipt OCR, bank SMS), credit card & EMI intelligence, and a smoked-glass Command Orb UI.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Android-First-3DDC84?style=for-the-badge&logo=android&logoColor=black)
![Local--First](https://img.shields.io/badge/Local--First-Hive%20%2B%20Sync-D4FF3A?style=for-the-badge&labelColor=101010)
![Privacy](https://img.shields.io/badge/No%20Bank%20Logins-Privacy%20First-FF9933?style=for-the-badge&labelColor=101010)

</div>

---

## ⚡ Why It Hits Different

Most finance apps are glorified spreadsheets that judge you *after* you're broke. SpendWiser is built around **forward signal**:

- **🧠 Smart Cash Runway** — Knows rent & bills hit on the 1st–5th and refuses to extrapolate start-of-month spikes into a fake month-end crash.
- **🎙️ 2-Second Capture** — Type `"chai 40"` or `"uber 280"`, speak it, snap a receipt, or parse bank SMS alerts automatically.
- **✨ Ask SpendWiser + Optional BYOK AI** — Instant offline answers out of the box (`LocalAskEngine`), plus an optional **SpendWiser AI** copilot (Gemini, OpenRouter, or Claude — your key, zero subscriptions).
- **🇮🇳 India-Native DNA** — Built for UPI velocity, HDFC/ICICI/SBI/Axis/Kotak/Amex SMS formats, Indian card billing cycles, and ₹ lakh/crore formatting.
- **🛸 Command Orb + Customizable Nav** — Navigate via a tactile radial **Command Orb** & Bento launcher, or switch to a **customizable Nav Bar** (up to 3 left + Apps + 3 right).
- **🔒 Zero Bank Credentials** — Local-first storage with Hive, biometric/PIN lock, full PDF/XLSX/JSON export, and optional Firebase sync.

---

## ⚡ Capture Without Friction

| Input | Powered By | Example |
|---|---|---|
| **Quick Type** | `CaptureParser` | `"chai 40"`, `"zomato 340"`, `"salary 142000"` |
| **Voice** | `speech_to_text` | Speak natural amounts & merchant names |
| **Receipt OCR** | `google_mlkit_text_recognition` | Snap a bill → extracts items, merchant & total |
| **Bank SMS** | `BankSmsParser` | Parses HDFC, ICICI, Axis, SBI, Kotak, Amex & UPI alerts (ignores OTPs & promos) |

Merchants are auto-categorized across **Indian & global brands** (Swiggy, Zomato, Blinkit, Zepto, BigBasket, BookMyShow, Uber, Ola, Rapido, IRCTC, Jio, Airtel, Amazon, Flipkart, YouTube, Netflix, Spotify, and more) with **real brand icons** via `simple_icons` + crisp vector fallbacks.

---

## 🎛️ The Financial OS Modules

| Module | What It Actually Does |
|---|---|
| **Home** | Net Worth hero card, Cash Runway curve, Safe-to-Spend, Financial Health Score & upcoming bills |
| **Ledger** | Day-grouped transaction archive + calendar view, search, tags, and instant edits |
| **Banks** | Savings, cash, and liquid account balances in one place |
| **Cards** | Statement cycles, utilization, minimum vs. total due, cardholder details & due countdowns |
| **Debt** | Loan tracking, EMI calendar, full amortization schedules & **Avalanche vs. Snowball** payoff simulator |
| **Budgets** | Category envelopes + total monthly pace without guilt-trip UI |
| **Goals** | Target amounts, deadlines, progress tracking & contributions |
| **Subscriptions** | Active renewals, recurring schedules & optional **AI Leak Audit** |
| **Split** | Shared expenses with friends/roommates, balances & clean settlements |
| **Insights** | Monthly reports, Year in Review, top merchants & **Ask SpendWiser** |
| **SpendWiser AI** *(Optional)* | Dedicated BYOK financial copilot unlocked when you add a Gemini, OpenRouter, or Claude key |
| **Tools & Export** | Annual summary **PDF**, statement **Excel (`.xlsx`)**, JSON backup/restore & PIN/biometric lock |

---

## ✨ Ask SpendWiser & Optional BYOK AI

SpendWiser works **100% offline by default** — no API key required:

- **Offline Instant Engine (`LocalAskEngine`)** — Answers biggest spends, last-N-day lists, `#tag` totals, custom date ranges (`1 Nov to 10 Nov`), category/merchant breakdowns, card dues, and Cash Runway locally with tap-to-filter Ledger links.
- **Optional BYOK Copilot (`SpendWiser AI`)** — Add your own **Gemini**, **OpenRouter**, or **Claude** API key in Settings (free tiers supported) to unlock:
  - **Dedicated SpendWiser AI App** in the launcher with multi-turn follow-ups and rich formatted answers.
  - **1-Tap Natural-Language Actions** — Type `"Log chai 40"` or `"Create a ₹25k Goa trip budget"` and confirm with one tap.
  - **"Can I Afford This?" & Debt Advisor** — Grounded in your live Cash Runway and Avalanche vs. Snowball payoff curve.
  - **AI Executive Takeaways** inside Monthly Reports & Year in Review.
  - **Subscription & Leak Audit** and **Clean up with AI** for messy voice/OCR transaction text.

---

## 🏗️ Tech Stack & Architecture

```text
lib/
├── core/          # Theme tokens, Instrument Serif + DM Sans typography, brand icons, shared widgets
├── data/
│   ├── models/    # Account, Card, Loan, Transaction, Subscription, Goal, Split, Snapshot
│   ├── services/  # FinanceCalculator (Runway, Health, Amortization, Payoff), PDF/XLSX/Backup
│   ├── sms/       # BankSmsParser (Indian banks + UPI + OTP/promo filtering)
│   └── mock/      # Seeded prototype store
└── features/      # Home, Ledger, Cards, Debt, Budgets, Goals, Split, Subscriptions, Insights, Settings, Launcher
```

| Layer | Packages |
|---|---|
| **State & UI** | `flutter_riverpod`, `animations`, `flutter_svg`, `simple_icons`, `intl` |
| **Local Storage** | `hive`, `hive_flutter`, `path_provider` |
| **Capture & Intelligence** | `speech_to_text`, `image_picker`, `google_mlkit_text_recognition` |
| **Security & Alerts** | `local_auth`, `crypto`, `flutter_local_notifications`, `timezone` |
| **Exports & Sync** | `pdf`, `excel`, `share_plus`, `file_picker`, `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in` |

---

## 🚀 Run It Locally

```bash
# 1. Install dependencies
flutter pub get

# 2. Run on a connected device or emulator
flutter run

# 3. Verify static analysis & test suite
flutter analyze
flutter test
```

---

## 🔒 Privacy Stance

1. **No ads. No data brokers.**
2. **No bank logins or scraping credentials.**
3. **Local-first by default** — your ledger and `LocalAskEngine` work offline on-device.
4. **AI is 100% opt-in (BYOK)** — no AI requests are ever made unless you add your own API key, and clearing it disables all AI UI immediately.
5. **Your data leaves when you say so** — export to PDF/XLSX/JSON or delete everything anytime.

---

<div align="center">

**Built for people who want clarity, not a second job as an accountant.**

<br />

<sub>DESIGNED & BUILT BY</sub>

### [Hariharen](https://hariharen.space)

[![Portfolio](https://img.shields.io/badge/Portfolio-hariharen.space-D4FF3A?style=for-the-badge&labelColor=101010)](https://hariharen.space)

</div>
