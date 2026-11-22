from pathlib import Path
import math
import wave
import numpy as np

RATE = 48000
SECONDS = 38
BEAT = 60 / 108
CUTS = [0, 3.4, 7.5, 11.0, 15.5, 19.5, 23.5, 25.4, 28.4, 34.0]
rng = np.random.default_rng(4242)
mix = np.zeros((RATE * SECONDS, 2), np.float64)


def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def time(duration):
    return np.arange(int(RATE * duration)) / RATE


def add(start, tone, gain, pan=0.0):
    begin = round(start * RATE)
    count = min(len(tone), len(mix) - begin)
    if count <= 0:
        return
    mix[begin:begin + count, 0] += tone[:count] * gain * math.sqrt((1 - pan) / 2)
    mix[begin:begin + count, 1] += tone[:count] * gain * math.sqrt((1 + pan) / 2)


def fade(t, up, down):
    return np.clip(t / up, 0, 1) * np.clip((t[-1] - t) / down, 0, 1)


def soft_synth(note, duration, seed):
    t = time(duration)
    f = hz(note)
    wave_a = np.sin(2 * np.pi * f * t + .11 * np.sin(2 * np.pi * (4.1 + seed * .06) * t))
    wave_b = np.sin(2 * np.pi * f * 1.003 * t + seed)
    overtone = np.sin(2 * np.pi * (f * 2.0 * t + .2 * np.sin(2 * np.pi * f * t)))
    return (.45 * wave_a + .37 * wave_b + .12 * overtone) * fade(t, .52, .74)


def pluck(note, duration):
    t = time(duration)
    f = hz(note)
    base = np.sin(2 * np.pi * f * t)
    harmonics = .35 * np.sin(2 * np.pi * 2.005 * f * t) * np.exp(-t * 8)
    bell = .17 * np.sin(2 * np.pi * 3.01 * f * t) * np.exp(-t * 24)
    return (base + harmonics + bell) * np.minimum(1,t*250) * np.exp(-t*6.2)


def bass(note, duration):
    t = time(duration)
    f = hz(note)
    signal = np.sin(2 * np.pi * f * t) + .24 * np.sin(2 * np.pi * f * 2 * t)
    return signal * fade(t, .02, .09) * np.exp(-t * 1.5)


def kick():
    t = time(.38)
    phase = 2*np.pi * (47*t + 78*(1-np.exp(-46*t))/46)
    return np.sin(phase) * np.exp(-t * 12) * np.minimum(1,t*700)


def hat(long=False):
    t = time(.13 if long else .058)
    noise = rng.normal(0,1,len(t))
    diff = np.diff(noise,prepend=0)*.44
    return diff * np.minimum(1,t*510) * np.exp(-t*(31 if long else 64))


def snare():
    t = time(.24)
    white = rng.normal(0, 1, len(t))
    crack = np.diff(white, prepend=0)*.5
    ring = np.sin(2*np.pi*(172*t + .55*(1-np.exp(-t*27))))
    return (.69*crack*np.exp(-t*23) + .26*ring*np.exp(-t*31)) * np.minimum(1,t*640)


def impact(duration):
    t = time(duration)
    noise = rng.normal(0,1,len(t))
    fizz = np.diff(noise,prepend=0)*.22
    f = 2*np.pi*(35*t + 32*(1-np.exp(-t*9))/9)
    return (.85*np.sin(f)*np.exp(-t*5.2) + fizz*np.exp(-t*10)) * np.minimum(1,t*320)


def rise(duration):
    t = time(duration)
    a = t/duration
    white = rng.normal(0,1,len(t))
    tone = np.sin(2*np.pi*(110*t + 180*t*t))
    sound = .19*tone + np.diff(white,prepend=0)*.46
    return sound*a**2*np.clip((duration-t)/.04,0,1)


chords = [(45,52,55,59,64),(41,48,52,55,60),(48,55,59,62,67),(43,50,53,57,62)]
for bar in range(17):
    t = bar * 4 * BEAT
    notes = chords[bar % 4]
    if t > SECONDS - 1.4:
        break
    final = t >= 33.33
    gain = .057 if final else .034 + .013 * (t > 12)
    for j, note in enumerate(notes):
        add(t+j*.026, soft_synth(note, 4*BEAT+.50, j), gain, [-.11,-.68,.59,-.35,.43][j])
    if 2 <= bar <= 14:
        for k, index in enumerate([2,4,3,4,2,3,4,3]):
            if bar == 12 and k < 5:
                continue
            at=t+k*BEAT/2
            pan=-.32 if k%2==0 else .32
            tone=pluck(notes[index]+12, .63)
            add(at,tone,.049 if k%2==0 else .035,pan)
            add(at+.25,tone,.013,-pan)
            if k%2==0:
                add(at,bass(notes[0]-12,BEAT*.77),.13,0)
        for beat in (0, 2):
            add(t+beat*BEAT,kick(),.28)
        for beat in (1,3):
            add(t+beat*BEAT,snare(),.15,.05)
        for k in range(8):
            add(t+k*BEAT/2,hat(k in {3,7}),.037 if k%2 else .023,.33 if k%2 else -.34)

for i, t in enumerate(CUTS):
    if i:
        add(max(0,t-.44),rise(.44),.16, .3 if i%2 else -.3)
    add(t,impact(.94),.24 if i in {0,2,5,8,9} else .14)
    add(t+.06,pluck([80,76,81,77][i%4],.82),.060,.22 if i%2 else -.22)

for i, note in enumerate([69,76,81,83,81]):
    t=.27 + i*.41
    sound=pluck(note,1.02)
    add(t,sound,.12,(i%2-.5)*.76)
    add(t+.29,sound,.035,(.5-i%2)*.76)

for i,note in enumerate([69,76,79,83,88]):
    at=34+i*.29
    sound=pluck(note,1.21)
    add(at,sound,.10,(i%2-.5)*.65)
    add(at+.32,sound,.025,(.5-i%2)*.65)

t=time(SECONDS)
mix *= (np.minimum(1,t/.018) * np.clip((SECONDS-t)/.95,0,1))[:,None]
mix = np.tanh(mix*1.4) * .91
out=Path(__file__).resolve().parent / "promo-score.wav"
with wave.open(str(out),"wb") as wf:
    wf.setnchannels(2)
    wf.setsampwidth(2)
    wf.setframerate(RATE)
    wf.writeframes(np.int16(np.clip(mix,-1,1)*32767).tobytes())

