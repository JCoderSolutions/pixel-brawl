#!/usr/bin/env python3
"""Genera los efectos de sonido de Pixel Brawl (estilo sfxr/chiptune).

Síntesis 100 % procedural con la librería estándar de Python: no usa ningún
sample externo, así que los .wav resultantes son obra original del proyecto y
se publican bajo CC0 1.0 (ver assets/audio/CREDITS.md).

Uso (desde la raíz del repo):
    python3 assets/audio/generate_sfx.py

Es determinista (semilla fija por sonido): volver a correrlo produce los
mismos archivos, así que solo hace falta si se cambia una receta.
"""

import math
import os
import random
import struct
import wave

RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sfx")


# --- Osciladores y envolventes ------------------------------------------------

def square(phase, duty=0.5):
    return 1.0 if (phase % 1.0) < duty else -1.0


def triangle(phase):
    p = phase % 1.0
    return 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p


def env(t, length, attack=0.005, power=1.0):
    """Ataque lineal corto y caída (1 - x)^power hasta el final."""
    if t < attack:
        return t / attack
    x = min((t - attack) / max(length - attack, 1e-6), 1.0)
    return (1.0 - x) ** power


class Noise:
    """Ruido blanco con sample-and-hold: `rate` bajo suena más grave (sfxr)."""

    def __init__(self, seed, lowpass=1.0):
        self.rng = random.Random(seed)
        self.value = 0.0
        self.acc = 0.0
        self.lp = 0.0
        self.alpha = lowpass

    def sample(self, rate):
        self.acc += rate / RATE
        if self.acc >= 1.0:
            self.acc %= 1.0
            self.value = self.rng.uniform(-1.0, 1.0)
        self.lp += self.alpha * (self.value - self.lp)
        return self.lp


def render(length, fn):
    n = int(length * RATE)
    return [fn(i / RATE) for i in range(n)]


def sweep(f0, f1, length, curve=1.0):
    """Devuelve una función t -> fase acumulada para un barrido f0 -> f1."""
    state = {"phase": 0.0}

    def phase_at(t):
        x = min(t / length, 1.0) ** curve
        state["phase"] += (f0 + (f1 - f0) * x) / RATE
        return state["phase"]

    return phase_at


# --- Recetas ------------------------------------------------------------------

def punch():
    noise = Noise(1, lowpass=0.35)
    ph = sweep(180, 50, 0.12)
    return render(0.12, lambda t: env(t, 0.12, 0.002, 2.0) * (
        0.55 * noise.sample(9000) + 0.6 * math.sin(2 * math.pi * ph(t))))


def hit():
    noise = Noise(2, lowpass=0.5)
    ph = sweep(260, 90, 0.09)
    return render(0.09, lambda t: env(t, 0.09, 0.001, 2.5) * (
        0.6 * noise.sample(12000) + 0.4 * square(ph(t), 0.3)))


def ricochet():
    noise = Noise(3, lowpass=0.8)
    ph = sweep(2400, 900, 0.16, 0.6)
    return render(0.16, lambda t: env(t, 0.16, 0.001, 1.6) * (
        0.35 * square(ph(t), 0.25) + 0.3 * noise.sample(20000) * env(t, 0.04)))


def shot():
    noise = Noise(4, lowpass=0.6)
    ph = sweep(900, 120, 0.16, 0.5)
    return render(0.18, lambda t: env(t, 0.18, 0.001, 3.0) * (
        0.75 * noise.sample(16000) + 0.35 * square(ph(t), 0.5)))


def shotgun():
    noise = Noise(5, lowpass=0.3)
    ph = sweep(300, 40, 0.3)
    return render(0.32, lambda t: env(t, 0.32, 0.001, 2.2) * (
        0.85 * noise.sample(7000) + 0.35 * math.sin(2 * math.pi * ph(t))))


def swing():
    noise = Noise(6, lowpass=0.15)
    return render(0.16, lambda t: math.sin(math.pi * min(t / 0.16, 1.0)) * 0.7 *
                  noise.sample(3000 + 14000 * t / 0.16))


def throw():
    noise = Noise(7, lowpass=0.1)
    return render(0.2, lambda t: math.sin(math.pi * min(t / 0.2, 1.0)) * 0.6 *
                  noise.sample(6000 - 3000 * t / 0.2))


def explosion():
    noise = Noise(8, lowpass=0.12)
    rumble = Noise(9, lowpass=0.04)
    ph = sweep(90, 25, 0.9)
    return render(0.9, lambda t: env(t, 0.9, 0.003, 1.8) * (
        0.8 * noise.sample(5000 - 4000 * min(t / 0.9, 1.0)) +
        0.7 * rumble.sample(1200) + 0.35 * math.sin(2 * math.pi * ph(t))))


def block_hit():
    noise = Noise(10, lowpass=0.25)
    ph = sweep(140, 70, 0.08)
    return render(0.08, lambda t: env(t, 0.08, 0.001, 2.0) * (
        0.5 * noise.sample(4000) + 0.5 * triangle(ph(t))))


def block_break():
    noise = Noise(11, lowpass=0.4)
    crackle = random.Random(12)

    def fn(t):
        # Caída a escalones: varios "crujidos" en vez de un solo golpe.
        step = 1.0 - 0.25 * int(t / 0.06)
        grit = 1.0 if crackle.random() > 0.3 else 0.4
        return env(t, 0.28, 0.001, 1.2) * max(step, 0.2) * grit * noise.sample(6000)

    return render(0.28, fn)


def jump():
    ph = sweep(220, 560, 0.12, 0.7)
    return render(0.12, lambda t: env(t, 0.12, 0.004, 1.0) * 0.4 * square(ph(t), 0.25))


def land():
    noise = Noise(13, lowpass=0.08)
    return render(0.08, lambda t: env(t, 0.08, 0.001, 2.0) * 0.8 * noise.sample(2500))


def death():
    notes = [523.25, 392.0, 311.13, 196.0]
    ph = {"phase": 0.0}

    def fn(t):
        i = min(int(t / 0.09), len(notes) - 1)
        ph["phase"] += notes[i] * (1.0 - 0.15 * ((t % 0.09) / 0.09)) / RATE
        return env(t, 0.42, 0.004, 0.8) * 0.4 * square(ph["phase"], 0.5)

    return render(0.42, fn)


def pickup():
    ph = {"phase": 0.0}

    def fn(t):
        ph["phase"] += (660.0 if t < 0.06 else 990.0) / RATE
        return env(t, 0.14, 0.003, 1.0) * 0.35 * square(ph["phase"], 0.5)

    return render(0.14, fn)


def dry_fire():
    """Clic metálico seco: el gatillo de un arma sin balas."""
    ph = sweep(2400, 1800, 0.03)
    ph2 = sweep(1600, 1200, 0.03)
    return render(0.07, lambda t: 0.5 * env(t, 0.025, 0.0005, 3.0) * square(ph(t), 0.3) +
                  (0.4 * env(t - 0.035, 0.03, 0.0005, 3.0) * square(ph2(t - 0.035), 0.3) if t > 0.035 else 0.0))


RECIPES = {
    "punch": punch,
    "hit": hit,
    "ricochet": ricochet,
    "shot": shot,
    "shotgun": shotgun,
    "swing": swing,
    "throw": throw,
    "explosion": explosion,
    "block_hit": block_hit,
    "block_break": block_break,
    "jump": jump,
    "land": land,
    "death": death,
    "pickup": pickup,
    "dry_fire": dry_fire,
}


def write_wav(path, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.9 / peak if peak > 0.9 else 1.0
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, recipe in RECIPES.items():
        path = os.path.join(OUT_DIR, name + ".wav")
        write_wav(path, recipe())
        print("ok", os.path.relpath(path))


if __name__ == "__main__":
    main()
