# Work Island — Mac App Store Checklist

Last updated: 2026-08-13

This checklist records the last known state. Before any external action, verify the live source metadata and App Store Connect state. The user normally performs browser, tester, submission, and release operations personally.

## Local preparation

- [x] Permanent bundle ID confirmed: `com.shikazeriku.workisland`
- [x] Xcode macOS app target and shared scheme created
- [x] Version 1.0.0 configured; local source now targets build 56, while uploaded build 1 remains unchanged
- [x] macOS 13 minimum configured
- [x] Universal arm64/x86_64 archive verified
- [x] App Sandbox enabled
- [x] User-selected read/write entitlement limited to Import and Export
- [x] Privacy manifest included
- [x] macOS AppIcon Asset Catalog includes 16 through 1024 pixel variants
- [x] Hardened Runtime enabled
- [x] Apple Development certificate created and strict signature verified
- [x] Existing-data Import and Export implemented with pre-import backup
- [x] Privacy text is available from the app menu
- [x] Swift package tests pass: 103/103 on the current 0.11.20 source
- [x] Menu-bar status item removed; the canonical installed app can manage its macOS login item from onboarding or Settings
- [x] English App Store metadata draft prepared

## Apple account setup

- [x] Sign in to Apple Developer and App Store Connect
- [x] Register the explicit App ID `com.shikazeriku.workisland`
- [x] Create the macOS App Store Connect record: Apple ID `6797406491`
- [x] Confirm the public name `Work Island` is available
- [x] Use SKU `work-island-macos` and primary language English (U.S.)
- [x] Confirm the Free Apps Agreement is active; leave the Paid Apps Agreement unsigned while the app remains free with no in-app purchases

## Public metadata

- [x] Publish the support page and save `https://shikaland0927-ctrl.github.io/work-island/support.html`
- [x] Publish the privacy policy and save `https://shikaland0927-ctrl.github.io/work-island/privacy.html`
- [x] Add the private App Review contact details
- [x] Complete the age-rating questionnaire: calculated rating 4+
- [x] Publish App Privacy `Data Not Collected`
- [x] Set price to Free across all price regions
- [x] Set storefront availability to 148 regions, excluding all 27 EU member states; future-region auto-selection is off
- [x] Capture five accepted 1440×900 Mac screenshots with isolated sample data for the earlier UI
- [x] Upload the earlier approved two Mac screenshots in order: notch, then Dashboard
- [ ] Replace those screenshots because they use the old `Tasks` terminology and an earlier Dashboard/Stats layout
- [x] Omit App Preview for version 1.0.0 by product decision
- [x] Enter and save the prepared description, subtitle, keywords, promotional text, copyright, and review notes
- [x] Set category to Productivity and content rights to no third-party content
- [x] Disable review-login credentials because the app has no account
- [x] Use manual release after App Review approval

## Build delivery

- [x] Refresh the Apple account in Xcode and confirm Team `KTJ85A4ARS` has access to Certificates, Identifiers, & Profiles
- [x] Allow Xcode to create and use Cloud Managed Apple Distribution signing
- [x] Re-run all tests on the current source: 103/103 passed on 2026-08-13
- [x] Create and strictly verify a fresh Apple Development-signed 1.0.0 (1) archive for distribution export
- [x] Export and inspect the Store-signed 1.0.0 (1) package locally without uploading
- [x] Pass Xcode's upload analysis and App Store Connect validation
- [x] Upload version 1.0.0, build 1 to App Store Connect
- [x] Wait for processing and confirm `Non-Exempt Encryption: No`
- [x] Create and structurally validate an unsigned universal version 1.0.0, build 56 archive from the current source
- [ ] Create and validate a Distribution-signed version 1.0.0, build 56 or a newer unique build from the current source
- [ ] Upload that new build and wait for App Store Connect processing
- [ ] Add the new build to TestFlight and let the user complete cold-launch, physical notch/hover/click, timer, Import/Export, Dashboard-range, and History-edit QA
- [ ] Submit the tested build to Mac App Review

## Important boundaries

- The notarized Developer ID ZIP is for direct distribution and cannot be reused as the Store build.
- Do not change the production bundle ID after the first App Store Connect upload.
- Every uploaded build number must be unique.
- Do not replace the direct build's local data without exporting a backup first.
- Do not mark the app as collecting data unless its behavior or included SDKs change.
