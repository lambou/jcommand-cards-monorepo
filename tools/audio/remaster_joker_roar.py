"""Crop and remaster the Joker lion roar for the game.

    1. godot --headless --path apps/mobile -s <abs path>/tools/audio/decode_mp3.gd     (MP3 -> tools/audio/_roar_raw.f32)
    2. python tools/audio/remaster_joker_roar.py                                         (-> apps/mobile/assets/joker/joker_roar.wav)

Source: tools/audio/source/soundzee-lion-snarl-growl-354324.mp3 (outside the game folder: not imported or exported) (the clip's loud roar starts at ~3.9 s,
preceded by a quieter snarl from ~3.0 s). We keep 3.55 s .. 4.85 s so the roar's onset lands ~0.35 s after the
sound starts, the moment the mouth opens in the animation, and the whole thing is ~1.3 s like the animation.

Chain: mono (the stereo is ~identical) -> remove DC -> 70 Hz high-pass (rumble) -> 14 kHz low-pass (mp3 hiss)
-> fades -> gain to the game's level -> soft limiter so it never clips or distorts -> 16-bit WAV, 44.1 kHz.
The other game sounds peak around -5..-10 dBFS (loudest 100 ms -10..-17 dBFS); the old synthesised roar peaked at -4.1 dBFS.
"""
import wave

import numpy as np
from scipy.signal import butter, sosfiltfilt

SR = 44100
START, END = 3.55, 4.85
FADE_IN, FADE_OUT = 0.040, 0.300
TARGET_LOUD_DB = -12.5     # loudest 100 ms RMS
CEILING_DB = -4.5          # limiter ceiling (peak), well under clipping

RAW = "D:/develop/games/jcommand-cards-game/tools/audio/_roar_raw.f32"
OUT = "D:/develop/games/jcommand-cards-game/apps/mobile/assets/joker/joker_roar.wav"


def db(x):
    return 20 * np.log10(x + 1e-12)


def loudest_100ms(a):
    k = int(0.1 * SR)
    return max(np.sqrt((a[i:i + k] ** 2).mean()) for i in range(0, len(a) - k, k // 2))


def main():
    x = np.fromfile(RAW, dtype=np.float32).reshape(-1, 2).astype(np.float64)
    a = x.mean(axis=1)[int(START * SR):int(END * SR)]
    a = a - a.mean()
    a = sosfiltfilt(butter(2, 70, "highpass", fs=SR, output="sos"), a)
    a = sosfiltfilt(butter(4, 14000, "lowpass", fs=SR, output="sos"), a)
    n = len(a)
    fi, fo = int(FADE_IN * SR), int(FADE_OUT * SR)
    env = np.ones(n)
    env[:fi] = 0.5 - 0.5 * np.cos(np.pi * np.arange(fi) / fi)
    env[-fo:] = 0.5 + 0.5 * np.cos(np.pi * np.arange(fo) / fo)
    a = a * env
    a *= 10 ** (TARGET_LOUD_DB / 20) / loudest_100ms(a)
    # soft limiter: linear below the knee, smooth tanh curve up to the ceiling
    ceil = 10 ** (CEILING_DB / 20)
    knee = ceil * 0.6
    mag = np.abs(a)
    over = mag > knee
    lim = mag.copy()
    lim[over] = knee + (ceil - knee) * np.tanh((mag[over] - knee) / (ceil - knee))
    a = np.sign(a) * lim
    pcm = np.clip(np.round(a * 32767), -32768, 32767).astype("<i2")
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"{OUT}: {n / SR:.2f}s, peak {db(np.abs(a).max()):.1f} dBFS, loudest100ms {db(loudest_100ms(a)):.1f} dBFS, "
          f"rms {db(np.sqrt((a ** 2).mean())):.1f} dBFS, clipped samples {int((np.abs(pcm) >= 32767).sum())}")


main()
