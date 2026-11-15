#!/bin/sh
# 배포 전 검사. 실패하면 0이 아닌 값으로 끝나 배포를 멈춘다.
#
# 이 프로젝트에는 테스트 타겟이 없다. 그래서 지금 이 스크립트가 보장하는
# 것은 "릴리즈 설정으로 두 타겟이 경고 없이 컴파일된다"까지다. 테스트
# 타겟이 생기면 아래에서 자동으로 잡아 `xcodebuild test` 까지 돌린다.
set -eu

cd "$(dirname "$0")/.."

# 심사 노트가 파는 상품을 다 말하는가. 1.0.4 (8) 은 노트가 "인앱결제 없음" 인 채로
# 상품만 붙어 나가 2.1(b) 로 막혔다. 상품을 늘리면 노트의 7번(어디서 사는가)도 같이 고친다.
missing=$(grep -o '"productID" : "[^"]*"' SkyDex/Products.storekit | cut -d'"' -f4 |
    while read -r id; do grep -qF "$id" app-review-notes.md || echo "$id"; done)
if [ -n "$missing" ]; then
    echo "predeploy: app-review-notes.md 7번에 없는 상품 — 어디서 사는지 적을 것:" >&2
    echo "$missing" >&2
    exit 1
fi

PROJECT="SkyDex.xcodeproj"
SCHEME="${SCHEME:-SkyDex}"
DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"

if xcodebuild -project "$PROJECT" -list 2>/dev/null | sed -n '/Targets:/,/^$/p' | grep -qi "tests"; then
    echo "predeploy: 테스트 실행 ($SCHEME)"
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION" -quiet test
else
    echo "predeploy: 테스트 타겟이 없어 릴리즈 빌드만 확인한다 ($SCHEME)"
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
        -destination "generic/platform=iOS" -quiet \
        CODE_SIGNING_ALLOWED=NO build
fi

echo "predeploy: 통과"
