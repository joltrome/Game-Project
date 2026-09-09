#!/usr/bin/env python3
"""Candidate C only: original non-fade master, 40 bars, bounded endpoint comparison."""
import argparse
import array
import json
import math
from pathlib import Path
import sys
import wave

from create_vm061_loop_candidates import (
    EXPECTED_SHA, RATE, digest, float_bytes, load_float, measurements, write_float,
)

BAR_SECONDS = 4 * 60 / 104
EXACT_END = round(40 * BAR_SECONDS * RATE)
SEARCH_RADIUS = 96  # +/-2ms; never move the loop start away from original frame zero.
CONTEXT = round(4 * BAR_SECONDS * RATE)


def preview(path, samples):
    """Three 4-bar tail -> 4-bar head joins, separated by 1s of silence.

    Only the outer excerpt edges get 20ms fades. No candidate or join is faded.
    """
    excerpt = array.array('f', samples[-CONTEXT*2:])
    excerpt.extend(samples[:CONTEXT*2])
    for i in range(960):
        gain = .5 - .5 * math.cos(math.pi*i/959)
        for ch in range(2):
            excerpt[i*2+ch] *= gain
            excerpt[(len(excerpt)//2-1-i)*2+ch] *= gain
    pcm = array.array('h', (max(-32768, min(32767, round(v*32768))) for v in excerpt))
    if sys.byteorder != 'little': pcm.byteswap()
    with wave.open(str(path), 'wb') as out:
        out.setparams((2,2,RATE,0,'NONE','not compressed'))
        for i in range(3):
            if i: out.writeframes(bytes(RATE*4))
            out.writeframes(pcm.tobytes())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    assert digest(args.source) == EXPECTED_SHA
    original, raw = load_float(args.source)
    assert len(original)//2 > EXACT_END + SEARCH_RADIUS
    args.output.mkdir(parents=True, exist_ok=True)

    def seam_error(end):
        return max(abs(original[c]-original[2*(end-1)+c]) for c in range(2))

    # Match the actual (nonzero) first sample in BOTH channels. A zero crossing
    # alone would not match the start. This score is not a perceptual judgment.
    best_end = min(range(EXACT_END-SEARCH_RADIUS, EXACT_END+SEARCH_RADIUS+1),
                   key=lambda end: (seam_error(end), abs(end-EXACT_END)))
    report = {
        'source':str(args.source), 'source_sha256':EXPECTED_SHA,
        'source_frames':len(original)//2, 'rate':RATE, 'channels':2,
        'bpm':104, 'meter':'4/4', 'bars':40,
        'mathematical_boundary_seconds':40*BAR_SECONDS,
        'exact_nearest_frame':EXACT_END,
        'rounding_error_microseconds':(EXACT_END/RATE-40*BAR_SECONDS)*1e6,
        'search':{'radius_frames':SEARCH_RADIUS, 'radius_ms':2,
                  'bounds_inclusive':[EXACT_END-SEARCH_RADIUS,EXACT_END+SEARCH_RADIUS],
                  'criterion':'minimize max absolute L/R last-to-first sample difference; closest endpoint breaks ties',
                  'chosen_comparison_end':best_end, 'offset_frames':best_end-EXACT_END,
                  'offset_ms':(best_end-EXACT_END)/48},
        'no_sample_modification':True, 'no_runtime_selection':True,
        'preview':{'context_frames_each_side':CONTEXT, 'context_bars_each_side':4,
                   'join_seconds':[(CONTEXT+i*(2*CONTEXT+RATE))/RATE for i in range(3)],
                   'outer_excerpt_edge_fades_ms':20, 'separator_seconds':1,
                   'format':'48kHz stereo PCM16; no normalization'},
        'candidates':{}, 'files':{},
        'validation':{},
    }
    for name,end in [('C_exact_40_bars',EXACT_END),('C_nearby_endpoint',best_end)]:
        samples = array.array('f', original[:end*2])
        assert float_bytes(samples)==raw[:end*8]
        stats = measurements(samples)
        stats.update({'retained_frame_interval':[0,end],
                      'removed_frame_interval':[end,len(original)//2],
                      'removed_frames':len(original)//2-end,
                      'four_loop_join_seconds':[end/RATE*i for i in range(1,4)]})
        report['candidates'][name]=stats
        candidate=args.output/(name+'.wav');write_float(candidate,samples)
        assert load_float(candidate)[1]==raw[:end*8]
        repeated=args.output/(name+'_four_full_loops.wav');write_float(repeated,samples,4)
        assert load_float(repeated)[1]==raw[:end*8]*4
        short=args.output/(name+'_preview.wav');preview(short,samples)
        for p in [candidate,repeated,short]:
            report['files'][p.name]={'bytes':p.stat().st_size,'sha256':digest(p)}
    assert digest(args.source)==EXPECTED_SHA
    report['validation']={'original_unchanged':True,'both_prefixes_byte_exact':True,
                           'both_four_loop_files_byte_exact':True,'at_least_three_joins':True,
                           'adjustment_within_2ms':abs(best_end-EXACT_END)<=SEARCH_RADIUS}
    (args.output/'sample-edits.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['exact_nearest_frame','rounding_error_microseconds','search','preview','candidates','validation']},indent=2))

if __name__=='__main__': main()
