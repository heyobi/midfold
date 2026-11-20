# Writes store/listing.json (App Store name, subtitle, keywords, promo text, description) for 5 locales and checks Apple's limits.
# Usage: python -X utf8 scripts/listing.py
import json

L = {}

L['en-US'] = dict(
    name='Midfold: Pump to Fly',
    subtitle='Fold your phone, flap & glide',
    keywords='foldable,hinge,bird,wings,flap,paper,origami,arcade,glider,tap,casual,levels,endless,daily',
    promo='Made for iPhone Duo: hold it sideways and pump the hinge. Every close-and-open is a wing flap. Quick and deep flaps hard, small pumps make small hops.',
    description="""Pump the hinge to fly. Midfold is an arcade flight made for iPhone Duo: hold the phone sideways, half open, and close-then-open it. Every pump is a wing flap for Kip, a little bird folded from paper.

QUICK PUMP, BIG FLAP
A quick, deep pump flaps hard. A small, slow one is a gentle hop. Kip sinks between flaps, so you fly by rhythm and strength: big flaps over tall walls, tiny ones through tight tunnels.

THREE PAPER WORLDS
• Paper Meadow: rolling hills and paper gates. Learn the rhythm.
• Gusty Cliffs: updrafts, downdrafts and gates that slide.
• Ink Caves: narrow tunnels that need the gentlest pumps.
18 hand-tuned levels with three stars each, and three feathers per run so a bump is not the end.

ENDLESS AND DAILY
How far can Kip go? Endless keeps getting harder. The daily flight is a new course every day, the same for everyone.

FEELS GOOD
Haptics that follow every flap, paper-whoosh sounds, parallax worlds, confetti and a quick restart. Game Center leaderboards and achievements.

ON EVERY IPHONE AND IPAD
No hinge? Tap to flap, with the same physics.

FAIR
Paper Meadow and the daily flight are free. One purchase unlocks the other worlds and Endless. No ads, no subscription, no tracking.""")

L['tr'] = dict(
    name='Midfold: Pompala ve Uç',
    subtitle='Telefonu katla, kanat çırp',
    keywords='katlanabilir,menteşe,kuş,kanat,kağıt,origami,arcade,uçuş,dokun,bölüm,sonsuz,günlük,refleks',
    promo="iPhone Duo için: telefonu yan tutun ve menteşeyi pompalayın. Her kapat-aç bir kanat çırpışı. Hızlı ve derin pompa güçlü, küçük pompa küçük sıçrama.",
    description="""Uçmak için menteşeyi pompalayın. Midfold, iPhone Duo için tasarlanmış bir arcade uçuş oyunu: telefonu yan tutun, yarıya kadar açın, biraz kapatıp yeniden açın. Her pompa, kâğıttan katlanmış küçük kuş Kip için bir kanat çırpışı.

HIZLI POMPA, GÜÇLÜ ÇIRPIŞ
Hızlı ve derin bir pompa güçlü çırpar. Küçük ve yavaş bir pompa nazik bir sıçramadır. Kip çırpışlar arasında alçalır; ritim ve güçle uçarsınız: yüksek duvarlar için büyük, dar tüneller için minik çırpışlar.

ÜÇ KÂĞIT DÜNYA
• Kâğıt Çayır: dalgalı tepeler ve kâğıt kapılar. Ritmi öğrenin.
• Rüzgârlı Yamaçlar: yukarı ve aşağı esen rüzgârlar, kayan kapılar.
• Mürekkep Mağaraları: en nazik pompaları isteyen dar tüneller.
Her biri üç yıldızlı 18 bölüm; her uçuşta üç tüy, yani bir çarpma oyunun sonu değil.

SONSUZ VE GÜNLÜK
Kip ne kadar uzağa gidebilir? Sonsuz mod gittikçe zorlaşır. Günün uçuşu her gün yeni bir parkur, herkes için aynı.

İYİ HİSSETTİRİR
Her çırpışa eşlik eden titreşim, kâğıt hışırtısı sesleri, katmanlı dünyalar, konfeti ve hızlı yeniden başlama. Game Center sıralamaları ve başarımları.

HER IPHONE VE IPAD'DE
Menteşe yok mu? Aynı fizikle dokunarak kanat çırpın.

ADİL
Kâğıt Çayır ve günün uçuşu ücretsiz. Tek bir satın alma diğer dünyaların ve Sonsuz modun kilidini açar. Reklam yok, abonelik yok, izleme yok.""")

L['es-MX'] = dict(
    name='Midfold: Bombea y vuela',
    subtitle='Dobla tu celular y aletea',
    keywords='plegable,bisagra,pajaro,aletear,papel,origami,arcade,planeador,tocar,niveles,infinito,diario',
    promo='Hecho para iPhone Duo: sostenlo de lado y bombea la bisagra. Cada cerrar y abrir es un aleteo. Rápido y profundo aletea fuerte; poco, un saltito.',
    description="""Bombea la bisagra para volar. Midfold es un juego arcade de vuelo hecho para iPhone Duo: sostén el teléfono de lado, medio abierto, y ciérralo un poco y vuelve a abrirlo. Cada bombeo es un aleteo de Kip, un pajarito doblado en papel.

BOMBEO RÁPIDO, ALETEO FUERTE
Un bombeo rápido y profundo aletea fuerte. Uno pequeño y lento es un saltito suave. Kip baja entre aleteos: vuelas con ritmo y fuerza, aleteos grandes sobre muros altos y diminutos por túneles estrechos.

TRES MUNDOS DE PAPEL
• Paper Meadow: colinas y puertas de papel. Aprende el ritmo.
• Gusty Cliffs: corrientes de aire y puertas que se deslizan.
• Ink Caves: túneles estrechos que piden bombeos suaves.
18 niveles con tres estrellas cada uno y tres plumas por intento.

SIN FIN Y DIARIO
¿Hasta dónde llega Kip? El modo sin fin se pone cada vez más difícil. El vuelo diario es un recorrido nuevo cada día, igual para todos.

SE SIENTE BIEN
Vibración en cada aleteo, sonidos de papel, mundos con paralaje y reinicio rápido. Clasificaciones y logros de Game Center.

EN CUALQUIER IPHONE Y IPAD
¿Sin bisagra? Toca para aletear, con la misma física.

JUSTO
Paper Meadow y el vuelo diario son gratis. Una compra desbloquea los demás mundos y el modo sin fin. Sin anuncios, sin suscripción, sin rastreo.""")

L['pt-BR'] = dict(
    name='Midfold: Bombeie e voe',
    subtitle='Dobre o celular e bata asas',
    keywords='dobravel,dobradica,passaro,asas,papel,origami,arcade,planador,toque,fases,infinito,diario',
    promo='Feito para iPhone Duo: segure de lado e bombeie a dobradiça. Cada fechar e abrir é uma batida de asas. Rápido e fundo bate forte; pouco, um pulinho.',
    description="""Bombeie a dobradiça para voar. Midfold é um jogo arcade de voo feito para iPhone Duo: segure o celular de lado, meio aberto, feche um pouco e abra de novo. Cada bombeada é uma batida de asas do Kip, um passarinho dobrado em papel.

BOMBEADA RÁPIDA, BATIDA FORTE
Uma bombeada rápida e funda bate forte. Uma pequena e lenta é um pulinho suave. O Kip desce entre as batidas: você voa com ritmo e força, batidas grandes sobre muros altos e pequenas em túneis apertados.

TRÊS MUNDOS DE PAPEL
• Paper Meadow: colinas e portões de papel. Aprenda o ritmo.
• Gusty Cliffs: correntes de vento e portões que deslizam.
• Ink Caves: túneis estreitos que pedem bombeadas suaves.
18 fases com três estrelas cada e três penas por tentativa.

INFINITO E DIÁRIO
Até onde o Kip vai? O modo infinito fica cada vez mais difícil. O voo diário é um percurso novo todo dia, igual para todos.

GOSTOSO DE JOGAR
Vibração em cada batida, sons de papel, mundos com paralaxe e recomeço rápido. Placares e conquistas do Game Center.

EM QUALQUER IPHONE E IPAD
Sem dobradiça? Toque para bater as asas, com a mesma física.

JUSTO
Paper Meadow e o voo diário são grátis. Uma compra libera os outros mundos e o modo infinito. Sem anúncios, sem assinatura, sem rastreamento.""")

L['de-DE'] = dict(
    name='Midfold: Pumpen und fliegen',
    subtitle='Falten, pumpen, fliegen',
    keywords='faltbar,scharnier,vogel,flattern,papier,origami,arcade,gleiter,tippen,level,endlos,täglich',
    promo='Für das iPhone Duo: quer halten und das Scharnier pumpen. Jedes Zu-und-auf ist ein Flügelschlag. Schnell und tief schlägt kräftig, wenig macht kleine Hüpfer.',
    description="""Pump das Scharnier, um zu fliegen. Midfold ist ein Arcade-Flugspiel für das iPhone Duo: Halte das Telefon quer, halb aufgeklappt, schließ es ein Stück und öffne es wieder. Jedes Pumpen ist ein Flügelschlag für Kip, einen kleinen Vogel aus gefaltetem Papier.

SCHNELL GEPUMPT, KRÄFTIG GESCHLAGEN
Schnell und tief pumpen schlägt kräftig. Klein und langsam ist ein sanfter Hüpfer. Kip sinkt zwischen den Schlägen: Du fliegst mit Rhythmus und Kraft, große Schläge über hohe Wände, winzige durch enge Tunnel.

DREI PAPIERWELTEN
• Paper Meadow: sanfte Hügel und Papiertore. Lerne den Rhythmus.
• Gusty Cliffs: Auf- und Abwinde und gleitende Tore.
• Ink Caves: enge Tunnel, die sanftestes Pumpen verlangen.
18 Level mit je drei Sternen und drei Federn pro Versuch.

ENDLOS UND TÄGLICH
Wie weit kommt Kip? Endlos wird immer schwerer. Der Tagesflug ist jeden Tag eine neue Strecke, für alle gleich.

FÜHLT SICH GUT AN
Haptik bei jedem Flügelschlag, Papiergeräusche, Parallax-Welten und ein schneller Neustart. Game-Center-Bestenlisten und Erfolge.

AUF JEDEM IPHONE UND IPAD
Kein Scharnier? Tippe zum Flattern, mit derselben Physik.

FAIR
Paper Meadow und der Tagesflug sind kostenlos. Ein Kauf schaltet die anderen Welten und Endlos frei. Keine Werbung, kein Abo, kein Tracking.""")

LIMITS = dict(name=30, subtitle=30, keywords=100, promo=170, description=4000)
ok = True
for loc, d in L.items():
    for k, n in LIMITS.items():
        if len(d[k]) > n:
            ok = False
            print(f'{loc} {k} too long: {len(d[k])} > {n}')
json.dump(L, open('store/listing.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print('ok' if ok else 'FIX LIMITS', {loc: {k: len(v) for k, v in d.items() if k != 'description'} for loc, d in L.items()})
