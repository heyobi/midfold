# Builds Midfold/Localizable.xcstrings (English source, Turkish translations) and lists UI literals with no translation.
# Usage: python -X utf8 scripts/strings.py
import glob
import json
import re

TR = {
    # Home
    'Midfold': 'Midfold',
    'Games you play with the fold': 'Katlayarak oynanan oyunlar',
    'Fold games': 'Katlama oyunları',
    'Face-to-face duels': 'Karşılıklı düellolar',
    'The hinge is the controller. Open the phone halfway and play.': 'Menteşe oyun kolunuz. Telefonu yarıya kadar açın ve oynayın.',
    'Made for the iPhone Duo hinge. Here you play by tilting or with a slider.': 'iPhone Duo menteşesi için tasarlandı. Burada eğerek ya da kaydırıcıyla oynarsınız.',
    'Lay the phone open flat between you. Each of you gets one half; the fold is the line.': 'Telefonu aranıza düz açık bırakın. Her birinize bir yarı düşer; katlama çizgisi sınırdır.',
    'Lay the phone between you. Each of you gets one half of the screen.': 'Telefonu aranıza koyun. Ekranın bir yarısı sizin, diğer yarısı rakibinizin.',
    'Settings': 'Ayarlar',
    'Close': 'Kapat',
    # Games
    'Fold Flight': 'Katla Uç',
    'Angle Lock': 'Açı Kilidi',
    'Quick Draw': 'Hızlı Dokun',
    'Tug Line': 'Halat Çek',
    'Odd Spot': 'Farklıyı Bul',
    'Steer a paper glider through the gaps by opening and closing the phone.': 'Telefonu açıp kapatarak kâğıt uçağı boşluklardan geçirin.',
    'Hit eight target angles and hold steady. Beat your best time.': 'Sekiz hedef açıyı yakalayın ve sabit tutun. Rekorunuzu geçin.',
    'Wait for the signal, then tap first. Too early and the point goes across.': 'İşareti bekleyin, sonra ilk siz dokunun. Erken dokunursanız sayı rakibe gider.',
    'Tap like mad to pull the knot over the fold to your side.': 'Düğümü katlama çizgisinin üstünden kendi tarafınıza çekmek için hızla dokunun.',
    'Find the one symbol that is different before your rival does.': 'Farklı olan tek simgeyi rakibinizden önce bulun.',
    # Settings
    'Haptics': 'Titreşim',
    'Controller': 'Kontrol',
    'Fold games control': 'Katlama oyunu kontrolü',
    'Tilt': 'Eğme',
    'Slider': 'Kaydırıcı',
    'iPhone Duo hinge': 'iPhone Duo menteşesi',
    "Fold games read the angle of your iPhone Duo's hinge.": 'Katlama oyunları iPhone Duo menteşenizin açısını okur.',
    'On iPhone Duo the fold games use the hinge. On this device, tilt it toward you or use the slider.': 'iPhone Duo\'da katlama oyunları menteşeyle oynanır. Bu cihazda telefonu kendinize doğru eğin ya da kaydırıcıyı kullanın.',
    'Version': 'Sürüm',
    'No accounts, no ads, no tracking. Everything stays on this device.': 'Hesap yok, reklam yok, izleme yok. Her şey bu cihazda kalır.',
    'Source code and privacy': 'Kaynak kodu ve gizlilik',
    'Done': 'Bitti',
    # Fold Flight
    'Best %lld': 'Rekor %lld',
    'Crashed!': 'Çarptın!',
    'New best!': 'Yeni rekor!',
    'Open wider to climb, close to dive.': 'Yükselmek için açın, alçalmak için kapatın.',
    'Slide up to climb, down to dive.': 'Yükselmek için yukarı, alçalmak için aşağı kaydırın.',
    'Tilt toward you to climb, lay it back to dive.': 'Yükselmek için kendinize doğru eğin, alçalmak için geri yatırın.',
    'Tap to fly': 'Uçmak için dokunun',
    'Tap to fly again': 'Tekrar uçmak için dokunun',
    # Angle Lock
    'Best %@': 'Rekor %@',
    'Fold the phone to each target angle and hold it.': 'Telefonu her hedef açıya getirin ve öyle tutun.',
    'Set each target angle and hold it.': 'Her hedef açıyı ayarlayın ve öyle tutun.',
    'Tap to start': 'Başlamak için dokunun',
    'Target %lld°': 'Hedef %lld°',
    'All locked!': 'Hepsi kilitlendi!',
    'Tap to play again': 'Tekrar oynamak için dokunun',
    'Angle': 'Açı',
    'Angle %lld degrees': 'Açı %lld derece',
    '%lld degrees': '%lld derece',
    # Duels
    'Blue': 'Mavi',
    'Orange': 'Turuncu',
    'Tap when you are ready': 'Hazır olunca dokunun',
    'Waiting for the other player…': 'Diğer oyuncu bekleniyor…',
    'Wait…': 'Bekle…',
    'Tap the moment it turns green': 'Yeşile döndüğü anda dokunun',
    'TAP!': 'DOKUN!',
    'Point!': 'Sayı!',
    'They tapped too early': 'Rakip erken dokundu',
    '%lld ms': '%lld ms',
    'Too early!': 'Çok erken!',
    'Too slow': 'Geç kaldın',
    'You win!': 'Kazandın!',
    'You lose': 'Kaybettin',
    'Pull!': 'Çek!',
    'Pull harder!': 'Daha hızlı çek!',
    'Tap tap tap': 'Dokun dokun dokun',
    'Round to you!': 'Tur senin!',
    'Round lost': 'Turu kaybettin',
    'Tap for the next round': 'Sonraki tur için dokunun',
    'Frozen!': 'Dondun!',
    'Wrong one': 'Yanlış simge',
    'Found it!': 'Buldun!',
    'Find the odd one out. Tap when you are ready': 'Farklı olanı bul. Hazır olunca dokunun',
}

# Literals that are not UI text (symbols, keys, file names, formats).
IGNORE = re.compile(r'^(|[ ]|[a-z0-9.]+(\.[a-z0-9.]+)*|.*\\\(.*|%.*|[%@×·—•:°–]+.*|-shots.*|\d-.*|Logo|AccentColor|CFBundleShortVersionString|https?://.*|ready|next|done|shots|control|haptics|best\..*|@.*|.*\{.*)$')

found = set()
for f in glob.glob('Midfold/**/*.swift', recursive=True):
    for line in open(f, encoding='utf-8'):
        for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', line):
            found.add(m.group(1))
missing = sorted(s for s in found if s not in TR and not IGNORE.match(s))
print('untranslated literals:', missing)

strings = {}
for k, v in TR.items():
    strings[k] = {'localizations': {'tr': {'stringUnit': {'state': 'translated', 'value': v}}}}
cat = {'sourceLanguage': 'en', 'strings': dict(sorted(strings.items())), 'version': '1.0'}
json.dump(cat, open('Midfold/Localizable.xcstrings', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print(len(strings), 'strings written')
