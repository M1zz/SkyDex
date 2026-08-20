# App Review Information — Notes (paste into App Store Connect)

App Store Connect → 앱 버전 → **App Review Information → Notes** 에 아래 영문 블록을 그대로
붙여 넣습니다. Sign-in required 체크는 해제(계정 없음). Attachment 자리에 실기기 화면 녹화를
올립니다.

---

## 1. Demo account

Not applicable. The app has **no accounts, no login screen, and no server of ours**. Every
feature is available immediately on first launch. There is nothing to unlock, purchase, or
subscribe to.

The app does sync the user's own photos to **their own iCloud** (CloudKit private database)
so their collection survives losing or replacing a device. This uses whatever Apple Account
is already signed in to the device — there is no sign-up, no credential entry, and no
account for the reviewer to create. If no Apple Account is signed in, or iCloud is off for
this app, every feature still works and the data stays on the device.

## 2. Devices and OS versions tested

- iPhone 16 (iPhone17,3) — iOS 26.5.2 (23F84)
- iPhone 16 Plus (iPhone17,4) — iOS 26.5.2 (23F84)
- iPhone 15 Pro Max (iPhone16,2) — iOS 26.6 (23G71)

The app is iPhone-only (TARGETED_DEVICE_FAMILY = 1), portrait-only, and requires iOS 17.0
or later. The attached screen recording was captured on a physical iPhone 16 running
iOS 26.5.2.

## 3. Purpose and target audience

"하늘색" (SkyDex) is a personal, offline sky-colour collecting app.

The problem it solves: people photograph the sky constantly, and those photos end up as
undifferentiated clutter in the camera roll. This app turns them into a collection with a
shape.

How it works:
- The main screen is a board of 48 distinct sky colours, drawn as faint empty rings.
- The user photographs the sky. The app crops the photo to a square, extracts the dominant
  sky colour from it, and fills the single nearest swatch on the board (colour distance is
  measured with CIEDE2000).
- Filled swatches keep their full colour for a week and then slowly fade over eight weeks,
  so the board shows how recently each colour was actually seen. Nothing is ever deleted
  automatically and there are no streaks to lose.
- Additional screens: an archive/timeline of every photo taken, a photo detail view with the
  extracted colour and its Korean name, and a palette view grouping collected colours by
  colour family. Home Screen widgets show the board and the current hour's sky colour.

Target audience: general audience, no age restriction, no objectionable content. It is aimed
at people who enjoy a small daily photo habit and at people interested in colour. The user
interface is in Korean.

## 4. How to set up and access the main features

No setup, no credentials, no sample files are required.

1. Launch the app. The board of 48 empty colour rings appears immediately.
2. The app asks for **location** permission (When In Use). Allow or deny — either is fine.
   It is used once, at kilometre accuracy, only to compute local sunrise/sunset so the
   reference colours land at the right hour. If denied, the app falls back to a default
   coordinate and every feature keeps working.
3. Tap the camera button at the bottom. The app asks for **camera** permission.
4. Point the camera anywhere and tap the shutter. **The app never rejects a photo** — an
   office ceiling, a lamp, or a wall works exactly like real sky. The photo is saved and the
   matching swatch on the board is filled with the colour extracted from it.
5. Tap a filled swatch, or open the archive from the top-right button, to see the photo,
   its extracted colour and hex value, and the time it was taken.
6. To delete: open a photo and tap "지우기" (Delete), or swipe a row in the archive list.
   Deletion removes the photo and its entry from the device and from the user's iCloud.
7. The gear button at the top right of the archive screen opens Settings: an iCloud storage
   switch, **피드백 보내기** (Send Feedback), **리뷰 남기기** (Write a Review), links to the
   privacy policy and support page, and the app version.

## 5. External services, tools, and platforms used

- **Apple CloudKit (private database)** — the user's photos, extracted colours, capture
  times and notes are synced to the user's **own** iCloud account, container
  `iCloud.com.leeo.SkyDex`, so the collection survives a lost phone or a reinstall. The
  developer operates no server, cannot read this data, and holds no copy of it. Nothing is
  ever shared with any other user; there is no sharing feature in the app. Deleting an entry
  in the app deletes the iCloud copy. If iCloud is unavailable the app falls back to
  device-only storage and every feature keeps working.
- **Apple WeatherKit** — optional. Used only to tell the user what colour today's sky is
  expected to be at a given hour. If the network is unavailable or the request fails, the
  feature silently degrades and the app draws its default clear-sky reference colours.
  The required "Apple Weather" attribution and a link to the legal page are displayed on
  the screen where this data appears.
- **Core Location** — When In Use, kilometre accuracy, requested once, stored only in local
  UserDefaults. Coordinates are never attached to photos and never leave the device.
- **SwiftData (on-device store)** — photos and entries are stored in the app's own
  container on the device, and that store is what CloudKit syncs.
- **LeeoKit** — the developer's own open-source Swift package
  (https://github.com/M1zz/LeeoKit), shared across the developer's apps. It provides the
  in-app feedback form, the review prompt, and anonymous usage counting. It bundles no
  third-party SDK and talks only to Apple's CloudKit.
- **Apple CloudKit (public database, container `iCloud.com.Ysoup.FeedbackHub`)** — the
  developer's own container, used for three things: (a) feedback the user chooses to
  submit, (b) anonymous usage counts (launch count, app version, iOS version, device
  model, keyed by a random identifier unrelated to the device or Apple Account), and
  (c) MetricKit crash diagnostics. **No photo, colour, note, or location is ever sent
  here.** This is separate from the private container that syncs the user's collection.

There are no third-party SDKs, no advertising, no third-party analytics or crash
reporters, no AI or machine-learning services, no payment processors, no authentication
providers, and no backend server of any kind — every service above is Apple's, and the
only non-Apple code is the developer's own package. No third-party data processors are
involved.

## 6. User-generated content

Photos are user-generated but are **never shared, published, or made visible to anyone but
their owner**. There is no feed, no comments, no messaging, no profiles, and no way for one
user to see another user's content. Photos live in the app's container on the device and, if
the user is signed in to iCloud, in that user's own private CloudKit database — which moves
only between that same user's own devices. Consequently there is no third-party content for
anyone to report or block. Users can delete any of their own photos at any time, which
removes it from the device and from their iCloud (see step 6 above).

## 7. Purchases and subscriptions

None. The app is free, contains no in-app purchases, no subscriptions, and no paid or
locked content. There is no StoreKit code in the target at all.

## 7a. Settings and feedback

A gear button on the archive screen opens a settings sheet with: a switch for iCloud
storage, a **Send Feedback** form, a **Write a Review** row, links to the privacy policy and
support page, and the version. No account or credential is needed to reach any of it.

## 8. Regional differences

The app functions **identically in all regions**. There is no regional gating of features or
content, no region-specific content, and no server-side configuration. The interface is
localised in Korean only. Location and WeatherKit are used the same way everywhere; where
WeatherKit data is unavailable, the app falls back to its built-in reference colours, which
is the same behaviour as denying location permission.

## 9. Regulated industries / third-party protected material

Not applicable. The app is not in a regulated industry and contains no third-party protected
material. All images in the app are photographs taken by the user on their own device. The
48 reference colours and their Korean names are original content authored by the developer.
The only third-party data is Apple's own weather forecast, used under WeatherKit with the
required attribution displayed.

## 10. Purpose strings

- **NSCameraUsageDescription** — "하늘을 정사각형으로 촬영해 판에 담습니다. 사진은 이 기기와
  본인의 iCloud에만 보관되어 기기를 바꿔도 남으며, 개발자를 비롯한 누구에게도 전송되지
  않습니다." (The camera is used to photograph the sky as a square image that is added to the
  user's board. Photos are kept only on this device and in the user's own iCloud, so they
  survive changing devices, and are never transmitted to the developer or anyone else.)
- **NSLocationWhenInUseUsageDescription** — "이 자리의 기준 하늘색을 실제 일출·일몰 시각에
  맞추기 위해 위치를 한 번 대략적으로 씁니다. 좌표는 사진에 붙지 않고 어디로도 전송되지
  않습니다." (An approximate location is used once so the board's reference sky colours match
  the actual local sunrise and sunset times. Coordinates are never attached to photos and are
  never transmitted anywhere.)

The app does not use App Tracking Transparency, contacts, microphone, photo library, health,
or any other sensitive data or capability.

## 11. App privacy (nutrition label) — what is declared

The user's photos and colours are stored in the user's own Apple Account via CloudKit, which
Apple treats as data the user stores themselves rather than data collected by the developer.

Collected by the developer, and declared accordingly:

- **Usage Data → Product Interaction** — launch counts and app/OS/device version. Not
  linked to identity, not used for tracking. Keyed by a random identifier that is unrelated
  to the device or Apple Account and is regenerated on reinstall.
- **Diagnostics → Crash Data** — MetricKit reports. Not linked to identity, not used for
  tracking, and carrying no installation identifier.
- **User Content → Other User Content**, and **Contact Info** only when the user types a
  reply address — both only through the feedback form the user chooses to submit. Used for
  app functionality (answering the user), not for tracking.

Nothing is sold or shared with third parties, and nothing is used for tracking across apps
or websites.
