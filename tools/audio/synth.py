"""Original sound effects and music for Ascua Infinita, synthesised from scratch.

Run from the project root:  python tools/audio/synth.py
Requires numpy, scipy and ffmpeg (for the Ogg Vorbis music loops).
Every waveform is generated here; no samples or third-party recordings are used.
"""
import os
import subprocess
import wave

import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- primitives
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def env_adsr(n, a=0.005, d=0.1, s=0.6, r=0.2, sustain_time=None):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    if sustain_time is None:
        sustain_time = max(0, n / SR - a - d - r)
    s_n = int(sustain_time * SR)
    e = np.concatenate([
        np.linspace(0, 1, max(1, a_n), endpoint=False),
        np.linspace(1, s, max(1, d_n), endpoint=False),
        np.full(max(0, s_n), s),
        np.linspace(s, 0, max(1, r_n)),
    ])
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n]


def env_exp(n, decay):
    return np.exp(-np.arange(n) / SR / decay)


def lowpass(x, cutoff, order=2):
    cutoff = min(cutoff, SR * 0.45)
    b, a = butter(order, cutoff / (SR / 2), "low")
    return lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = butter(order, cutoff / (SR / 2), "high")
    return lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band")
    return lfilter(b, a, x)


def noise(n):
    return rng.uniform(-1, 1, n)


def sweep_phase(f0, f1, n, curve=1.0):
    k = np.linspace(0, 1, n) ** curve
    freq = f0 + (f1 - f0) * k
    return 2 * np.pi * np.cumsum(freq) / SR


def saw(phase):
    return 2 * ((phase / (2 * np.pi)) % 1.0) - 1


def square(phase, duty=0.5):
    return np.where((phase / (2 * np.pi)) % 1.0 < duty, 1.0, -1.0)


def tri(phase):
    return 2 * np.abs(saw(phase)) - 1


def pluck(freq, dur, bright=0.5, decay=0.996):
    """Karplus-Strong string, computed one period at a time."""
    n = int(dur * SR)
    period = max(2, int(SR / freq))
    buf = lowpass(noise(period), 800 + 6000 * bright) if period > 12 else noise(period)
    out = np.zeros(n + period + 1)
    out[:period] = buf
    pos = period
    while pos < n:
        end = min(pos + period, n)
        prev = out[pos - period:end - period]
        prev2 = out[pos - period + 1:end - period + 1]
        out[pos:end] = decay * 0.5 * (prev + prev2)
        pos = end
    y = out[:n]
    return y * env_adsr(n, 0.001, 0.0, 1.0, min(0.05, dur * 0.3))


def fm_bell(freq, dur, ratio=3.5, index=3.0, decay=1.2):
    t = t_axis(dur)
    mod_env = np.exp(-t / (decay * 0.35))
    y = np.sin(2 * np.pi * freq * t + index * mod_env * np.sin(2 * np.pi * freq * ratio * t))
    return y * np.exp(-t / decay) * env_adsr(len(t), 0.002, 0, 1, 0.02)


def soft_saw(freq, dur, cutoff=1800, detune=0.004, voices=3):
    t = t_axis(dur)
    y = np.zeros_like(t)
    for v in range(voices):
        f = freq * (1 + detune * (v - (voices - 1) / 2))
        y += saw(2 * np.pi * f * t + rng.uniform(0, 6.28))
    return lowpass(y / voices, cutoff)


def comb(x, d, g):
    """y[n] = x[n] + g * y[n - d], evaluated one block of d samples at a time."""
    y = x.astype(np.float64).copy()
    for start in range(d, len(y), d):
        end = min(start + d, len(y))
        y[start:end] += g * y[start - d:end - d]
    return y


def allpass(x, d, g=0.5):
    """y[n] = -g x[n] + x[n - d] + g y[n - d]."""
    y = -g * x.astype(np.float64)
    y[d:] += x[:-d]
    for start in range(d, len(y), d):
        end = min(start + d, len(y))
        y[start:end] += g * y[start - d:end - d]
    return y


def reverb(x, mix=0.3, size=1.0, damp=0.4):
    combs = [1557, 1617, 1491, 1422, 1277, 1356]
    allpasses = [225, 556, 441, 341]
    src = lowpass(x, 5200 - damp * 3000, 1)
    wet = np.zeros_like(x, dtype=np.float64)
    for d in combs:
        wet += comb(src, int(d * size), 0.84 * (1 - damp * 0.2))
    wet /= len(combs)
    for d in allpasses:
        wet = allpass(wet, d)
    return x * (1 - mix) + wet * mix * 1.6


def delay(x, seconds, feedback=0.35, mix=0.3):
    d = int(seconds * SR)
    echo = np.zeros_like(x, dtype=np.float64)
    echo[d:] = x[:-d]
    return x + mix * comb(echo, d, feedback)


def normalize(x, peak=0.89):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def loudness(x, target_db=-17.0, ceiling=0.9):
    """Match RMS loudness, then soft-limit peaks above 70% of the ceiling."""
    rms = np.sqrt(np.mean(x ** 2)) or 1.0
    x = x / rms * 10 ** (target_db / 20)
    t = 0.7 * ceiling
    over = np.abs(x) > t
    x[over] = np.sign(x[over]) * (t + (ceiling - t) * np.tanh((np.abs(x[over]) - t) / (ceiling - t)))
    return x


def fade(x, fin=0.002, fout=0.01):
    n = len(x)
    e = np.ones(n)
    a, b = int(fin * SR), int(fout * SR)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if b:
        e[-b:] = np.linspace(1, 0, b)
    return x * e


def write_wav(path, x, rate=SR):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data.tobytes())


def mix_at(buf, sig, start):
    s = int(start * SR)
    if s >= len(buf):
        return
    e = min(len(buf), s + len(sig))
    buf[s:e] += sig[:e - s]


# ---------------------------------------------------------------- effects
def sfx():
    out = {}

    def thump(f0, f1, dur, decay):
        n = int(dur * SR)
        return np.sin(sweep_phase(f0, f1, n, 0.5)) * env_exp(n, decay)

    for i, (pitch, tone) in enumerate([(1.0, 900), (1.12, 1100), (0.9, 800)]):
        n = int(0.16 * SR)
        click = bandpass(noise(n), 900 * pitch, 4200 * pitch) * env_exp(n, 0.012)
        body = thump(210 * pitch, 70 * pitch, 0.16, 0.05)
        slash = highpass(noise(n), 2500) * env_exp(n, 0.03) * 0.35
        out["hit_%d" % (i + 1)] = fade(normalize(click * 0.8 + body + slash, 0.75))

    n = int(0.45 * SR)
    ring = sum(np.sin(2 * np.pi * f * t_axis(0.45)) * w for f, w in [(1320, 0.5), (1980, 0.3), (2640, 0.2)]) * env_exp(n, 0.12)
    crack = highpass(noise(n), 1800) * env_exp(n, 0.02)
    out["critical"] = fade(normalize(ring * 0.55 + crack * 0.8 + thump(320, 60, 0.45, 0.07), 0.85))

    # Destello: rising whoosh, flash, low boom, shimmer tail.
    n = int(1.2 * SR)
    t = t_axis(1.2)
    whoosh = bandpass(noise(n), 400, 5000) * np.clip(t / 0.25, 0, 1) * np.exp(-np.clip(t - 0.25, 0, None) / 0.12)
    boom = np.zeros(n)
    mix_at(boom, thump(120, 32, 0.9, 0.3), 0.22)
    shimmer = np.zeros(n)
    for k, f in enumerate([1568, 2093, 2637, 3136]):
        mix_at(shimmer, fm_bell(f, 0.9, 2.0, 1.2, 0.35) * 0.25, 0.24 + k * 0.05)
    out["burst"] = fade(normalize(reverb(whoosh * 0.6 + boom + shimmer, 0.3), 0.92))

    # Enemy strike landing on the bearer.
    n = int(0.5 * SR)
    swing = bandpass(noise(n), 300, 2400) * np.clip(t_axis(0.5) / 0.08, 0, 1) * env_exp(n, 0.06)
    impact = np.zeros(n)
    mix_at(impact, thump(160, 40, 0.4, 0.09) + lowpass(noise(int(0.4 * SR)), 900) * env_exp(int(0.4 * SR), 0.05), 0.07)
    out["hurt"] = fade(normalize(swing * 0.5 + impact, 0.9))

    # Gold: two bright tones.
    y = np.zeros(int(0.35 * SR))
    mix_at(y, fm_bell(1760, 0.3, 2.0, 0.8, 0.12), 0.0)
    mix_at(y, fm_bell(2637, 0.3, 2.0, 0.8, 0.14), 0.06)
    out["coin"] = fade(normalize(y, 0.6))

    # Forge purchase: hammer on anvil.
    n = int(0.6 * SR)
    anvil = sum(np.sin(2 * np.pi * f * t_axis(0.6)) * w * env_exp(n, d) for f, w, d in [(1180, 0.5, 0.25), (2710, 0.3, 0.12), (4020, 0.2, 0.06)])
    knock = lowpass(noise(n), 2500) * env_exp(n, 0.01)
    out["buy"] = fade(normalize(reverb(anvil + knock * 0.8, 0.18), 0.7))

    # Relic chosen: ascending arpeggio of bells.
    y = np.zeros(int(1.6 * SR))
    for k, m in enumerate([69, 72, 76, 81, 84]):
        mix_at(y, fm_bell(midi(m), 1.2, 3.0, 1.6, 0.5) * (0.8 - k * 0.08), k * 0.07)
    out["relic"] = fade(normalize(reverb(y, 0.35, 1.2), 0.8))

    # Relic offered: a suspended chord swelling in.
    n = int(2.0 * SR)
    pad = sum(soft_saw(midi(m), 2.0, 1400) for m in [57, 62, 64, 69])
    pad *= np.sin(np.linspace(0, np.pi, n)) ** 1.5
    out["offer"] = fade(normalize(reverb(pad, 0.45, 1.3), 0.6))

    # Deaths per enemy.
    n = int(0.6 * SR)
    t = t_axis(0.6)
    squelch = lowpass(noise(n), 700) * env_exp(n, 0.12) + np.sin(sweep_phase(300, 90, n)) * env_exp(n, 0.1) * 0.6
    bubbles = sum(np.sin(2 * np.pi * (500 + 160 * k) * t) * np.exp(-((t - 0.05 * k - 0.1) ** 2) / 0.0004) for k in range(5)) * 0.3
    out["die_slime"] = fade(normalize(squelch + bubbles, 0.8))

    y = np.zeros(int(1.0 * SR))
    mix_at(y, bandpass(noise(int(0.5 * SR)), 1500, 7000) * env_exp(int(0.5 * SR), 0.08) * 0.6, 0)
    for k in range(6):
        mix_at(y, fm_bell(midi(84 + rng.integers(-5, 7)), 0.5, 2.5, 1.0, 0.15) * 0.3, 0.03 + k * 0.05)
    out["die_wisp"] = fade(normalize(reverb(y, 0.3), 0.75))

    y = np.zeros(int(1.1 * SR))
    for k in range(9):
        dur = 0.18
        rock = lowpass(noise(int(dur * SR)), 600 + rng.integers(0, 900)) * env_exp(int(dur * SR), 0.04)
        mix_at(y, rock * rng.uniform(0.4, 1.0), 0.04 * k + rng.uniform(0, 0.05))
    mix_at(y, thump(110, 35, 0.6, 0.2), 0.0)
    out["die_sentinel"] = fade(normalize(y, 0.9))

    n = int(3.0 * SR)
    y = np.zeros(n)
    mix_at(y, thump(90, 25, 2.5, 0.8), 0)
    mix_at(y, lowpass(noise(int(2.4 * SR)), 400) * env_exp(int(2.4 * SR), 0.7), 0)
    for k, m in enumerate([50, 53, 57, 62, 65]):
        mix_at(y, soft_saw(midi(m), 2.4, 1200) * env_adsr(int(2.4 * SR), 0.3, 0.4, 0.6, 1.2) * 0.25, 0.4)
    out["die_boss"] = fade(normalize(reverb(y, 0.4, 1.4), 0.92))

    # Boss arrives: low horn and rumble.
    n = int(2.6 * SR)
    horn = sum(soft_saw(midi(m), 2.6, 700, 0.006, 4) for m in [38, 45, 50])
    horn *= env_adsr(n, 0.5, 0.3, 0.8, 1.0)
    rumble = lowpass(noise(n), 160) * env_adsr(n, 0.8, 0.2, 0.9, 1.0) * 2.5
    out["boss_appear"] = fade(normalize(reverb(horn + rumble, 0.4, 1.5), 0.9))

    # Boss charging a fireball (telegraph).
    n = int(1.4 * SR)
    t = t_axis(1.4)
    roar = bandpass(noise(n), 200, 2200) * (t / 1.4) ** 1.5
    tone = np.sin(sweep_phase(110, 330, n, 1.4)) * (t / 1.4) ** 2 * 0.5
    out["boss_charge"] = fade(normalize(roar + tone, 0.8), 0.02, 0.05)

    # Interrupt / stagger: glass and a falling tone.
    n = int(0.9 * SR)
    glass = sum(np.sin(2 * np.pi * f * t_axis(0.9)) * env_exp(n, 0.15 + 0.05 * k) for k, f in enumerate([2350, 3170, 4410, 5230]))
    shatter = highpass(noise(n), 3000) * env_exp(n, 0.05)
    fall = np.sin(sweep_phase(880, 220, n)) * env_exp(n, 0.25) * 0.5
    out["interrupt"] = fade(normalize(reverb(glass * 0.4 + shatter + fall, 0.25), 0.85))

    # Wandering ember.
    y = np.zeros(int(0.9 * SR))
    for k, m in enumerate([88, 91, 95]):
        mix_at(y, fm_bell(midi(m), 0.6, 2.0, 0.6, 0.25) * 0.4, k * 0.08)
    out["ember_appear"] = fade(normalize(reverb(y, 0.4), 0.45))
    y = np.zeros(int(1.0 * SR))
    for k, m in enumerate([76, 79, 83, 88, 91, 95]):
        mix_at(y, fm_bell(midi(m), 0.6, 2.0, 0.9, 0.3) * 0.5, k * 0.04)
    out["ember_take"] = fade(normalize(reverb(y, 0.3), 0.75))

    # Expedition lost.
    y = np.zeros(int(2.4 * SR))
    for k, m in enumerate([62, 58, 55, 50]):
        mix_at(y, soft_saw(midi(m), 1.2, 900) * env_adsr(int(1.2 * SR), 0.05, 0.3, 0.5, 0.7) * 0.6, k * 0.35)
    out["fall"] = fade(normalize(reverb(y, 0.45, 1.3), 0.8))

    # Rebirth: rising major chord.
    y = np.zeros(int(2.4 * SR))
    for k, m in enumerate([55, 59, 62, 67, 71, 74]):
        mix_at(y, fm_bell(midi(m), 1.8, 2.0, 1.1, 0.8) * 0.35, k * 0.09)
    mix_at(y, sum(soft_saw(midi(m), 2.0, 1600) for m in [43, 55, 62]) * env_adsr(int(2.0 * SR), 0.6, 0.3, 0.7, 0.8) * 0.4, 0)
    out["rebirth"] = fade(normalize(reverb(y, 0.4, 1.3), 0.8))

    out["heal"] = fade(normalize(reverb(sum(fm_bell(midi(m), 0.8, 1.0, 0.8, 0.3) for m in [79, 83, 86]), 0.3), 0.45))

    # Interface.
    n = int(0.05 * SR)
    out["ui_hover"] = fade(normalize(np.sin(2 * np.pi * 1900 * t_axis(0.05)) * env_exp(n, 0.012), 0.22))
    n = int(0.09 * SR)
    out["ui_click"] = fade(normalize(np.sin(sweep_phase(900, 520, n)) * env_exp(n, 0.025) + bandpass(noise(n), 2000, 6000) * env_exp(n, 0.006) * 0.4, 0.42))
    n = int(0.35 * SR)
    out["ui_open"] = fade(normalize(bandpass(noise(n), 500, 3500) * np.sin(np.linspace(0, np.pi, n)) ** 2 + fm_bell(1046, 0.35, 2, 0.5, 0.1) * 0.3, 0.38))
    n = int(0.25 * SR)
    out["ui_close"] = fade(normalize(np.sin(sweep_phase(700, 380, n)) * env_exp(n, 0.06) * 0.6 + bandpass(noise(n), 400, 2500) * env_exp(n, 0.05) * 0.4, 0.32))
    n = int(0.18 * SR)
    out["ui_denied"] = fade(normalize(square(sweep_phase(180, 150, n), 0.3) * env_exp(n, 0.06) * 0.3 + lowpass(noise(n), 800) * env_exp(n, 0.02) * 0.3, 0.3))
    for name, sig in out.items():
        write_wav(os.path.join(SFX_DIR, name + ".wav"), sig)
    print("sfx: %d sounds" % len(out))


def sfx_combat():
    """Sounds added with the active combat of 0.6. They draw noise from their
    own seed so the older effects and the music render exactly as before."""
    global rng
    saved = rng
    rng = np.random.default_rng(61)
    out = {}

    # Parada: steel meeting steel, a bright ring and a short scrape.
    n = int(0.7 * SR)
    t = t_axis(0.7)
    ring = sum(np.sin(2 * np.pi * f * t) * w * env_exp(n, d) for f, w, d in [(1560, 0.5, 0.22), (2340, 0.35, 0.16), (3710, 0.25, 0.09), (5120, 0.15, 0.05)])
    clash = highpass(noise(n), 2200) * env_exp(n, 0.015)
    scrape = bandpass(noise(n), 3000, 8000) * np.clip(t / 0.02, 0, 1) * np.exp(-t / 0.08) * 0.4
    body = np.sin(sweep_phase(260, 90, n, 0.5)) * env_exp(n, 0.06)
    out["parry"] = fade(normalize(reverb(ring * 0.6 + clash + scrape + body * 0.7, 0.22), 0.88))

    # Guard raised: a quick airy swish.
    n = int(0.22 * SR)
    t = t_axis(0.22)
    swish = bandpass(noise(n), 900, 5000) * np.sin(np.pi * np.clip(t / 0.22, 0, 1)) ** 2
    out["guard"] = fade(normalize(swish, 0.35))

    # Weak point lights up: two soft rising pings.
    y = np.zeros(int(0.7 * SR))
    for k, m in enumerate([86, 93]):
        mix_at(y, fm_bell(midi(m), 0.5, 1.5, 0.5, 0.18) * 0.5, k * 0.07)
    out["weak_appear"] = fade(normalize(reverb(y, 0.35), 0.4))

    # Weak point struck: a glassy crack over a heavy thump.
    n = int(0.6 * SR)
    t = t_axis(0.6)
    crack = highpass(noise(n), 2600) * env_exp(n, 0.025)
    chime = sum(np.sin(2 * np.pi * f * t) * env_exp(n, 0.2) for f in [2093, 3136, 4186]) * 0.3
    thud = np.sin(sweep_phase(240, 45, n, 0.5)) * env_exp(n, 0.1)
    out["weak_hit"] = fade(normalize(crack * 0.7 + chime + thud, 0.9))

    # Walking on to the next chamber: soft steps in the dark.
    y = np.zeros(int(1.0 * SR))
    for k in range(3):
        step = lowpass(noise(int(0.12 * SR)), 500) * env_exp(int(0.12 * SR), 0.03)
        mix_at(y, step * (0.8 - k * 0.15), 0.1 + k * 0.3)
    out["advance"] = fade(normalize(reverb(y, 0.3), 0.3))

    for name, sig in out.items():
        write_wav(os.path.join(SFX_DIR, name + ".wav"), sig)
    rng = saved
    print("sfx: %d combat sounds" % len(out))


# ---------------------------------------------------------------- music
class Song:
    def __init__(self, bpm, bars, beats_per_bar=4):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.length = bars * beats_per_bar * self.beat
        self.tail = 4.0
        self.buf = np.zeros(int((self.length + self.tail) * SR))
        self.buses = {}

    def bus(self, name):
        if name not in self.buses:
            self.buses[name] = np.zeros_like(self.buf)
        return self.buses[name]

    def add(self, bus, sig, beat, gain=1.0):
        mix_at(self.bus(bus), sig * gain, beat * self.beat)

    def render(self, sends, master_reverb=0.25, size=1.2):
        out = np.zeros_like(self.buf)
        for name, sig in self.buses.items():
            out += sig * sends.get(name, 1.0)
        out = reverb(out, master_reverb, size)
        # Fold the tail back to the start so the loop has no seam.
        n = int(self.length * SR)
        loop = out[:n].copy()
        tail = out[n:]
        loop[:len(tail)] += tail
        return loudness(lowpass(loop, 15000), -17.0)


def chord_notes(root, kind):
    return [root + i for i in {"m": [0, 3, 7], "M": [0, 4, 7], "sus": [0, 5, 7], "dim": [0, 3, 6], "m7": [0, 3, 7, 10]}[kind]]


def kick(dur=0.35, f0=120, f1=42):
    n = int(dur * SR)
    return np.sin(sweep_phase(f0, f1, n, 0.4)) * env_exp(n, 0.12) + lowpass(noise(n), 1500) * env_exp(n, 0.004) * 0.3


def snare(dur=0.25):
    n = int(dur * SR)
    return bandpass(noise(n), 900, 7000) * env_exp(n, 0.06) + np.sin(sweep_phase(260, 170, n)) * env_exp(n, 0.04) * 0.5


def hat(dur=0.06, open_=False):
    n = int((0.25 if open_ else dur) * SR)
    return highpass(noise(n), 7000) * env_exp(n, 0.09 if open_ else 0.015)


def tom(f=90, dur=0.6):
    n = int(dur * SR)
    return np.sin(sweep_phase(f * 1.6, f, n, 0.3)) * env_exp(n, 0.2)


def pad_chord(notes, dur, cutoff=1300, attack=0.8):
    n = int(dur * SR)
    y = sum(soft_saw(midi(m), dur, cutoff, 0.005, 3) for m in notes) / len(notes)
    return y * env_adsr(n, attack, 0.3, 0.8, min(1.2, dur * 0.4))


def flute(freq, dur, vib=5.0):
    t = t_axis(dur)
    phase = 2 * np.pi * freq * t + 0.012 * freq / vib * np.sin(2 * np.pi * vib * t) * np.clip(t / 0.3, 0, 1)
    y = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.05 * tri(3 * phase)
    breath = bandpass(noise(len(t)), freq, freq * 3) * 0.05
    return (y + breath) * env_adsr(len(t), 0.08, 0.1, 0.8, 0.15)


def song_menu():
    s = Song(70, 16)
    prog = [(62, "m"), (58, "M"), (65, "M"), (60, "M"), (62, "m"), (55, "m"), (58, "M"), (57, "M")] * 2
    melody = [(0, 74, 2), (2, 72, 1), (3, 69, 1), (4, 70, 3), (8, 69, 2), (10, 65, 2), (12, 67, 4),
              (16, 74, 2), (18, 76, 1), (19, 77, 1), (20, 79, 3), (24, 77, 1.5), (25.5, 76, 0.5), (26, 74, 2), (28, 73, 4)]
    for bar, (root, kind) in enumerate(prog):
        b = bar * 4
        notes = chord_notes(root, kind)
        s.add("pad", pad_chord([n - 12 for n in notes], 4.4 * s.beat, 1100, 1.0), b, 0.45)
        s.add("bass", np.sin(2 * np.pi * midi(root - 24) * t_axis(4 * s.beat)) * env_adsr(int(4 * s.beat * SR), 0.05, 0.4, 0.7, 0.6), b, 0.5)
        arp = [notes[0], notes[1], notes[2], notes[1] + 12, notes[2], notes[1], notes[0] + 12, notes[2]]
        for k, m in enumerate(arp):
            s.add("arp", pluck(midi(m), 1.6, 0.35, 0.997), b + k * 0.5, 0.32)
    for start, m, d in melody + [(x + 32, m, d) for x, m, d in melody]:
        s.add("lead", fm_bell(midi(m), d * s.beat + 1.0, 2.0, 1.4, 0.9), start, 0.28)
    return s.render({"pad": 1, "arp": 1, "lead": 1, "bass": 1}, 0.35, 1.4)


def song_garden():
    s = Song(84, 16)
    prog = [(57, "m"), (53, "M"), (60, "M"), (55, "M"), (57, "m"), (53, "M"), (50, "m"), (52, "M")] * 2
    for bar, (root, kind) in enumerate(prog):
        b = bar * 4
        notes = chord_notes(root, kind)
        s.add("pad", pad_chord(notes, 4.2 * s.beat, 900, 0.6), b, 0.28)
        s.add("bass", pluck(midi(root - 24), 2.0, 0.2, 0.998), b, 0.55)
        s.add("bass", pluck(midi(root - 24), 1.5, 0.2, 0.998), b + 2.5, 0.4)
        pattern = [0, 2, 1, 2, 0 + 3, 2, 1, 2]
        for k in range(8):
            idx = pattern[k]
            m = notes[idx % 3] + (12 if idx >= 3 else 0) + 12
            s.add("arp", pluck(midi(m), 0.9, 0.55, 0.995), b + k * 0.5, 0.22)
        s.add("drums", kick(0.3, 100, 45), b, 0.5)
        s.add("drums", kick(0.3, 100, 45), b + 2, 0.35)
        for k in range(8):
            s.add("drums", hat(), b + k * 0.5 + 0.25, 0.08 + 0.04 * (k % 2))
    phrase = [(0, 81, 1.5), (1.5, 79, 0.5), (2, 76, 2), (4, 77, 1), (5, 76, 1), (6, 72, 2), (8, 74, 1.5), (9.5, 72, 0.5),
              (10, 71, 2), (12, 72, 1), (13, 74, 1), (14, 76, 2)]
    for rep in (16, 48):
        for start, m, d in phrase:
            s.add("lead", flute(midi(m), d * s.beat * 0.95), rep + start, 0.18)
    return s.render({"pad": 1, "arp": 1, "bass": 1, "drums": 1, "lead": 1}, 0.28, 1.2)


def song_crypt():
    s = Song(66, 16)
    prog = [(52, "m"), (53, "M"), (52, "m"), (50, "M"), (48, "M"), (53, "M"), (52, "m"), (51, "dim")] * 2
    for bar, (root, kind) in enumerate(prog):
        b = bar * 4
        notes = chord_notes(root, kind)
        choir = sum(soft_saw(midi(m), 4.5 * s.beat, 700, 0.008, 4) for m in notes) / 3
        choir *= env_adsr(len(choir), 1.4, 0.4, 0.8, 1.2)
        s.add("pad", choir, b, 0.4)
        s.add("drone", np.sin(2 * np.pi * midi(40) * t_axis(4 * s.beat + 0.5)) * env_adsr(int((4 * s.beat + 0.5) * SR), 0.6, 0.2, 0.9, 0.6), b, 0.35)
        if bar % 2 == 0:
            s.add("drums", tom(70, 1.0), b, 0.45)
            s.add("drums", tom(70, 1.0), b + 2.5, 0.25)
        for k, m in enumerate([notes[0] + 24, notes[2] + 12, notes[1] + 24]):
            if (bar + k) % 3 != 2:
                s.add("bells", fm_bell(midi(m), 3.0, 3.5, 2.2, 1.4), b + k * 1.33, 0.18)
    return s.render({"pad": 1, "drone": 1, "drums": 1, "bells": 1}, 0.5, 1.7)


def song_forge():
    s = Song(100, 16)
    prog = [(48, "m"), (44, "M"), (46, "M"), (43, "M")] * 4
    for bar, (root, kind) in enumerate(prog):
        b = bar * 4
        notes = chord_notes(root, kind)
        for k in range(8):
            m = root - 12 + (12 if k in (3, 7) else 0)
            sig = lowpass(saw(2 * np.pi * midi(m) * t_axis(0.28)), 600) * env_adsr(int(0.28 * SR), 0.004, 0.08, 0.5, 0.1)
            s.add("bass", sig, b + k * 0.5, 0.5)
        s.add("pad", pad_chord([n + 12 for n in notes], 4.2 * s.beat, 1500, 0.3), b, 0.22)
        s.add("drums", kick(), b, 0.7)
        s.add("drums", kick(), b + 1.5, 0.5)
        s.add("drums", kick(), b + 2, 0.7)
        s.add("drums", snare(), b + 1, 0.4)
        s.add("drums", snare(), b + 3, 0.45)
        for k in range(4):
            s.add("anvil", fm_bell(midi(84 if k % 2 else 79), 0.5, 3.7, 2.5, 0.12), b + k + 0.5, 0.12)
    riff = [(0, 72, 0.5), (0.5, 75, 0.5), (1, 79, 1), (2, 77, 0.5), (2.5, 75, 0.5), (3, 74, 1)]
    for rep in range(4, 16, 2):
        for start, m, d in riff:
            sig = soft_saw(midi(m), d * s.beat, 2600, 0.004, 3) * env_adsr(int(d * s.beat * SR), 0.01, 0.1, 0.7, 0.08)
            s.add("lead", sig, rep * 4 + start, 0.2)
    return s.render({"bass": 1, "pad": 1, "drums": 1, "anvil": 1, "lead": 1}, 0.22, 1.0)


def song_boss():
    s = Song(132, 16)
    prog = [(50, "m"), (46, "M"), (48, "M"), (45, "M")] * 4
    for bar, (root, kind) in enumerate(prog):
        b = bar * 4
        notes = chord_notes(root, kind)
        for k in range(16):
            m = root - 12 + (7 if k % 4 == 3 else 0)
            sig = lowpass(saw(2 * np.pi * midi(m) * t_axis(0.12)) + square(2 * np.pi * midi(m) * t_axis(0.12), 0.3) * 0.4, 900)
            s.add("bass", sig * env_adsr(len(sig), 0.002, 0.05, 0.5, 0.04), b + k * 0.25, 0.42)
        for k in range(4):
            s.add("drums", kick(0.25, 140, 45), b + k, 0.75)
            s.add("drums", hat(), b + k + 0.5, 0.12)
        s.add("drums", snare(), b + 1, 0.55)
        s.add("drums", snare(), b + 3, 0.55)
        if bar % 4 == 3:
            for k in range(4):
                s.add("drums", snare(0.15), b + 3 + k * 0.25, 0.3 + k * 0.08)
        stab = sum(soft_saw(midi(m + 12), 0.25, 2200, 0.006, 3) for m in notes) / 3
        for pos in (0, 0.75, 2, 2.75):
            s.add("stabs", stab * env_adsr(len(stab), 0.003, 0.08, 0.4, 0.06), b + pos, 0.32)
    melody = [(0, 74, 1.5), (1.5, 72, 0.5), (2, 70, 1), (3, 69, 1), (4, 70, 1.5), (5.5, 72, 0.5), (6, 74, 2),
              (8, 77, 1.5), (9.5, 76, 0.5), (10, 74, 1), (11, 72, 1), (12, 73, 4)]
    for rep in (16, 32, 48):
        for start, m, d in melody:
            dur = d * s.beat
            sig = soft_saw(midi(m), dur, 3200, 0.006, 3) * env_adsr(int(dur * SR), 0.02, 0.1, 0.8, 0.1)
            s.add("lead", sig, rep + start, 0.22)
    return s.render({"bass": 1, "drums": 1, "stabs": 1, "lead": 1}, 0.18, 1.0)


def song_camp():
    s = Song(66, 16, 3)
    prog = [(55, "M"), (50, "M"), (52, "m"), (48, "M")] * 4
    for bar, (root, kind) in enumerate(prog):
        b = bar * 3
        notes = chord_notes(root, kind)
        s.add("bass", pluck(midi(root - 12), 3.0, 0.3, 0.998), b, 0.5)
        picks = [notes[1] + 12, notes[2] + 12, notes[0] + 24, notes[2] + 12, notes[1] + 12, notes[2]]
        for k, m in enumerate(picks):
            s.add("guitar", pluck(midi(m), 1.8, 0.45, 0.997), b + k * 0.5, 0.3)
        s.add("pad", pad_chord(notes, 3.3 * s.beat, 800, 1.0), b, 0.15)
    crackle = np.zeros_like(s.buf)
    for _ in range(int(s.length * 14)):
        pos = rng.integers(0, len(crackle) - 400)
        crackle[pos:pos + 300] += highpass(noise(300), 1500) * env_exp(300, 0.0012) * rng.uniform(0.1, 0.8)
    s.buses["fire"] = crackle * 0.12 + lowpass(noise(len(crackle)), 300) * 0.05
    return s.render({"bass": 1, "guitar": 1, "pad": 1, "fire": 1}, 0.25, 1.1)


def write_ogg(name, x):
    os.makedirs(MUSIC_DIR, exist_ok=True)
    tmp = os.path.join(MUSIC_DIR, name + ".tmp.wav")
    write_wav(tmp, x)
    path = os.path.join(MUSIC_DIR, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", path], check=True)
    os.remove(tmp)
    print("music: %-7s %5.1f s" % (name, len(x) / SR))


if __name__ == "__main__":
    import sys
    sfx()
    sfx_combat()
    if "--sfx" in sys.argv:
        sys.exit(0)
    for name, fn in [("menu", song_menu), ("garden", song_garden), ("crypt", song_crypt), ("forge", song_forge), ("boss", song_boss), ("camp", song_camp)]:
        write_ogg(name, fn())
