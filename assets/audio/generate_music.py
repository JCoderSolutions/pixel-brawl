#!/usr/bin/env python3
"""Genera las pistas de música de Pixel Brawl (chiptune en loop).

Síntesis 100 % procedural con la librería estándar de Python, igual que
generate_sfx.py: sin samples externos, así que los .wav resultantes son obra
original del proyecto y se publican bajo CC0 1.0 (ver assets/audio/CREDITS.md).

Uso (desde la raíz del repo):
    python3 assets/audio/generate_music.py

Cada pista dura un número exacto de compases y ninguna nota suena más allá
del final, así que el loop no tiene saltos. Es determinista: volver a correrlo
produce los mismos archivos.
"""

import math
import os
import random
import struct
import wave

RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "music")


# --- Osciladores ------------------------------------------------------------

def freq(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def pulse(phase, duty):
    return 1.0 if (phase % 1.0) < duty else -1.0


def triangle(phase):
    p = phase % 1.0
    return 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p


class Track:
    def __init__(self, bpm, bars):
        self.step = 60.0 / bpm / 4.0  # una semicorchea
        self.steps = bars * 16
        self.length = int(round(self.steps * self.step * RATE))
        self.buf = [0.0] * self.length

    def _span(self, start_step, steps):
        start = int(round(start_step * self.step * RATE))
        count = int(round(steps * self.step * RATE))
        return start, min(count, self.length - start)

    def tone(self, start_step, steps, midi, wave_fn, volume, attack=0.004, release=0.35):
        """Nota con envolvente: ataque corto, caída suave hasta el final."""
        start, count = self._span(start_step, steps)
        f = freq(midi)
        attack_n = max(1, int(attack * RATE))
        release_n = max(1, int(count * release))
        for i in range(count):
            env = min(1.0, i / attack_n)
            if i > count - release_n:
                env *= (count - i) / release_n
            env *= 1.0 - 0.25 * i / count  # decae un poco durante la nota
            self.buf[start + i] += wave_fn(f * i / RATE) * volume * env

    def kick(self, start_step, volume=0.9):
        start, count = self._span(start_step, 2)
        count = min(count, int(0.12 * RATE))
        phase = 0.0
        for i in range(count):
            t = i / count
            phase += (140.0 - 95.0 * t) / RATE
            self.buf[start + i] += math.sin(2 * math.pi * phase) * volume * (1.0 - t) ** 2

    def noise(self, start_step, seconds, volume, seed, bright=False):
        rng = random.Random(seed)
        start, count = self._span(start_step, 4)
        count = min(count, int(seconds * RATE))
        last = 0.0
        hold = 0.0
        for i in range(count):
            # Ruido "NES": se renueva cada pocos samples; las variantes
            # brillantes restan el sample anterior (un pasa-altos barato).
            if i % (1 if bright else 3) == 0:
                hold = rng.uniform(-1.0, 1.0)
            value = hold - last if bright else hold
            last = hold
            self.buf[start + i] += value * volume * (1.0 - i / count) ** 2

    def samples(self, peak=0.8):
        top = max(abs(v) for v in self.buf) or 1.0
        return [v / top * peak for v in self.buf]


# --- Pistas -----------------------------------------------------------------

def chord_tones(root, minor):
    return [root, root + (3 if minor else 4), root + 7]


def battle():
    """150 BPM en Mi menor, 16 compases: arpegios, bajo bombeando y batería."""
    track = Track(bpm=150, bars=16)
    # (raíz MIDI, menor) por compás: A = Em Em C D x2, B = Am Em C B.
    part_a = [(52, True), (52, True), (48, False), (50, False)] * 2
    part_b = [(45, True), (52, True), (48, False), (47, False)] * 2
    progression = part_a + part_b
    melody_b = [  # (semicorchea dentro de 8 compases, nota, duración)
        (0, 76, 4), (4, 79, 4), (8, 78, 2), (10, 76, 2), (12, 74, 4),
        (16, 76, 6), (22, 71, 2), (24, 74, 4), (28, 76, 4),
        (32, 72, 4), (36, 76, 4), (40, 79, 4), (44, 81, 4),
        (48, 78, 8), (56, 75, 4), (60, 78, 4),
        (64, 76, 4), (68, 79, 4), (72, 78, 2), (74, 76, 2), (76, 74, 4),
        (80, 71, 6), (86, 74, 2), (88, 76, 8),
        (96, 72, 4), (100, 71, 4), (104, 72, 4), (108, 74, 4),
        (112, 75, 8), (120, 71, 8),
    ]
    for bar, (root, minor) in enumerate(progression):
        base = bar * 16
        tones = chord_tones(root, minor)
        for eighth in range(8):
            note = root - 12 + (12 if eighth % 2 else 0)
            track.tone(base + eighth * 2, 2, note, triangle, 0.55, release=0.3)
        arp = [tones[0] + 12, tones[1] + 12, tones[2] + 12, tones[1] + 24]
        for i in range(16):
            track.tone(base + i, 1, arp[i % 4], lambda p: pulse(p, 0.125), 0.13, release=0.6)
        for beat in range(4):
            if beat % 2 == 0:
                track.kick(base + beat * 4)
            else:
                track.noise(base + beat * 4, 0.14, 0.45, seed=bar * 4 + beat)
            track.noise(base + beat * 4 + 2, 0.04, 0.18, seed=1000 + bar * 4 + beat, bright=True)
        if bar % 4 == 3:
            track.kick(base + 14, 0.6)
    # Melodía principal: en la parte A se anticipa con notas largas, en la B canta.
    for bar, (root, minor) in enumerate(part_a):
        tones = chord_tones(root, minor)
        track.tone(bar * 16, 8, tones[2] + 12, lambda p: pulse(p, 0.25), 0.16)
        track.tone(bar * 16 + 8, 8, tones[1] + 12, lambda p: pulse(p, 0.25), 0.16)
    for step, note, length in melody_b:
        track.tone(128 + step, length, note, lambda p: pulse(p, 0.25), 0.22, release=0.25)
    return track


def menu():
    """100 BPM en La menor, 8 compases: tranquilo, para elegir mapa y bots."""
    track = Track(bpm=100, bars=8)
    progression = [(45, True), (41, False), (48, False), (43, False)] * 2
    melody = [
        (0, 76, 6), (6, 74, 2), (8, 72, 8),
        (16, 72, 6), (22, 69, 2), (24, 72, 8),
        (32, 71, 6), (38, 72, 2), (40, 74, 8),
        (48, 71, 8), (56, 67, 8),
        (64, 76, 6), (70, 77, 2), (72, 79, 8),
        (80, 77, 6), (86, 76, 2), (88, 72, 8),
        (96, 72, 4), (100, 74, 4), (104, 76, 8),
        (112, 74, 8), (120, 71, 8),
    ]
    for bar, (root, minor) in enumerate(progression):
        base = bar * 16
        tones = chord_tones(root, minor)
        track.tone(base, 8, root - 12, triangle, 0.6, release=0.4)
        track.tone(base + 8, 8, root - 5, triangle, 0.6, release=0.4)
        arp = [tones[0] + 12, tones[1] + 12, tones[2] + 12, tones[1] + 12]
        for i in range(8):
            track.tone(base + i * 2, 2, arp[i % 4], lambda p: pulse(p, 0.125), 0.12, release=0.7)
        for beat in range(4):
            track.noise(base + beat * 4 + 2, 0.03, 0.12, seed=2000 + bar * 4 + beat, bright=True)
    for step, note, length in melody:
        track.tone(step, length, note, lambda p: pulse(p, 0.5), 0.18, attack=0.01, release=0.3)
    return track


def write(name, track):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".wav")
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in track.samples())
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(frames)
    print("%s: %.1f s, %d KB" % (path, track.length / RATE, len(frames) // 1024))


if __name__ == "__main__":
    write("battle", battle())
    write("menu", menu())
