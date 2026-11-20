# Builds Midfold/Localizable.xcstrings (English source, Turkish translations) and lists UI literals with no translation.
# Usage: python -X utf8 scripts/strings.py
import glob
import json
import re

TR = {
    # Home
    'Midfold': 'Midfold',
    'Pump the hinge to fly': 'Uçmak için menteşeyi pompalayın',
    'A paper bird, one flap at a time': 'Kâğıt bir kuş, her seferinde bir kanat çırpışı',
    'Play': 'Oyna',
    'Continue %@': 'Devam et %@',
    'Daily flight': 'Günün uçuşu',
    'A new course every day, the same for everyone.': 'Her gün yeni bir parkur, herkes için aynı.',
    "Today's best %lld": 'Bugünün rekoru %lld',
    'Endless': 'Sonsuz',
    'How far can Kip go? It only gets harder.': 'Kip ne kadar uzağa gidebilir? Gittikçe zorlaşır.',
    'Best %lld': 'Rekor %lld',
    'Made for iPhone Duo: hold it sideways, half open, and pump the hinge.': 'iPhone Duo için tasarlandı: yan tutun, yarıya kadar açın ve menteşeyi pompalayın.',
    'Made for iPhone Duo, where you fly by pumping the hinge. Here, tap to flap.': 'iPhone Duo için tasarlandı; orada menteşeyi pompalayarak uçarsınız. Burada kanat çırpmak için dokunun.',
    'Leaderboards': 'Sıralamalar',
    'Settings': 'Ayarlar',
    'Paper Meadow': 'Kâğıt Çayır',
    'Gusty Cliffs': 'Rüzgârlı Yamaçlar',
    'Ink Caves': 'Mürekkep Mağaraları',
    'Rolling hills and paper gates. Learn the rhythm.': 'Dalgalı tepeler ve kâğıt kapılar. Ritmi öğrenin.',
    'Up- and downdrafts and gates that slide.': 'Yukarı ve aşağı esen rüzgârlar, kayan kapılar.',
    'Narrow tunnels that need gentle pumps.': 'Nazik pompalar isteyen dar tüneller.',
    'Unlock': 'Kilidi aç',
    'Level %@': 'Bölüm %@',
    '%lld of 3 stars': '3 yıldızdan %lld',
    'Locked': 'Kilitli',
    # Settings
    'Sound': 'Ses',
    'Haptics': 'Titreşim',
    'Pump sensitivity': 'Pompa hassasiyeti',
    'Try it': 'Deneyin',
    'iPhone Duo hinge': 'iPhone Duo menteşesi',
    'Higher sensitivity makes small pumps flap harder. Without a hinge, tap to flap.': 'Yüksek hassasiyette küçük pompalar da güçlü kanat çırpar. Menteşe yoksa kanat çırpmak için dokunun.',
    'All worlds unlocked': 'Tüm dünyaların kilidi açık',
    'Unlock all worlds': 'Tüm dünyaların kilidini aç',
    'Restore purchases': 'Satın alımları geri yükle',
    'Leaderboards and achievements': 'Sıralamalar ve başarımlar',
    'Version': 'Sürüm',
    'No accounts, no ads, no tracking. Your progress stays on this device; Game Center is optional.': 'Hesap yok, reklam yok, izleme yok. İlerlemeniz bu cihazda kalır; Game Center isteğe bağlıdır.',
    'Source code and privacy': 'Kaynak kodu ve gizlilik',
    'Done': 'Bitti',
    'OK': 'Tamam',
    # Paywall
    'Gusty Cliffs: drafts and sliding gates': 'Rüzgârlı Yamaçlar: rüzgârlar ve kayan kapılar',
    'Ink Caves: tunnels that need gentle pumps': 'Mürekkep Mağaraları: nazik pompa isteyen tüneller',
    'Endless mode with a leaderboard': 'Sıralamalı sonsuz mod',
    'One purchase, no subscription, no ads': 'Tek seferlik satın alma, abonelik yok, reklam yok',
    'Unlocked. Have fun!': 'Kilit açıldı. İyi eğlenceler!',
    'Unlock for %@': '%@ karşılığında aç',
    'Not now': 'Şimdi değil',
    'The store is not available right now. Try again later.': 'Mağazaya şu anda ulaşılamıyor. Daha sonra yeniden deneyin.',
    'The purchase is waiting for approval.': 'Satın alma onay bekliyor.',
    'The purchase did not go through. Nothing was charged.': 'Satın alma tamamlanmadı. Ücret alınmadı.',
    'All worlds are unlocked.': 'Tüm dünyaların kilidi açıldı.',
    'No earlier purchase was found for this Apple Account.': 'Bu Apple Hesabında önceki bir satın alma bulunamadı.',
    # Game
    'Pause': 'Duraklat',
    'Paused': 'Duraklatıldı',
    'Resume': 'Devam',
    'Restart': 'Yeniden başla',
    'Menu': 'Menü',
    'Daily': 'Günlük',
    'Flight': 'Uçuş',
    'Pump the hinge or tap to flap': 'Kanat çırpmak için menteşeyi pompalayın ya da dokunun',
    'Tap to flap': 'Kanat çırpmak için dokunun',
    'Tap to fly': 'Uçmak için dokunun',
    'Best played sideways': 'Yan tutarak oynayın',
    'Run over': 'Uçuş bitti',
    'Level complete!': 'Bölüm tamam!',
    'New best!': 'Yeni rekor!',
    'Next level': 'Sonraki bölüm',
    'Retry': 'Tekrar',
    'Out of feathers': 'Tüyler bitti',
    '%lld%% of the way': 'Yolun %%%lld kadarı',
    'Or pump the hinge to fly again': 'Ya da yeniden uçmak için menteşeyi pompalayın',
    '%lld feathers left': '%lld tüy kaldı',
    'Progress %lld percent': 'İlerleme yüzde %lld',
    '%lld of 3 stars': '3 yıldızdan %lld',
    'Hinge angle %lld degrees': 'Menteşe açısı %lld derece',
    'Pump to flap': 'Pompala, kanat çırp',
    'Hold the phone sideways, half open. Close it a little and open it again: every pump is a wing flap.': 'Telefonu yan tutun, yarıya kadar açık. Biraz kapatıp yeniden açın: her pompa bir kanat çırpışı.',
    'Quick, deep pumps flap hard. Small pumps make small hops, perfect for tunnels.': 'Hızlı ve derin pompalar güçlü çırpar. Küçük pompalar küçük sıçramalar yapar; tüneller için ideal.',
    'Tap anywhere to flap. Kip sinks between flaps, so find a rhythm.': 'Kanat çırpmak için herhangi bir yere dokunun. Kip çırpışlar arasında alçalır, ritmi yakalayın.',
    'On iPhone Duo you pump the hinge instead.': "iPhone Duo'da bunun yerine menteşeyi pompalarsınız.",
    'Got it': 'Anladım',
}

# Literals that are not UI text (symbols, keys, file names, formats).
IGNORE = re.compile(r'^(|[ ]|midfold\..*|com\.heyobi.*|.*\.wav|sound|sensitivity|unlocked|progress|[a-z0-9.]+(\.[a-z0-9.]+)*|.*\\\(.*|%.*|[%@×·—•:°–]+.*|-shots.*|\d-.*|Logo|AccentColor|CFBundleShortVersionString|https?://.*|ready|next|done|shots|control|haptics|best\..*|@.*|.*\{.*)$')

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
