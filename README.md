# 🌴 Bali Travel Health

**A comprehensive travel health companion for visitors to Bali.**

Bali Travel Health helps travellers stay safe before, during, and after their trip — with health risk assessments, step-by-step emergency guides, nurse booking, vaccine records, and personalised health advice — all available offline.

---

## ✨ Features

| Category | Feature |
|---|---|
| **Pre-Travel** | Health risk assessment · Vaccine record · Travel schedule |
| **During Travel** | Emergency guide (step-by-step & interactive decision trees) · BLS / CPR · Choking · Wound care · Allergy & anaphylaxis · Emergency numbers |
| **Post-Travel** | Post-travel health screening · Follow-up advice based on your results |
| **Nursing Care** | Browse & book registered nurses in Bali · Appointment management |
| **Offline-First** | All guides, assessments, and history cached locally — works without internet |
| **Localisation** | Support English & Indonesian |

---

## 📱 Screenshots

![Bali Travel Health App](https://balihealth.sgp1.cdn.digitaloceanspaces.com/Bali%20Travel%20Health%20App.png)

---

## Requirements

| Requirement | Value |
|---|---|
| iOS | 18.6 or later |
| Device | iPhone |
| Xcode (to build) | 26 / Xcode 16+ |
| Swift | 5.10+ |

---

## 📦 Installation — Sideloading via Sideloadly

### Requirement Before Sideloading
You only need a free Apple ID.

> **Note:** Free Apple ID sideloads expire after **7 days**. Re-run the steps below to renew. A paid Apple Developer account removes this limit.

### Step 1 — Download Sideloadly

1. Go to **[sideloadly.io](https://sideloadly.io)** and download the version for your computer (Windows or macOS).
2. Install and launch Sideloadly.

### Step 2 — Get the IPA file

Download the latest `BaliTravelHealth.ipa` from the [**Releases**](../../releases/latest) page.

### Step 3 — Connect your iPhone

1. Connect your iPhone to your computer with a USB cable.
2. Unlock your iPhone and tap **Trust** when asked to trust the computer.
3. If using macOS, open **Finder** and confirm your iPhone appears in the sidebar.

### Step 4 — Sideload

1. Open **Sideloadly**.
2. Drag and drop `BaliTravelHealth.ipa` into the Sideloadly window, or click the IPA icon to browse for it.
3. Make sure your device is shown in the device dropdown.
4. Enter your **Apple ID** email address in the account field.
5. Click **Start**.
6. Enter your Apple ID **password** when prompted.  
   > Sideloadly uses Apple's own signing servers — your credentials are sent directly to Apple, not stored by Sideloadly.
7. Wait for "Done" to appear. The app will appear on your Home Screen.

### Step 5 — Trust the developer certificate

Before launching the app you must trust the signing certificate on your device:

1. Open **Settings → General → VPN & Device Management**.
2. Under **Developer App**, tap your Apple ID.
3. Tap **Trust "[your Apple ID]"** → **Trust**.

### Step 6 — Launch

Open **Bali Travel Health** from your Home Screen. Sign in with Google to get started.

### Renewing after 7 days (free Apple ID only)

Repeat Steps 3–5 with the same IPA and Apple ID. Your data is stored locally on the device and will not be lost.

---

## 🛠 Build from Source

```bash
# Clone the repository
git clone https://github.com/balitravelhealth/ios-app.git
cd ios-app

# Open in Xcode
open BaliTravelHealth.xcodeproj
```

1. Select your iPhone as the run destination (or a simulator).
2. In **Signing & Capabilities**, change the **Team** to your own Apple Developer account.
3. Press **⌘R** to build and run.

No package manager setup is required — the project uses only Apple system frameworks.

---

---

## 📚 Frameworks & Licenses

Bali Travel Health uses **only Apple system frameworks** — no third-party dependencies. All frameworks below ship with iOS and are provided under Apple's standard SDK license.

| Framework | Purpose |
|---|---|
| **SwiftUI** | Entire UI layer |
| **SwiftData** | Local persistence (healthcare facilities, cached items) |
| **Foundation** | Networking, JSON, file I/O, date handling |
| **Network** | `NWPathMonitor` for real-time connectivity detection |
| **Security** | Keychain Services — secure token and credential storage |
| **MapKit** | Healthcare facility map |
| **CoreLocation** | User location for facility search and appointment address |
| **AVFoundation** | Looping background videos on onboarding screens |


> No CocoaPods, Carthage, or Swift Package Manager dependencies are used.  
> No analytics SDKs, ad SDKs, or tracking libraries are included.

---

## 🔒 Privacy

- **No third-party analytics or tracking** — zero SDK dependencies
- Authentication tokens stored exclusively in the iOS **Keychain**
- All guide and assessment data cached locally in **Application Support** (not iCloud-synced)
- Location is requested only when the user opens the facility finder

---

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you'd like to change.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

---

## 📬 Contact

For questions, feedback, or issues, please open a [GitHub Issue](../../issues).

---

<p align="center">Made with ❤️ for travellers visiting Bali 🌴</p>
