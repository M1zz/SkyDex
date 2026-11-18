# App Review 답장 — Guideline 2.1(b) 두 번째 (Pro 를 찾을 수 없음)

대상: 1.0.4 두 번째 리젝. 심사관이 "Support the Developer 의 팁 3개만 보인다" 고 답했다.

까닭: 심사관이 보낸 캡처의 설정 화면 버전이 **1.0.4 (8)** 이다. 빌드 8 에는 결제 화면이 없다
(빌드 8 의 설정에는 '구독 관리' 칸이 없고, iCloud 스위치에도 잠금 표시가 없다). 결제 화면은 빌드 10 에 있다.
즉 심사가 아직 빌드 8 로 돌았다.

순서:
1. App Store Connect ▸ 1.0.4 ▸ 빌드 칸이 **10** 인지 본다. 8 이면 10 으로 바꾼다.
2. 아래 영문을 심사 메시지에 답장으로 붙여 넣고 다시 제출한다.

---

Hello, and thank you for checking again.

We believe the review was done on an earlier build. The screenshot of Settings shows
Version 1.0.4 (8) at the bottom of the Support section. Build 8 was made before the purchase
screen was added, so it only contains the three tips under Support the Developer. The Plus and
Pro products are in build 1.0.4 (10), which is now selected for this version.

Please install build 10 and check that Settings shows Version 1.0.4 (10). Then:

1. Launch the app. The colour board appears.
2. Tap the list button at the bottom right, next to the round camera button. The Log screen opens.
3. Tap the gear at the top right. Settings opens.
4. Directly below the Storage section, there is a section titled "Manage Subscription".
   It is not present in build 8. It shows "Your plan: Free" and a button "See Plus · Pro".
5. Tap "See Plus · Pro". The purchase screen opens with a SkyDex Plus card and a SkyDex Pro card.
   Each card shows Yearly and Lifetime. Tap "Show Weekly and Monthly Too" to see Weekly and Monthly.

In build 10 the purchase screen also opens from:

- the "Also keep in iCloud" switch in Settings, which now has a Pro lock and opens the Pro card
  when turned on;
- the Palette and Repeats tabs on the Log screen, which open the Plus card.

The two remaining products appear only after an earlier purchase, so that no one pays twice:

- SkyDex Pro (Lifetime Upgrade): buy SkyDex Plus (Lifetime), then reopen the purchase screen.
  The Pro card's Lifetime option becomes "Upgrade to Pro Lifetime".
- SkyDex Pro (Lifetime) (Pro Graduate): start any Plus or Pro subscription, then open Settings
  again. A "Switch to Lifetime" row appears in the Manage Subscription section.

Restore Purchases and Redeem Code are in the same Manage Subscription section.

Thank you for your patience.
