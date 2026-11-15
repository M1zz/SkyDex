# App Review 답장 — Guideline 2.1(b) (인앱결제를 찾을 수 없음)

Submission ID: 0785d57d-74f7-4e02-94ba-c6fd9142a277
대상: 1.0.4 (8) 리젝. **페이월이 든 새 빌드(1.0.4 (10))를 DeployBar 로 올린 뒤** 보낸다.

까닭: 빌드 8 은 페이월 커밋(23d0b93) 전에 만든 빌드라 앱 안에 결제 코드가 없었다.
그런데 상품 10개가 그 제출에 붙어 나갔고, 심사 노트도 "인앱결제 없음" 이었다.

순서:
1. App Store Connect ▸ 1.0.4 ▸ 빌드를 10 으로 바꾼다 (DeployBar 배포가 한다).
2. App Review Information ▸ Notes 를 `app-review-notes.md` 의 영문 블록으로 바꾼다.
3. 아래 영문을 심사 메시지에 답장으로 붙여 넣는다.

---

Hello, and thank you for the review.

We are sorry for the confusion. Build 1.0.4 (8) was built before the purchase screen was added
to the app, so the In-App Purchases attached to that submission could not be found in it. We
have uploaded build 1.0.4 (10), which contains the purchase screen, and selected it for this
version. We have also updated the App Review Information notes with the steps below.

All products are Apple In-App Purchases. They are not restricted by storefront, device, or
any account of ours, and they are offered to every user, including in the review sandbox.

To open the purchase screen:

1. Launch the app. The colour board appears.
2. Tap the list button at the bottom right, next to the round camera button. The Log screen opens.
3. Tap the gear at the top right. Settings opens.
4. In the Manage Subscription section, tap "See Plus · Pro".

The screen shows a SkyDex Plus card and a SkyDex Pro card. Each card shows Yearly and Lifetime;
tap "Show Weekly and Monthly Too" to see Weekly and Monthly. This covers:

- SkyDex Plus (Weekly), (Monthly), (Yearly), (Lifetime)
- SkyDex Pro (Weekly), (Monthly), (Yearly)
- SkyDex Pro (Lifetime) (Pro Lifetime)

Two products are only offered after an earlier purchase, so that no one pays twice:

- SkyDex Pro (Lifetime Upgrade): buy SkyDex Plus (Lifetime), then reopen the purchase screen.
  The Pro card's Lifetime option becomes "Upgrade to Pro Lifetime" and sells this product.
- SkyDex Pro (Lifetime) (Pro Graduate): start any Plus or Pro subscription, then open Settings
  again. A "Switch to Lifetime" row appears in Manage Subscription and offers this product.

The purchase screen also opens from the locked features themselves: the Palette and Repeats
tabs on the Log screen (Plus), and the "Also keep in iCloud" switch in Settings (Pro).
Restore Purchases and Redeem Code are in the same section of Settings.

Please let us know if anything else would help.

Thank you.
