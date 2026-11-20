# Writes store/listing.json (App Store name, subtitle, keywords, promo text, description) for 5 locales and checks Apple's limits.
# Usage: python -X utf8 scripts/listing.py
import json

L = {}

L['en-US'] = dict(
    name='Midfold: 2 Player Fold Games',
    subtitle='Party duels on one phone',
    keywords='two,party,duel,reaction,tap,foldable,hinge,versus,friends,offline,local,multiplayer,battle,family',
    promo='Open the phone to fly, fold it to lock the angle, or lay it flat and duel face to face across the fold. Made for iPhone Duo, fun on every iPhone and iPad.',
    description="""Midfold turns the fold into the game. Made for iPhone Duo, playable on every iPhone and iPad. No account, no ads, works offline.

FOLD GAMES: THE HINGE IS THE CONTROLLER
• Fold Flight: open the phone wider to climb, close it to dive, and steer a paper glider through the gaps.
• Angle Lock: fold to eight target angles and hold each one steady. Beat your best time.

FACE-TO-FACE DUELS
Lay the phone open flat on the table between two players. Each half of the screen turns toward its player, and the fold is the centre line.
• Quick Draw: wait for green, then tap first. Tap too early and the point goes to your rival.
• Tug Line: tap as fast as you can to pull the knot over the fold to your side.
• Odd Spot: each player gets their own grid. Find the one symbol that is different before your rival does; a wrong tap freezes you.

ON EVERY DEVICE
On iPhones and iPads without a hinge, steer the fold games by tilting the device or with a slider, and duels split the screen in two.

PRIVATE
No accounts, no ads, no tracking. Nothing leaves your device.""")

L['tr'] = dict(
    name='Midfold: İki Kişilik Oyunlar',
    subtitle='Katla, kapış, kazan',
    keywords='parti,düello,refleks,dokun,katlanabilir,menteşe,arkadaş,çevrimdışı,yerel,aile,yarış,hız,eğlence',
    promo='Uçmak için telefonu açın, açıyı kilitlemek için katlayın ya da düz bırakıp katlama çizgisinin iki yanında karşılıklı kapışın. iPhone Duo için tasarlandı.',
    description="""Midfold katlamayı oyuna çeviriyor. iPhone Duo için tasarlandı, her iPhone ve iPad'de oynanır. Hesap yok, reklam yok, internetsiz çalışır.

KATLAMA OYUNLARI: MENTEŞE OYUN KOLUNUZ
• Katla Uç: yükselmek için telefonu açın, alçalmak için kapatın ve kâğıt uçağı boşluklardan geçirin.
• Açı Kilidi: telefonu sekiz hedef açıya getirin ve her birinde sabit tutun. Rekorunuzu geçin.

KARŞILIKLI DÜELLOLAR
Telefonu iki oyuncunun arasına, masaya düz açık bırakın. Ekranın her yarısı kendi oyuncusuna döner, katlama çizgisi orta çizgidir.
• Hızlı Dokun: yeşili bekleyin, sonra ilk siz dokunun. Erken dokunursanız sayı rakibe gider.
• Halat Çek: düğümü katlama çizgisinin üstünden kendi tarafınıza çekmek için olabildiğince hızlı dokunun.
• Farklıyı Bul: her oyuncunun kendi ızgarası var. Farklı olan tek simgeyi rakibinizden önce bulun; yanlış dokunuş sizi dondurur.

HER CİHAZDA
Menteşesi olmayan iPhone ve iPad'lerde katlama oyunlarını cihazı eğerek ya da kaydırıcıyla oynarsınız; düellolarda ekran ikiye bölünür.

GİZLİ
Hesap yok, reklam yok, izleme yok. Hiçbir şey cihazınızdan çıkmaz.""")

L['es-MX'] = dict(
    name='Midfold: Juegos para 2',
    subtitle='Duelos cara a cara y bisagra',
    keywords='dos,jugadores,fiesta,duelo,reflejos,plegable,amigos,sin,internet,local,multijugador,familia,rapido',
    promo='Abre el teléfono para volar, dóblalo para fijar el ángulo o déjalo plano y enfréntate cara a cara a ambos lados del pliegue. Hecho para iPhone Duo.',
    description="""Midfold convierte el pliegue en el juego. Hecho para iPhone Duo y se juega en cualquier iPhone y iPad. Sin cuenta, sin anuncios, funciona sin internet.

JUEGOS DE PLIEGUE: LA BISAGRA ES EL CONTROL
• Vuelo plegado (Fold Flight): abre más el teléfono para subir, ciérralo para bajar y guía un avión de papel entre los huecos.
• Bloqueo de ángulo (Angle Lock): dobla el teléfono hasta ocho ángulos objetivo y mantén cada uno firme. Supera tu mejor tiempo.

DUELOS CARA A CARA
Deja el teléfono abierto y plano sobre la mesa entre dos jugadores. Cada mitad de la pantalla mira a su jugador y el pliegue es la línea central.
• Quick Draw: espera el verde y toca primero. Si tocas antes, el punto es para tu rival.
• Tug Line: toca lo más rápido que puedas para llevar el nudo a tu lado del pliegue.
• Odd Spot: cada jugador tiene su propia cuadrícula. Encuentra el símbolo distinto antes que tu rival; un toque equivocado te congela.

EN CUALQUIER DISPOSITIVO
En iPhone y iPad sin bisagra, juega los juegos de pliegue inclinando el dispositivo o con un control deslizante, y los duelos dividen la pantalla en dos.

PRIVADO
Sin cuentas, sin anuncios, sin rastreo. Nada sale de tu dispositivo.""")

L['pt-BR'] = dict(
    name='Midfold: Jogos para 2',
    subtitle='Duelos cara a cara no celular',
    keywords='dois,jogadores,festa,duelo,reflexo,dobrável,dobradiça,amigos,offline,local,multiplayer,família',
    promo='Abra o celular para voar, dobre para travar o ângulo ou deixe-o aberto na mesa e dispute cara a cara dos dois lados da dobra. Feito para iPhone Duo.',
    description="""Midfold transforma a dobra no jogo. Feito para iPhone Duo e jogável em qualquer iPhone e iPad. Sem conta, sem anúncios, funciona offline.

JOGOS DE DOBRA: A DOBRADIÇA É O CONTROLE
• Voo dobrado (Fold Flight): abra mais o celular para subir, feche para descer e guie um avião de papel pelas brechas.
• Trava de ângulo (Angle Lock): dobre até oito ângulos-alvo e segure cada um firme. Bata seu melhor tempo.

DUELOS CARA A CARA
Deixe o celular aberto e plano na mesa entre dois jogadores. Cada metade da tela fica virada para seu jogador, e a dobra é a linha central.
• Quick Draw: espere o verde e toque primeiro. Tocou antes da hora, o ponto vai para o rival.
• Tug Line: toque o mais rápido que puder para puxar o nó por cima da dobra até o seu lado.
• Odd Spot: cada jogador tem sua própria grade. Ache o símbolo diferente antes do rival; um toque errado congela você.

EM QUALQUER APARELHO
Em iPhones e iPads sem dobradiça, jogue os jogos de dobra inclinando o aparelho ou com um controle deslizante; nos duelos a tela se divide em duas.

PRIVADO
Sem contas, sem anúncios, sem rastreamento. Nada sai do seu aparelho.""")

L['de-DE'] = dict(
    name='Midfold: Spiele zu zweit',
    subtitle='Duelle am Tisch, Klapp-Spiele',
    keywords='zwei,spieler,party,duell,reaktion,tippen,faltbar,scharnier,freunde,offline,lokal,familie',
    promo='Klapp das Telefon auf, um zu fliegen, falte es, um den Winkel zu halten, oder leg es flach hin und duelliere dich über den Falz hinweg. Für das iPhone Duo.',
    description="""Midfold macht den Falz zum Spiel. Gemacht für das iPhone Duo, spielbar auf jedem iPhone und iPad. Kein Konto, keine Werbung, funktioniert offline.

FALZ-SPIELE: DAS SCHARNIER IST DER CONTROLLER
• Falzflug (Fold Flight): Klapp das Telefon weiter auf, um zu steigen, schließ es, um zu sinken, und lenk einen Papierflieger durch die Lücken.
• Winkelschloss (Angle Lock): Falte das Telefon auf acht Zielwinkel und halte jeden ruhig. Schlag deine Bestzeit.

DUELLE VON ANGESICHT ZU ANGESICHT
Leg das Telefon aufgeklappt und flach zwischen zwei Spieler auf den Tisch. Jede Bildschirmhälfte dreht sich zu ihrem Spieler, der Falz ist die Mittellinie.
• Quick Draw: Warte auf Grün und tippe zuerst. Wer zu früh tippt, schenkt dem Gegner den Punkt.
• Tug Line: Tippe so schnell du kannst, um den Knoten über den Falz auf deine Seite zu ziehen.
• Odd Spot: Jeder hat sein eigenes Raster. Finde das eine abweichende Symbol vor deinem Gegner; ein falscher Tipp friert dich ein.

AUF JEDEM GERÄT
Auf iPhones und iPads ohne Scharnier steuerst du die Falz-Spiele durch Neigen oder mit einem Schieberegler, und Duelle teilen den Bildschirm in zwei Hälften.

PRIVAT
Keine Konten, keine Werbung, kein Tracking. Nichts verlässt dein Gerät.""")

LIMITS = dict(name=30, subtitle=30, keywords=100, promo=170, description=4000)
ok = True
for loc, d in L.items():
    for k, n in LIMITS.items():
        if len(d[k]) > n:
            ok = False
            print(f'{loc} {k} too long: {len(d[k])} > {n}')
json.dump(L, open('store/listing.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print('ok' if ok else 'FIX LIMITS', {loc: {k: len(v) for k, v in d.items() if k != 'description'} for loc, d in L.items()})
