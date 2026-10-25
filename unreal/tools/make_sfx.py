"""Synthesises the game's sound effects (port of scripts/sfx.gd) as .wav files that Unreal imports directly.
Output: unreal/DarkSouls/Content/ImportSource/Audio/Sfx/*.wav   Needs numpy.
Import the folder into /Game/Audio/Sfx (keep the file names; the game looks sounds up by name)."""
import os, wave, zlib
import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "DarkSouls", "Content", "ImportSource", "Audio", "Sfx")


def rng_for(name):
    return np.random.default_rng(zlib.crc32(name.encode()))


def lowpass(x, a):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += (v - acc) * (a if np.isscalar(a) else a[i])
        y[i] = acc
    return y


def t_of(n):
    return np.arange(n) / RATE


def thunder(r):
    n = int(RATE * 3.4); t = t_of(n); w = r.uniform(-1, 1, n)
    a = np.interp(t / 0.6, [0, 1], [0.55, 0.02])
    lp = lowpass(w, a); lp2 = lowpass(lp, 0.25)
    env = np.exp(-t * 1.25) * (0.55 + 0.45 * np.sin(t * 6.5 + 1.3 * np.sin(t * 2.1)))
    return (lp2 * 4.2 * env + np.exp(-t * 28) * w * 0.9) * np.minimum(t / 0.01, 1)


def rain(r):
    fade = 800; total = RATE * 2 + fade
    w = r.uniform(-1, 1, total); lp = lowpass(w, 0.35); raw = (w - lp) * 0.22 + lp * 0.1
    n = RATE * 2; s = raw[:n].copy(); k = np.arange(fade) / fade
    s[:fade] = raw[:fade] * k + raw[n:n + fade] * (1 - k)
    return s


def hit(r):
    n = int(RATE * 0.22); t = t_of(n); w = r.uniform(-1, 1, n)
    return lowpass(w, 0.3) * np.exp(-t * 22) * 1.2 + np.sin(t * 2 * np.pi * 110) * np.exp(-t * 26) * 0.8


def hurt(r):
    n = int(RATE * 0.3); t = t_of(n); w = r.uniform(-1, 1, n)
    return lowpass(w, 0.15) * np.exp(-t * 14) * 1.6 + np.sin(t * 2 * np.pi * 70) * np.exp(-t * 15) * 0.9


def swing(r):
    n = int(RATE * 0.28); t = t_of(n); u = t / 0.28; w = r.uniform(-1, 1, n)
    return lowpass(w, 0.05 + (0.5 - 0.05) * np.sin(u * np.pi)) * np.sin(u * np.pi) * 0.7


def bolt(r):
    n = int(RATE * 1.1); t = t_of(n); w = r.uniform(-1, 1, n)
    return (w * np.exp(-t * 30) * 0.9 + lowpass(w, 0.2) * np.exp(-t * 5) * 1.6) * np.minimum(t / 0.004, 1)


def chime(r):
    n = int(RATE * 1.2); t = t_of(n); v = np.zeros(n)
    for k, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        t0 = k * 0.11; m = t > t0
        v[m] += np.sin((t[m] - t0) * 2 * np.pi * f) * np.exp(-(t[m] - t0) * 3.2) * 0.3
    return v


def potion(r):
    n = int(RATE * 0.7); t = t_of(n); f = 300 + 600 * t / 0.7; e = np.sin(t / 0.7 * np.pi)
    return np.sin(t * 2 * np.pi * f) * e * 0.35 + np.sin(t * 2 * np.pi * f * 1.5) * e * 0.12


def roar(r):
    n = int(RATE * 1.6); t = t_of(n); f = 62 + np.sin(t * 9) * 8 - t * 12
    saw = np.mod(t * f, 1) * 2 - 1; w = r.uniform(-1, 1, n)
    return (saw * 0.5 + lowpass(w, 0.12) * 0.9) * np.sin(np.clip(t / 1.6, 0, 1) * np.pi) * 0.9


FORMANTS = [[700, 1200], [450, 800], [500, 1900], [350, 700]]


def voice(vowel, style):
    r = np.random.default_rng(vowel * 31 + style * 7 + 5)
    dur = 0.13; n = int(RATE * dur); t = t_of(n); fm = FORMANTS[vowel % 4]
    f = (105 + r.uniform(-8, 8)) * (1 - 0.15 * t / dur); v = np.zeros(n)
    for k in range(1, 18):
        hf = f * k
        amp = np.exp(-((hf - fm[0]) / 220) ** 2) + 0.6 * np.exp(-((hf - fm[1]) / 320) ** 2)
        v += np.sin(t * 2 * np.pi * hf) * amp / k * 2.2
    noise = r.uniform(-1, 1, n)
    env = np.minimum(t / 0.012, 1) * np.clip((dur - t) / 0.05, 0, 1)
    if style == 0:
        v = v * (0.75 + 0.25 * np.sign(np.sin(t * 2 * np.pi * 38))) + noise * 0.08
    elif style == 1:
        v = v * 0.35 + (noise - lowpass(noise, 0.55)) * 0.7
    else:
        v = v * np.sin(t * 2 * np.pi * 90 + 1) * 1.4 + np.sin(t * 2 * np.pi * 620) * 0.12
    return np.clip(v, -1, 1) * env * 0.5


def boom(r):
    n = int(RATE * 2.2); t = t_of(n); w = r.uniform(-1, 1, n)
    a = 0.5 + (0.04 - 0.5) * np.clip(t / 0.8, 0, 1)
    thump = np.sin(t * 2 * np.pi * (95 - 60 * np.clip(t / 0.6, 0, 1))) * np.exp(-t * 2.4)
    return (thump * 0.8 + lowpass(w, a) * 0.9 * np.exp(-t * 1.6)) * np.minimum(t / 0.004, 1)


def crumble(r):
    n = int(RATE * 1.8); t = t_of(n); w = r.uniform(-1, 1, n); lp = lowpass(w, 0.08)
    click = np.zeros(n); c = 0.0
    for i in range(n):
        if r.random() < 0.0018 * (1 - t[i] / 1.8): c = r.uniform(0.5, 1)
        c *= 0.985; click[i] = c
    return (lp * 0.7 + w * click * 0.5) * (1 - t / 1.8)


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32000).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE); f.writeframes(pcm.tobytes())


def main():
    for name, fn in [("thunder", thunder), ("rain", rain), ("hit", hit), ("hurt", hurt), ("swing", swing), ("bolt", bolt), ("chime", chime),
                     ("potion", potion), ("roar", roar), ("boom", boom), ("crumble", crumble)]:
        write(name, fn(rng_for(name)))
    for style, prefix in enumerate("vhm"):
        for vowel in range(4):
            write("%s%d" % (prefix, vowel), voice(vowel, style))
    print("wrote", len(os.listdir(OUT)), "files to", os.path.abspath(OUT))


main()
