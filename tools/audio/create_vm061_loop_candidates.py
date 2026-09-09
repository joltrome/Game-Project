#!/usr/bin/env python3
"""Reproduce the authorized VM061 A/B experiment, never a runtime selection.

Only Python standard-library code is used. Source: stereo 48kHz float32 RIFF WAV.
Every frame interval is zero-based and half-open. Outputs go outside runtime assets.
"""
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import wave

FRAMES = 4_541_538  # nearest integral frame to 41 * 4 * 60 / 104 * 48000
RATE = 48_000
TREATMENT = 96  # 2 ms support; last weight is exactly zero
EXPECTED_SHA = '1e12cc678e944c2ea1aa560653c1c07e3b26a1dbdd9dfead40d3deced3b391d4'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_float(path):
    raw = path.read_bytes()
    assert raw[:4] == b'RIFF' and raw[8:12] == b'WAVE'
    pos, fmt, data = 12, None, None
    while pos + 8 <= len(raw):
        key, length = struct.unpack_from('<4sI', raw, pos)
        value = raw[pos + 8:pos + 8 + length]
        if key == b'fmt ': fmt = struct.unpack_from('<HHIIHH', value)
        if key == b'data': data = value
        pos += 8 + length + length % 2
    assert fmt == (3, 2, RATE, RATE * 8, 8, 32), fmt
    samples = array.array('f', data)
    if sys.byteorder != 'little': samples.byteswap()
    return samples, data


def float_bytes(samples):
    copy = array.array('f', samples)
    if sys.byteorder != 'little': copy.byteswap()
    return copy.tobytes()


def write_float(path, samples, repeats=1):
    data = float_bytes(samples)
    fmt = struct.pack('<HHIIHH', 3, 2, RATE, RATE * 8, 8, 32)
    fact = struct.pack('<I', len(samples) // 2 * repeats)
    with path.open('wb') as out:
        out.write(b'RIFF' + struct.pack('<I', 4 + 24 + 12 + 8 + len(data)*repeats) + b'WAVE')
        out.write(b'fmt ' + struct.pack('<I', 16) + fmt)
        out.write(b'fact' + struct.pack('<I', 4) + fact)
        out.write(b'data' + struct.pack('<I', len(data)*repeats))
        for _ in range(repeats): out.write(data)


def audition(path, samples):
    """Three independent six-second boundary excerpts; 1 s silence between.

    Preview-only 20ms edge fades suppress artificial excerpt-start/end clicks.
    True candidate boundaries are untouched and at 3, 10 and 17 seconds.
    """
    excerpt = array.array('f', samples[-3*RATE*2:])
    excerpt.extend(samples[:3*RATE*2])
    ramp = 960
    for i in range(ramp):
        gain = 0.5 - 0.5 * math.cos(math.pi * i / (ramp - 1))
        for ch in range(2):
            excerpt[i*2+ch] *= gain
            excerpt[(len(excerpt)//2-1-i)*2+ch] *= gain
    pcm = array.array('h', (max(-32768, min(32767, round(x*32768))) for x in excerpt))
    if sys.byteorder != 'little': pcm.byteswap()
    with wave.open(str(path), 'wb') as out:
        out.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        for repeat in range(3):
            if repeat: out.writeframes(bytes(RATE*4))
            out.writeframes(pcm.tobytes())


def measurements(samples):
    jump = [float(samples[c]-samples[-2+c]) for c in range(2)]
    edge = array.array('f', samples[-96:]); edge.extend(samples[:96])
    return {
        'frames': len(samples)//2,
        'duration_seconds': len(samples)/2/RATE,
        'wrap_step_L_R': jump,
        'wrap_step_peak_dbfs': 20*math.log10(max(map(abs,jump))) if any(jump) else None,
        'first_frame_L_R': list(samples[:2]),
        'last_frame_L_R': list(samples[-2:]),
        'peak': max(map(abs,samples)),
        'rms': math.sqrt(sum(x*x for x in samples)/len(samples)),
    }


def main():
    parser=argparse.ArgumentParser();parser.add_argument('source',type=Path);parser.add_argument('output',type=Path)
    args=parser.parse_args();source_sha=digest(args.source)
    assert source_sha==EXPECTED_SHA, 'Different master: inspect rather than silently editing it.'
    args.output.mkdir(parents=True,exist_ok=True)
    original, original_bytes=load_float(args.source)
    a=array.array('f',original[:FRAMES*2]);b=array.array('f',a)
    for n in range(TREATMENT):
        weight=(1+math.cos(math.pi*n/(TREATMENT-1)))/2
        for ch in range(2): b[n*2+ch]=a[n*2+ch]-a[ch]*weight
    # Exact preservation guarantees; candidate A is only a sample-aligned trim.
    assert float_bytes(a)==original_bytes[:FRAMES*8]
    assert b[TREATMENT*2:]==a[TREATMENT*2:]
    assert b[:2]==b[-2:]==array.array('f',[0.,0.])
    assert len(a)==len(b)==FRAMES*2
    zero_near_first_cross=min(range(70,81),key=lambda i:max(abs(a[2*i]),abs(a[2*i+1])))
    report={
        'source':str(args.source),'source_sha256':source_sha,
        'source_frames':len(original)//2,'sample_rate':RATE,'channels':2,
        'target_seconds_requested':94.6153846,'mathematical_bar_boundary_seconds':41*4*60/104,
        'retained_frame_interval':[0,FRAMES], 'removed_frame_interval':[FRAMES,len(original)//2],
        'removed_frames':len(original)//2-FRAMES,
        'removed_ms':(len(original)//2-FRAMES)/48,
        'rounding_error_microseconds':(FRAMES/RATE-41*4*60/104)*1e6,
        'A':measurements(a),'B':measurements(b),
        'B_treatment':{
            'support_frame_interval':[0,TREATMENT],'support_ms':2,
            'actually_changed_frame_interval':[0,TREATMENT-1],
            'formula':'B[n,c] = A[n,c] - A[0,c] * (1 + cos(pi*n/95))/2, n=0..95; all later frames unchanged',
            'purpose':'Remove initial sample offset with a raised-cosine correction; no overlap, gain fade, resampling, duration change or arrangement change.',
            'max_absolute_sample_change':max(abs(b[i]-a[i]) for i in range(TREATMENT*2)),
        },
        'zero_crossing_alternative_inspected_not_exported':{
            'nearest_frame_to_zero_at_first_stereo_crossing':zero_near_first_cross,
            'frame_L_R':list(a[zero_near_first_cross*2:zero_near_first_cross*2+2]),
            'extra_start_trim_ms':zero_near_first_cross/48,
            'reason':'A start trim would shorten the authorized bar-length loop and remove its onset; B instead retains all frame positions.'
        },
        'previews':{'seam_seconds':[3,10,17],'silence_between_excerpts_seconds':1,'preview_only_edge_fade_ms':20,'format':'48 kHz stereo PCM16'},
        'files':{},'validation':{'A_prefix_byte_exact':True,'B_outside_2ms_byte_exact':True,'B_wrap_step_zero':True,'same_frame_count':True}
    }
    for name,samples in [('A_trim_only',a),('B_trim_2ms_declick',b)]:
        candidate=args.output/(name+'.wav');write_float(candidate,samples)
        assert load_float(candidate)[1]==float_bytes(samples)
        triple=args.output/(name+'_3_full_loops.wav');write_float(triple,samples,3)
        _,triple_bytes=load_float(triple)
        assert triple_bytes==float_bytes(samples)*3
        preview=args.output/(name+'_preview.wav');audition(preview,samples)
        for f in [candidate,triple,preview]: report['files'][f.name]={'bytes':f.stat().st_size,'sha256':digest(f)}
    audition(args.output/'original_control_preview.wav',original)
    assert digest(args.source)==source_sha
    report['validation']['original_unchanged']=True
    report['validation']['three_full_loops_per_candidate_byte_exact']=True
    (args.output/'sample-edits.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['removed_frames','removed_ms','rounding_error_microseconds','A','B','zero_crossing_alternative_inspected_not_exported','validation']},indent=2))

if __name__=='__main__':main()
