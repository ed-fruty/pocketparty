"""Create an original relaxed instrumental loop, with no external audio samples."""
from pathlib import Path
import wave
import numpy as np

rate, bpm, bars = 22050, 78, 8
beat = 60 / bpm
seconds = bars * 4 * beat
track = np.zeros((round(rate * seconds), 2), dtype=np.float64)
rng = np.random.default_rng(24)

def add(sound, when, pan=0.5):
    # Wrap ringing tails into the start so the loop stays continuous.
    indices = (round(when * rate) + np.arange(len(sound))) % len(track)
    for channel, gain in enumerate([np.cos(pan * np.pi / 2), np.sin(pan * np.pi / 2)]):
        np.add.at(track[:, channel], indices, sound * gain)

def note(midi, duration, gain, kind='pluck'):
    t = np.arange(round(duration * rate)) / rate
    frequency = 440 * 2 ** ((midi - 69) / 12)
    if kind == 'bass':
        tone = np.sin(2*np.pi*frequency*t) + .15*np.sin(4*np.pi*frequency*t)
        envelope = (1-np.exp(-t*80))*np.exp(-t*4)
    else:
        tone = np.sin(2*np.pi*frequency*t) + .10*np.sin(2*np.pi*frequency*2*t)*np.exp(-t*6)
        envelope = (1-np.exp(-t*180))*np.exp(-t*3.2)
    return tone * envelope * gain

chords = [(60,64,67), (57,60,64), (53,57,60), (55,59,62)]
melodies = [
    [76,79,81,79,76,74,72,74],
    [76,72,69,72,76,79,76,72],
    [77,76,72,69,72,76,77,76],
    [74,71,67,71,74,79,74,72],
]
for bar in range(bars):
    chord = chords[bar % 4]
    start = bar * 4 * beat
    for n, midi in enumerate(melodies[bar % 4]):
        # A little breathing room and variation in the second half.
        if n % 2 or (n == 6 and bar % 2):
            continue
        if bar >= 8 and n in [2,6]:
            midi = chord[n % 3] + 12
        add(note(midi - 12, 1.4, .035), start + n * beat / 2, .4 if n % 2 else .6)
    for pulse in [0,2]:
        add(note(chord[0]-24, .7, .035, 'bass'), start + pulse*beat)
    for pulse in [1,3]:
        for voice, midi in enumerate(chord):
            add(note(midi, .5, .012), start + pulse*beat, .25 + voice*.25)
    for pulse in range(4):
        t = np.arange(round(.12*rate))/rate
        brush = rng.normal(0,1,len(t))
        brush = np.concatenate(([0.0], np.diff(brush))) * np.exp(-t*65) * (1-np.exp(-t*600))*.004
        add(brush, start + (pulse+.5)*beat, .65)
# Gentle saturation; preserve the previous music player's volume setting.
track = np.tanh(track)
# Master the source at an audible level; keep the in-game volume unchanged.
rms = np.sqrt(np.mean(track ** 2))
gain = min(0.16 / max(rms, 1e-9), 0.9 / max(np.abs(track).max(), 1e-9))
track *= gain
assert 0.12 <= np.sqrt(np.mean(track ** 2)) <= 0.18
assert np.abs(track).max() <= 0.90001
path = Path(__file__).resolve().parents[1] / 'assets/audio/party_ambient.wav'
with wave.open(str(path), 'wb') as output:
    output.setnchannels(2)
    output.setsampwidth(2)
    output.setframerate(rate)
    output.writeframes((track * 32767).astype('<i2').tobytes())
print(f'{seconds:.1f}s original relaxed loop; peak {np.abs(track).max():.3f}, RMS {np.sqrt(np.mean(track**2)):.3f}')
