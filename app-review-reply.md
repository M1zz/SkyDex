# App Review 답장 초안 — Guideline 5.2.5 (WeatherKit)

Submission ID: 837283f7-a525-4607-93b8-1138ed249bd5
대상: 1.0 (3) 리젝에 대한 답장. **빌드 1.0 (4)를 먼저 업로드한 뒤** 보낼 것.

App Store Connect → 해당 제출의 심사 메시지에 아래 영문을 그대로 붙여 넣습니다.
App Review Information → Notes 에는 `app-review-notes.md`의 12번 항목이 같은 내용으로
들어가 있어야 합니다. **화면 녹화 첨부는 필요 없습니다** — 보여줄 WeatherKit 기능이
더 이상 없기 때문입니다.

---

Hello, and thank you for the review.

**The app does not support WeatherKit.**

Build 1.0 (3) did link WeatherKit, and we understand why the attribution question was
raised. Rather than keep the dependency, we have removed it completely. Build 1.0 (4),
which we have just uploaded, contains no weather functionality at all:

- The `com.apple.developer.weatherkit` entitlement has been removed from the app's
  entitlements file.
- `import WeatherKit` no longer appears anywhere in the source, and the shipped binary does
  not link the WeatherKit framework.
- Every feature that displayed forecast data has been removed with it: the daily tip above
  the camera button, and the forecast line and colour shown in the empty-slot sheet.

Because no Apple Weather data is displayed anywhere in the app, there is no WeatherKit
feature to record, and we have not attached a screen recording. We have added this
information to the App Review Information section of App Store Connect.

For clarity about what the app does draw: its forty-eight reference sky colours are computed
entirely on the device from the date, the user's approximate latitude and longitude, and the
sun's own schedule at that place (sunrise, solar noon, sunset, civil twilight), using our own
code and no network request. Location is still requested at kilometre accuracy for exactly
that purpose — working out when the sun rises and sets where the user is — and is never used
to request weather. Where the app describes a colour for a given hour, it states that it is
describing a clear sky, and it makes no claim about the actual weather.

The app's only network use is Apple's CloudKit, which syncs the user's own photographs to
their own iCloud account.

Please let us know if anything else would help.

Thank you.
