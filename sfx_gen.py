#!/usr/bin/env python3
"""PICO-8 SFX hex data generator.

Usage: python3 sfx_gen.py
Outputs SFX lines ready to paste into a .p8 file's __sfx__ section.
"""

def note(name, octave, wave, vol, effect=0):
    """Convert note name to 5-char hex string.

    Pitches: C0=0, C1=12, C2=24, C3=36, C4=48
    Semitones: C=0, D=2, E=4, F=5, G=7, A=9, B=11

    Waveforms: 0=triangle, 1=tilted saw, 2=saw, 3=square,
               4=pulse, 5=organ, 6=noise, 7=phaser

    Effects: 0=none, 1=slide, 2=vibrato, 3=drop,
             4=fade in, 5=fade out, 6=arp fast, 7=arp slow
    """
    names = {'c':0,'d':2,'e':4,'f':5,'g':7,'a':9,'b':11}
    pitch = names[name.lower()] + octave * 12
    return f"{pitch:02x}{wave}{vol}{effect}"

def rest():
    return "00000"

def sfx_line(speed, notes, loop_start=0, loop_end=0):
    """Build a 168-char SFX line. Pads with rests to 32 notes."""
    while len(notes) < 32:
        notes.append(rest())
    header = f"01{speed:02x}{loop_start:02x}{loop_end:02x}"
    line = header + "".join(notes[:32])
    assert len(line) == 168, f"Expected 168 chars, got {len(line)}"
    return line


if __name__ == "__main__":
    N = note
    R = rest

    # --- Game SFX (0-4) ---

    # SFX 0: Select blip (triangle, speed 4)
    sfx_0 = sfx_line(4, [
        N('e',2,0,7), N('g',2,0,6), N('c',3,0,5), N('c',3,0,3),
    ])

    # SFX 1: Capture thud (saw, speed 3)
    sfx_1 = sfx_line(3, [
        N('c',1,2,7), N('g',0,2,6), N('e',0,2,5), N('d',0,2,4),
    ])

    # SFX 2: Invalid buzz (noise, speed 1)
    sfx_2 = sfx_line(1, [
        N('a',0,6,5), N('g',0,6,3),
    ])

    # SFX 3: Win fanfare (square, speed 8)
    sfx_3 = sfx_line(8, [
        N('c',2,3,7), N('c',2,3,5), R(),
        N('e',2,3,7), N('e',2,3,5), R(),
        N('g',2,3,7), N('g',2,3,5), R(),
        N('c',3,3,7), N('c',3,3,7), N('c',3,3,5,5), N('c',3,3,5),
    ])

    # SFX 4: Menu tick (triangle, speed 1)
    sfx_4 = sfx_line(1, [
        N('c',3,0,4),
    ])

    # --- Music SFX (8-11) ---

    # SFX 8: Melody A (organ, speed 12)
    sfx_8 = sfx_line(12, [
        N('c',3,5,5), N('e',3,5,5), N('g',3,5,5), N('e',3,5,5),
        N('c',3,5,5), N('e',3,5,5), N('g',3,5,5), R(),
        N('f',3,5,5), N('a',3,5,5), N('g',3,5,5), N('e',3,5,5),
        N('f',3,5,5), N('e',3,5,5), N('d',3,5,5), R(),
        N('c',3,5,5), N('e',3,5,5), N('g',3,5,5), N('a',3,5,5),
        N('g',3,5,5), N('e',3,5,5), N('c',3,5,5), R(),
        N('d',3,5,5), N('e',3,5,5), N('d',3,5,5), N('c',3,5,4),
        N('c',3,5,3), R(), R(), R(),
    ])

    # SFX 9: Melody B (organ, speed 12)
    sfx_9 = sfx_line(12, [
        N('e',3,5,5), N('g',3,5,5), N('a',3,5,5), N('g',3,5,5),
        N('e',3,5,5), N('g',3,5,5), N('c',4,5,5), R(),
        N('a',3,5,5), N('g',3,5,5), N('e',3,5,5), N('g',3,5,5),
        N('a',3,5,5), N('g',3,5,5), N('e',3,5,5), R(),
        N('c',3,5,5), N('d',3,5,5), N('e',3,5,5), N('g',3,5,5),
        N('a',3,5,5), N('g',3,5,5), N('e',3,5,5), N('d',3,5,5),
        N('c',3,5,5), N('c',3,5,4), N('c',3,5,3), R(),
        R(), R(), R(), R(),
    ])

    # SFX 10: Bass A (triangle, speed 12)
    sfx_10 = sfx_line(12, [
        N('c',2,0,4), R(), N('c',2,0,3), R(),
        N('c',2,0,4), R(), N('c',2,0,3), R(),
        N('f',2,0,4), R(), N('f',2,0,3), R(),
        N('f',2,0,4), R(), N('f',2,0,3), R(),
        N('c',2,0,4), R(), N('c',2,0,3), R(),
        N('g',2,0,4), R(), N('g',2,0,3), R(),
        N('f',2,0,4), R(), N('g',2,0,4), R(),
        N('c',2,0,4,5), R(), R(), R(),
    ])

    # SFX 11: Bass B (triangle, speed 12)
    sfx_11 = sfx_line(12, [
        N('a',1,0,4), R(), N('a',1,0,3), R(),
        N('a',1,0,4), R(), N('a',1,0,3), R(),
        N('f',2,0,4), R(), N('f',2,0,3), R(),
        N('g',2,0,4), R(), N('g',2,0,3), R(),
        N('c',2,0,4), R(), N('c',2,0,3), R(),
        N('g',2,0,4), R(), N('g',2,0,3), R(),
        N('f',2,0,4), R(), N('g',2,0,4), R(),
        N('c',2,0,4,5), R(), R(), R(),
    ])

    # Print all
    all_sfx = [sfx_0, sfx_1, sfx_2, sfx_3, sfx_4,
               None, None, None,  # 5-7 unused
               sfx_8, sfx_9, sfx_10, sfx_11]

    print("__sfx__")
    for i, s in enumerate(all_sfx):
        if s:
            print(f"{s}  -- SFX {i}")
        else:
            # empty placeholder
            print("001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")

    print()
    print("__music__")
    print("01 080a4141  -- pattern 0: melody A + bass A (loop start)")
    print("02 090b4141  -- pattern 1: melody B + bass B (loop end)")
