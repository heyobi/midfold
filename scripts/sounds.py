# Draws Midfold's sound effects as 16-bit mono WAVs into Midfold/Sounds (no third-party audio).
# Usage: python scripts/sounds.py
import math
import os
import random
import struct
import wave

SR = 44100
OUT = 'Midfold/Sounds'
random.seed(7)


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(s / peak * 0.85 * 32767)) for s in samples))


def env(i, n, attack, release):
    t = i / n
    if t < attack:
        return t / attack
    return max(0.0, 1 - (t - attack) / release) if release else 1.0


def lowpass(x, a):
    y, out = 0.0, []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


# Wing whoosh: band-limited noise swelling and fading, like paper moving air.
n = int(SR * 0.22)
noise = [random.uniform(-1, 1) for _ in range(n)]
lp1 = lowpass(noise, 0.18)
lp2 = lowpass(noise, 0.04)
flap = [(a - b) * math.sin(math.pi * min(1, i / n * 1.4)) ** 2 for i, (a, b) in enumerate(zip(lp1, lp2))]
write('flap', flap)

# Star: two bright bell partials with a quick decay.
n = int(SR * 0.5)
star = []
for i in range(n):
    t = i / SR
    e = math.exp(-t * 7)
    star.append(e * (math.sin(2 * math.pi * 1568 * t) + 0.5 * math.sin(2 * math.pi * 2349 * t) + 0.25 * math.sin(2 * math.pi * 3136 * t)))
write('star', star)

# Gate passed: a soft paper tick.
n = int(SR * 0.06)
tick = lowpass([random.uniform(-1, 1) * math.exp(-i / SR * 90) for i in range(n)], 0.3)
write('gate', tick)

# Hit: low thump plus crumple.
n = int(SR * 0.35)
hit = []
crumple = lowpass([random.uniform(-1, 1) for _ in range(n)], 0.25)
for i in range(n):
    t = i / SR
    hit.append(math.exp(-t * 14) * math.sin(2 * math.pi * (90 - 40 * t) * t) * 1.2 + crumple[i] * math.exp(-t * 18) * 0.6)
write('hit', hit)

# Win: rising arpeggio (C E G C).
win = []
for k, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
    n = int(SR * (0.13 if k < 3 else 0.45))
    for i in range(n):
        t = i / SR
        win.append(math.exp(-t * (9 if k < 3 else 4)) * (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(4 * math.pi * f * t)))
write('win', win)

# Lose: two falling notes.
lose = []
for f in [392.0, 293.66]:
    n = int(SR * 0.28)
    for i in range(n):
        t = i / SR
        lose.append(math.exp(-t * 6) * (math.sin(2 * math.pi * f * t) + 0.2 * math.sin(6 * math.pi * f * t)))
write('lose', lose)
print('sounds written')
