#!/usr/bin/env python3
"""마케팅 스크린샷 목업 생성: HTML 생성 → 헤드리스 Chrome 렌더링.

슬라이드마다 layout 이 달라 배치가 다양함:
  hero-bleed  : 헤드라인 상단 중앙 + 정면 대형 폰, 하단 블리드
  left-text   : 좌측 정렬 텍스트 + 오른쪽으로 기운 폰
  text-bottom : 폰 상단 + 텍스트 하단
  flat-rotate : 평면 회전(-5°) 폰, 하단 블리드
  dark        : 다크 배경 반전 + 정면 폰
"""
import subprocess, sys, pathlib, time

# 하늘색 — 원본: docs/screenshots/raw/<스토어 로케일>/ (iPhone Pro Max 시뮬레이터 1320x2868)
# ko 는 하늘색 표의 색으로 만든 하늘 그림 24장을 사진 앱에서 골라 넣고 찍었다.
# 나머지 언어는 디버그 빌드의 데모 모드로 찍었다(SkyDex/Support/ScreenshotDemo.swift):
#   xcrun simctl launch <기기> com.leeo.SkyDex -SkyDexDemo -SkyDexDemoScreen board|reading|card|palette|empty \
#       -AppleLanguages "(en-GB)" -AppleLocale en_GB
#   01-board=board  02-name=reading  03-card=card  04-palette=palette  05-empty=empty
#
# 사용법: python3 scripts/make_marketing_screenshots.py [로케일 ...]   (없으면 전부)
import tempfile
ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "docs" / "screenshots" / "raw"
MARKETING = ROOT / "docs" / "screenshots" / "marketing"
WORK = pathlib.Path(tempfile.gettempdir())
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1242, 2688   # 이 계정의 iPhone 제출 규격

SHOTS_KO = [
    ("01-board.png",   "hero-bleed",  "오늘 하늘은<br>무슨 색이었나요", "하늘을 찍을 때마다 마흔여덟 칸이 채워져요"),
    ("02-name.png",    "left-text",   "하늘마다<br>닮은 이름이 붙어요", "살얼음색, 수영장 타일색, 홍시색"),
    ("03-card.png",    "text-bottom", "그 순간의 생각을<br>하늘 위에 적어요", "사진 한 장에 한 마디씩"),
    ("04-palette.png", "flat-rotate", "모은 색은<br>팔레트가 돼요", "파랑, 옅은 파랑, 누런 회색까지 갈래별로"),
    ("05-empty.png",   "dark",        "빈 칸은<br>언제 찾을지 알려줘요", "그 시간대 하늘이 어떤 색일지 미리 보여 줘요"),
]

# 언어마다 따로 쓴 문구. 02 · 04 의 부제는 앱 화면에 나오는 이름(번역본) 그대로다.
SHOTS_BY_LOCALE = {
    "en-US": [
        [
            "01-board.png",
            "What color was<br>the sky today?",
            "Every sky photo fills one of 48 circles"
        ],
        [
            "02-name.png",
            "Every sky gets<br>a name of its own",
            "Thin ice, Swimming-pool tile, Ripe persimmon"
        ],
        [
            "03-card.png",
            "Write a thought<br>on the sky",
            "One line for every photo"
        ],
        [
            "04-palette.png",
            "Your colors become<br>a palette",
            "Blue, Pale blue, Yellowish gray, and more"
        ],
        [
            "05-empty.png",
            "Empty circles<br>tell you when",
            "See what color the sky will be at that hour"
        ]
    ],
    "en-GB": [
        [
            "01-board.png",
            "What colour was<br>the sky today?",
            "Every sky photo fills one of 48 circles"
        ],
        [
            "02-name.png",
            "Every sky gets<br>a name of its own",
            "Thin ice, Swimming-pool tile, Ripe persimmon"
        ],
        [
            "03-card.png",
            "Write a thought<br>on the sky",
            "One line for every photo"
        ],
        [
            "04-palette.png",
            "Your colours turn<br>into a palette",
            "Blue, Pale blue, Yellowish grey and more"
        ],
        [
            "05-empty.png",
            "Empty circles<br>tell you when",
            "See what colour the sky will be at that hour"
        ]
    ],
    "ja": [
        [
            "01-board.png",
            "今日の空は<br>何色でしたか",
            "空を撮るたびに48の丸が埋まります"
        ],
        [
            "02-name.png",
            "空ごとに<br>似た色の名前を",
            "薄氷の色、プールのタイル色、熟柿の色"
        ],
        [
            "03-card.png",
            "その時の気持ちを<br>空に書きとめて",
            "写真一枚に、ひとこと"
        ],
        [
            "04-palette.png",
            "集めた色は<br>パレットになる",
            "青、淡い青、黄みの灰色まで系統別に"
        ],
        [
            "05-empty.png",
            "空いた丸が<br>探す時間を教えます",
            "その時間の空が何色か、先に見られます"
        ]
    ],
    "zh-Hans": [
        [
            "01-board.png",
            "今天的天空<br>是什么颜色",
            "每拍一张天空，就填上一个圆点，共48个"
        ],
        [
            "02-name.png",
            "每片天空<br>都有相似的名字",
            "薄冰色、泳池瓷砖色、熟柿子色"
        ],
        [
            "03-card.png",
            "把此刻的想法<br>写在天空上",
            "每张照片，写一句话"
        ],
        [
            "04-palette.png",
            "收集的颜色<br>汇成调色板",
            "蓝、浅蓝、黄灰，按色系归类"
        ],
        [
            "05-empty.png",
            "空着的圆点<br>告诉你何时去找",
            "提前看到那个时段天空的颜色"
        ]
    ],
    "zh-Hant": [
        [
            "01-board.png",
            "今天的天空<br>是什麼顏色",
            "每拍一張天空，就填上一個圓點，共48個"
        ],
        [
            "02-name.png",
            "每片天空<br>都有相似的名字",
            "薄冰色、泳池磁磚色、熟柿子色"
        ],
        [
            "03-card.png",
            "把此刻的想法<br>寫在天空上",
            "每張照片，寫一句話"
        ],
        [
            "04-palette.png",
            "收集的顏色<br>匯成調色盤",
            "藍、淺藍、黃灰，依色系歸類"
        ],
        [
            "05-empty.png",
            "空著的圓點<br>告訴你何時去找",
            "提前看到那個時段天空的顏色"
        ]
    ],
    "ru": [
        [
            "01-board.png",
            "Какого цвета<br>было небо сегодня",
            "Каждый снимок неба — один из 48 кружков"
        ],
        [
            "02-name.png",
            "У каждого неба<br>своё имя",
            "Тонкий лёд, плитка бассейна, спелая хурма"
        ],
        [
            "03-card.png",
            "Запишите мысль<br>прямо на небе",
            "Одна фраза к каждому снимку"
        ],
        [
            "04-palette.png",
            "Собранные цвета<br>станут палитрой",
            "Синий, голубой, желтовато-серый и другие"
        ],
        [
            "05-empty.png",
            "Пустой кружок<br>подскажет время",
            "Покажет, каким будет небо в этот час"
        ]
    ],
    "es-MX": [
        [
            "01-board.png",
            "¿De qué color<br>fue el cielo hoy?",
            "Cada foto llena uno de los 48 círculos"
        ],
        [
            "02-name.png",
            "Cada cielo recibe<br>un nombre",
            "Hielo delgado, azulejo de alberca, caqui maduro"
        ],
        [
            "03-card.png",
            "Escribe lo que<br>piensas en el cielo",
            "Una frase para cada foto"
        ],
        [
            "04-palette.png",
            "Tus colores forman<br>una paleta",
            "Azul, azul claro, gris amarillento y más"
        ],
        [
            "05-empty.png",
            "Cada círculo vacío<br>te dice cuándo",
            "Mira de qué color será el cielo a esa hora"
        ]
    ],
    "de-DE": [
        [
            "01-board.png",
            "Welche Farbe hatte<br>der Himmel heute?",
            "Jedes Foto füllt einen der 48 Kreise"
        ],
        [
            "02-name.png",
            "Jeder Himmel<br>trägt einen Namen",
            "Dünnes Eis, Schwimmbadfliese, Reife Kaki"
        ],
        [
            "03-card.png",
            "Schreib deinen<br>Gedanken dazu",
            "Ein Satz zu jedem Foto"
        ],
        [
            "04-palette.png",
            "Gesammelte Farben<br>werden zur Palette",
            "Blau, Hellblau, Gelbgrau und mehr"
        ],
        [
            "05-empty.png",
            "Leere Kreise<br>zeigen dir, wann",
            "Welche Farbe der Himmel dann haben wird"
        ]
    ],
    "fr-FR": [
        [
            "01-board.png",
            "De quelle couleur<br>était le ciel ?",
            "Chaque photo remplit l’un des 48 cercles"
        ],
        [
            "02-name.png",
            "Chaque ciel reçoit<br>son nom",
            "Fine glace, carrelage de piscine, kaki bien mûr"
        ],
        [
            "03-card.png",
            "Notez une pensée<br>sur le ciel",
            "Une phrase pour chaque photo"
        ],
        [
            "04-palette.png",
            "Vos couleurs<br>font une palette",
            "Bleu, bleu pâle, gris jaunâtre et d’autres"
        ],
        [
            "05-empty.png",
            "Un cercle vide<br>vous dit quand",
            "Découvrez la couleur du ciel à cette heure"
        ]
    ],
    "it": [
        [
            "01-board.png",
            "Di che colore<br>era il cielo oggi?",
            "Ogni foto riempie uno dei 48 cerchi"
        ],
        [
            "02-name.png",
            "Ogni cielo<br>ha il suo nome",
            "Ghiaccio sottile, piastrella di piscina, caco maturo"
        ],
        [
            "03-card.png",
            "Scrivi un pensiero<br>sul cielo",
            "Una frase per ogni foto"
        ],
        [
            "04-palette.png",
            "I colori raccolti<br>diventano palette",
            "Blu, azzurro, grigio giallastro e altri"
        ],
        [
            "05-empty.png",
            "I cerchi vuoti<br>ti dicono quando",
            "Vedi in anticipo il cielo di quell’ora"
        ]
    ],
    "pt-BR": [
        [
            "01-board.png",
            "De que cor estava<br>o céu hoje?",
            "Cada foto preenche um dos 48 círculos"
        ],
        [
            "02-name.png",
            "Cada céu ganha<br>um nome",
            "Gelo fino, azulejo de piscina, caqui maduro"
        ],
        [
            "03-card.png",
            "Deixe uma frase<br>sobre o céu",
            "Uma linha em cada foto"
        ],
        [
            "04-palette.png",
            "As cores coletadas<br>viram paleta",
            "Azul, azul-claro, cinza-amarelado e mais"
        ],
        [
            "05-empty.png",
            "Círculos vazios<br>dizem quando",
            "Veja como o céu estará naquele horário"
        ]
    ],
    "th": [
        [
            "01-board.png",
            "วันนี้ท้องฟ้า<br>เป็นสีอะไร",
            "ถ่ายฟ้าแต่ละครั้ง เติมวงกลม 1 ใน 48 วง"
        ],
        [
            "02-name.png",
            "ท้องฟ้าแต่ละภาพ<br>มีชื่อสีของตัวเอง",
            "สีน้ำแข็งบาง สีกระเบื้องสระว่ายน้ำ สีลูกพลับสุก"
        ],
        [
            "03-card.png",
            "เขียนความรู้สึก<br>ไว้บนท้องฟ้า",
            "หนึ่งภาพ หนึ่งประโยค"
        ],
        [
            "04-palette.png",
            "สีที่สะสม<br>กลายเป็นจานสี",
            "น้ำเงิน ฟ้าอ่อน เทาอมเหลือง แยกตามกลุ่มสี"
        ],
        [
            "05-empty.png",
            "วงกลมที่ว่าง<br>บอกเวลาที่ควรถ่าย",
            "ดูก่อนว่าฟ้าช่วงนั้นจะเป็นสีอะไร"
        ]
    ],
    "vi": [
        [
            "01-board.png",
            "Bầu trời hôm nay<br>màu gì?",
            "Mỗi lần chụp trời, một trong 48 ô được tô"
        ],
        [
            "02-name.png",
            "Mỗi bầu trời<br>có một tên màu",
            "Màu băng mỏng, màu gạch bể bơi, màu hồng chín mềm"
        ],
        [
            "03-card.png",
            "Ghi lại suy nghĩ<br>lên bầu trời",
            "Mỗi bức ảnh, một dòng"
        ],
        [
            "04-palette.png",
            "Màu đã sưu tầm<br>thành bảng màu",
            "Xanh lam, xanh nhạt, xám ngả vàng theo nhóm"
        ],
        [
            "05-empty.png",
            "Ô trống cho biết<br>khi nào nên tìm",
            "Xem trước bầu trời giờ đó sẽ có màu gì"
        ]
    ],
    "cs": [
        [
            "01-board.png",
            "Jakou barvu<br>mělo dnes nebe?",
            "Každá fotka vyplní jedno ze 48 koleček"
        ],
        [
            "02-name.png",
            "Každé nebe<br>dostane jméno",
            "Tenký led, bazénové dlaždičky, zralý kaki"
        ],
        [
            "03-card.png",
            "Napište k nebi<br>svou myšlenku",
            "Jedna věta ke každé fotce"
        ],
        [
            "04-palette.png",
            "Sesbírané barvy<br>tvoří paletu",
            "Modrá, světle modrá, nažloutle šedá a další"
        ],
        [
            "05-empty.png",
            "Prázdné kolečko<br>poradí, kdy hledat",
            "Ukáže, jaké bude nebe v tu dobu"
        ]
    ],
    "da": [
        [
            "01-board.png",
            "Hvilken farve havde<br>himlen i dag?",
            "Hvert billede fylder en af 48 cirkler"
        ],
        [
            "02-name.png",
            "Hver himmel<br>får sit eget navn",
            "Tynd is, svømmebassinflise, moden kaki"
        ],
        [
            "03-card.png",
            "Skriv en tanke<br>på himlen",
            "Én sætning til hvert billede"
        ],
        [
            "04-palette.png",
            "Dine farver<br>bliver til en palet",
            "Blå, lyseblå, gulgrå og flere"
        ],
        [
            "05-empty.png",
            "Tomme cirkler<br>fortæller hvornår",
            "Se himlens farve på det tidspunkt"
        ]
    ],
    "el": [
        [
            "01-board.png",
            "Τι χρώμα είχε<br>ο ουρανός σήμερα;",
            "Κάθε λήψη γεμίζει έναν από 48 κύκλους"
        ],
        [
            "02-name.png",
            "Κάθε ουρανός<br>παίρνει ένα όνομα",
            "Λεπτός πάγος, πλακάκι πισίνας, ώριμο λωτό"
        ],
        [
            "03-card.png",
            "Γράψε μια σκέψη<br>πάνω στον ουρανό",
            "Μία φράση για κάθε φωτογραφία"
        ],
        [
            "04-palette.png",
            "Τα χρώματά σου<br>γίνονται παλέτα",
            "Μπλε, απαλό μπλε, κιτρινωπό γκρι και άλλα"
        ],
        [
            "05-empty.png",
            "Ο άδειος κύκλος<br>σου λέει πότε",
            "Δες από πριν τι χρώμα θα έχει ο ουρανός"
        ]
    ],
    "fi": [
        [
            "01-board.png",
            "Minkä värinen<br>taivas oli tänään?",
            "Jokainen kuva täyttää yhden 48 ympyrästä"
        ],
        [
            "02-name.png",
            "Jokainen taivas<br>saa oman nimen",
            "Ohut jää, uima-altaan laatta, kypsä kaki"
        ],
        [
            "03-card.png",
            "Kirjoita ajatus<br>taivaan päälle",
            "Yksi lause jokaiseen kuvaan"
        ],
        [
            "04-palette.png",
            "Kerätyt värit<br>muuttuvat paletiksi",
            "Sininen, vaaleansininen, kellertävä harmaa"
        ],
        [
            "05-empty.png",
            "Tyhjä ympyrä<br>kertoo milloin",
            "Näet etukäteen, minkä värinen taivas on"
        ]
    ],
    "id": [
        [
            "01-board.png",
            "Apa warna langit<br>hari ini?",
            "Tiap foto mengisi satu dari 48 lingkaran"
        ],
        [
            "02-name.png",
            "Setiap langit<br>punya nama sendiri",
            "Es tipis, ubin kolam renang, kesemek matang"
        ],
        [
            "03-card.png",
            "Tulis isi hatimu<br>di atas langit",
            "Satu kalimat untuk setiap foto"
        ],
        [
            "04-palette.png",
            "Warnamu menjadi<br>sebuah palet",
            "Biru, biru pucat, kelabu kekuningan, dll."
        ],
        [
            "05-empty.png",
            "Lingkaran kosong<br>memberi tahu kapan",
            "Lihat dulu warna langit di jam itu"
        ]
    ],
    "nb": [
        [
            "01-board.png",
            "Hvilken farge var<br>himmelen i dag?",
            "Hvert bilde fyller én av 48 sirkler"
        ],
        [
            "02-name.png",
            "Hver himmel<br>får sitt eget navn",
            "Tynn is, bassengflis, moden kaki"
        ],
        [
            "03-card.png",
            "Skriv en tanke<br>på himmelen",
            "Én setning til hvert bilde"
        ],
        [
            "04-palette.png",
            "Fargene dine<br>blir en palett",
            "Blå, lyseblå, gulgrå og flere"
        ],
        [
            "05-empty.png",
            "Tomme sirkler<br>forteller når",
            "Se himmelens farge på det tidspunktet"
        ]
    ],
    "nl-NL": [
        [
            "01-board.png",
            "Welke kleur had<br>de lucht vandaag?",
            "Elke foto vult een van de 48 cirkels"
        ],
        [
            "02-name.png",
            "Elke lucht<br>krijgt een naam",
            "Dun ijs, zwembadtegel, rijpe kaki"
        ],
        [
            "03-card.png",
            "Schrijf je gedachte<br>op de lucht",
            "Eén zin bij elke foto"
        ],
        [
            "04-palette.png",
            "Je kleuren worden<br>een palet",
            "Blauw, lichtblauw, geelgrijs en meer"
        ],
        [
            "05-empty.png",
            "Lege cirkels<br>vertellen wanneer",
            "Zie vooraf welke kleur de lucht dan heeft"
        ]
    ],
    "pl": [
        [
            "01-board.png",
            "Jakiego koloru<br>było dziś niebo?",
            "Każde zdjęcie wypełnia jedno z 48 kółek"
        ],
        [
            "02-name.png",
            "Każde niebo<br>dostaje imię",
            "Cienki lód, płytki basenowe, dojrzały kaki"
        ],
        [
            "03-card.png",
            "Zapisz myśl<br>na niebie",
            "Jedno zdanie do każdego zdjęcia"
        ],
        [
            "04-palette.png",
            "Zebrane kolory<br>tworzą paletę",
            "Niebieski, jasnoniebieski, żółtawoszary"
        ],
        [
            "05-empty.png",
            "Puste kółko<br>podpowie, kiedy",
            "Zobacz, jakie niebo będzie o tej porze"
        ]
    ],
    "sv": [
        [
            "01-board.png",
            "Vilken färg hade<br>himlen i dag?",
            "Varje bild fyller en av 48 cirklar"
        ],
        [
            "02-name.png",
            "Varje himmel<br>får ett eget namn",
            "Tunn is, simbassängkakel, mogen kaki"
        ],
        [
            "03-card.png",
            "Skriv en tanke<br>på himlen",
            "En mening till varje bild"
        ],
        [
            "04-palette.png",
            "Dina färger<br>blir en palett",
            "Blått, ljusblått, gulgrått och fler"
        ],
        [
            "05-empty.png",
            "Tomma cirklar<br>berättar när",
            "Se i förväg vilken färg himlen får"
        ]
    ],
    "tr": [
        [
            "01-board.png",
            "Bugün gökyüzü<br>ne renkti?",
            "Her fotoğraf 48 daireden birini doldurur"
        ],
        [
            "02-name.png",
            "Her gökyüzüne<br>bir isim",
            "İnce buz, havuz fayansı, olgun hurma"
        ],
        [
            "03-card.png",
            "O anki düşünceni<br>göğe yaz",
            "Her fotoğrafa bir cümle"
        ],
        [
            "04-palette.png",
            "Topladığın renkler<br>palet olur",
            "Mavi, açık mavi, sarımsı gri ve dahası"
        ],
        [
            "05-empty.png",
            "Boş daire<br>zamanı söyler",
            "O saatteki gök rengini önceden gör"
        ]
    ]
}

LAYOUT_OF = {fname: layout for fname, layout, _, _ in SHOTS_KO}


def shots(locale):
    if locale == "ko":
        return SHOTS_KO
    return [(fname, LAYOUT_OF[fname], headline, sub) for fname, headline, sub in SHOTS_BY_LOCALE[locale]]


BASE_CSS = f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{W}px; height:{H}px; overflow:hidden; }}
body {{ background:#EEF4F8; font-family:system-ui, -apple-system, "Helvetica Neue", sans-serif; position:relative; }}
/* 한글 글꼴은 한국어에만. 다른 언어에 끼면 그리스어·베트남어의 악센트가 따로 놀아 글자가 깨진다. */
:lang(ko) body {{ font-family:-apple-system, "Apple SD Gothic Neo", sans-serif; }}
:lang(th) body {{ font-family:system-ui, "Thonburi", sans-serif; }}
:lang(ja) body {{ font-family:-apple-system, "Hiragino Sans", sans-serif; }}
:lang(zh-Hans) body {{ font-family:-apple-system, "PingFang SC", sans-serif; }}
:lang(zh-Hant) body {{ font-family:-apple-system, "PingFang TC", sans-serif; }}
.headline {{ font-size:100px; font-weight:800; color:#1B2733; letter-spacing:-2px; line-height:1.2; }}
.sub {{ font-size:52px; font-weight:500; color:#6F7E90; letter-spacing:-1px; padding:0 60px; }}
:lang(ko) .headline, :lang(ko) .sub {{ word-break:keep-all; }}
.phone {{ background:#17171a; border-radius:116px; border:3px solid #3a3a3e; padding:25px;
  box-shadow: 60px 90px 120px rgba(0,0,0,.28), 20px 30px 50px rgba(0,0,0,.18); }}
.phone img {{ width:100%; display:block; border-radius:92px; }}
"""

LAYOUTS = {
    # 1) 정면 대형, 하단 블리드
    "hero-bleed": """
.headline { text-align:center; margin-top:290px; padding:0 70px; }
.sub { text-align:center; margin-top:52px; }
.wrap { display:flex; justify-content:center; margin-top:150px; }
.phone { width:1000px; }
""",
    # 2) 좌측 정렬 텍스트 + 오른쪽 기울기, 오른쪽 블리드
    "left-text": """
.headline { text-align:left; margin:300px 0 0 110px; }
.sub { text-align:left; margin:48px 0 0 114px; }
.wrap { perspective:2600px; perspective-origin:30% 30%; position:absolute; left:300px; top:990px; }
.phone { width:840px; transform:rotateY(16deg) rotateX(2deg); }
""",
    # 3) 폰 상단, 텍스트 하단
    "text-bottom": """
.wrap { perspective:2800px; perspective-origin:50% 40%; display:flex; justify-content:center; margin-top:170px; }
.phone { width:880px; transform:rotateY(-10deg) rotateX(2deg); }
.headline { text-align:center; margin-top:120px; padding:0 70px; }
.sub { text-align:center; margin-top:48px; }
""",
    # 4) 평면 회전, 좌측 치우침 + 하단 블리드
    "flat-rotate": """
.headline { text-align:center; margin-top:270px; padding:0 70px; }
.sub { text-align:center; margin-top:52px; }
.wrap { position:absolute; left:120px; top:1010px; }
.phone { width:1010px; transform:rotate(-6deg); }
""",
    # 5) 다크 배경 반전 + 정면
    "dark": """
body { background:#131316; }
.headline { color:#f5f5f7; text-align:center; margin-top:290px; padding:0 70px; }
.sub { color:#77777d; text-align:center; margin-top:52px; }
.wrap { display:flex; justify-content:center; margin-top:150px; }
.phone { width:930px; border-color:#48484e;
  box-shadow: 0 0 160px rgba(80,140,255,.22), 40px 70px 110px rgba(0,0,0,.55); }
""",
}

# text-bottom 은 폰이 먼저 오는 DOM 순서
BODY_TEXT_FIRST = '<div class="headline">{headline}</div><div class="sub">{sub}</div><div class="wrap"><div class="phone"><img src="{img}"></div></div>'
BODY_PHONE_FIRST = '<div class="wrap"><div class="phone"><img src="{img}"></div></div><div class="headline">{headline}</div><div class="sub">{sub}</div>'

HTML = """<!doctype html><html lang="{lang}"><head><meta charset="utf-8"><style>
{base}{layout}
</style></head><body>{body}</body></html>"""

def main(locale):
    src, out = RAW / locale, MARKETING / locale
    out.mkdir(parents=True, exist_ok=True)
    for fname, layout, headline, sub in shots(locale):
        body_tpl = BODY_PHONE_FIRST if layout == "text-bottom" else BODY_TEXT_FIRST
        body = body_tpl.format(headline=headline, sub=sub, img=(src / fname).as_uri())
        html_path = WORK / f"skydex-{locale}-{fname.replace('.png', '.html')}"
        html_path.write_text(HTML.format(lang=locale, base=BASE_CSS, layout=LAYOUTS[layout], body=body), encoding="utf-8")
        out_png = out / fname
        # Chrome 은 다른 창과 겹치면 가끔 실패한다 — 따로 쓰는 프로필로 세 번까지
        for _ in range(3):
            try:
                r = subprocess.run([CHROME, "--headless=new", f"--screenshot={out_png}",
                                    f"--window-size={W},{H}", "--force-device-scale-factor=1",
                                    "--hide-scrollbars", "--disable-gpu", "--virtual-time-budget=3000",
                                    "--allow-file-access-from-files", html_path.as_uri()],
                                   capture_output=True, timeout=120)
            except subprocess.TimeoutExpired:
                continue
            if r.returncode == 0:
                break
        else:
            raise SystemExit(f"Chrome 이 그리지 못했다: {out_png}")
        print(f"rendered {out_png}")
        time.sleep(2)

if __name__ == "__main__":
    for locale in sys.argv[1:] or ["ko", *SHOTS_BY_LOCALE]:
        main(locale)
        time.sleep(2)  # 맥을 같이 쓰므로 한 장씩 천천히
