/*
  polyrhythms.scd - a tool to explore polyrhythms in Supercollider
  Copyright © 2019 Panu Luukkonen

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// INIT
(
  // SynthDefs
  SynthDef(\sin, { |out = 0, freq = 440, amp = 0.1, pan = 0, sustain = 1|
    var z, env;

    env = EnvGen.kr(Env([0, amp, 0], [0.01, sustain*8]), doneAction: 2);
    z = SinOsc.ar(freq) * EnvGen.kr(Env([0, 1, 0], [0.01, sustain*8]), doneAction: 2);

    OffsetOut.ar(out, Pan2.ar(z, pan, amp))
  }).add;

  SynthDef(\saw, { |out = 0, freq = 440, amp = 0.1, pan = 0, sustain = 1|
    var z, env, lpf;

    env = EnvGen.kr(Env([0, amp, 0], [0.01, sustain*8]), doneAction: 2);
    z = BlitB3Saw.ar(freq) * env;
    lpf = LPF.ar(z, 2000);

    OffsetOut.ar(out, Pan2.ar(lpf, pan, amp))
  }).add;

  SynthDef(\kick, { |out = 0, amp = 0.3, sinfreq = 60, glissf = 0.9, att = 0.01, rel = 0.45, pan = 0|
    var env, snd, ramp;

    env = Env.perc(att, rel, amp).kr(doneAction: 2);
    ramp = XLine.kr(start: sinfreq, end: sinfreq * glissf, dur: rel);
    snd = SinOsc.ar(freq: ramp, mul: env);

    OffsetOut.ar(out, Pan2.ar(snd, pan, amp))
  }).add;

  SynthDef(\snare, {|out = 0, amp = 0.1, sinfreq = 180, att = 0.01, rel = 0.2, ffreq = 2000, pan = 0|
    var env, snd1, snd2, sum;

    env = Env.perc(att, rel, amp).kr(doneAction: 2);
    snd1 = HPF.ar(in: WhiteNoise.ar, freq: ffreq, mul: env);
    snd2 = SinOsc.ar(freq: sinfreq, mul: env);
    sum = snd1 + snd2;

    OffsetOut.ar(out, Pan2.ar(sum, pan, amp))
  }).add;

  SynthDef(\hihat, {|out = 0, amp = 0.5, att = 0.01, rel = 0.2, ffreq = 6000, pan = 0|
    var env, snd;

    env = Env.perc(att, rel, amp).kr(doneAction: 2);
    snd = WhiteNoise.ar;
    snd = HPF.ar(in: snd, freq: ffreq, mul: env);

    OffsetOut.ar(out, Pan2.ar(snd, pan, amp))
  }).add;

  // Functions
  /*
    ~irat
    returns interval ratios

    :param i  an interval in semitones
              - 0 is unison, 12 an octave above, -24 two octaves below, etc...
    :return   a multiplier of the interval ratio
  */
  ~irat = { |i|
    var ratios = [1/1, 16/15, 9/8, 6/5, 5/4, 4/3, 7/5, 3/2, 8/5, 5/3, 7/4, 15/8];

    ratios.wrapAt(i) * (2 ** i.div(12))
  };

  /*
    ~poly
    create polyrhythms that are (by default) equidistantly panned to the stereo field

    :param polys          a number of a single rhythm or an array of polyrhythms to play
                          - e.g. #[5, 9] for a 5 against 9 polyrhythm
    :param instrument     the instrument to play
    :param amp            amount of amplitude
    :param sustain        amount of sustain
    :param pan            panning
                          - if not given, pan equidistantly using 100% of the stereo field
                          - accepts a number or an array to pan different rhythms to different points
                            in the stereo field
    :param firstNoteMul   first note of the bar will sound this many times higher
                          - 2 equals octave, 1.5 perfect fifth, etc...
    :param f              a (two parameter) function to compute the next frequency in the array
                            :param root the root note frequency
                            :param i    the nth note (n starts from 0)
    :return               an array of Pbinds that you can play
  */
  ~poly = { |polys = #[5, 9], instrument = (\default), amp = 0.1, sustain = 0.02, pan = nil, firstNoteMul = 1, f = ({ |root, i| root + (root/2 * i) })|
    var pbinds = Array(polys.size);

    if (polys.isArray.not, { polys = [polys] });

    polys.do { |poly, i|
      var freq, freqs, panning;

      // frequency
      freq = f.(root: 220, i: i);
      // a sequence with the first note firstNoteMul times higher
      freqs = Pseq([freq*firstNoteMul] ++ Array.fill(poly-1, freq), inf);
      // if panning is explicitly given, pan it there
      if (pan.isNil.not, {
        if (pan.isArray.not, { pan = [pan] });
        panning = pan.wrapAt(i);
      }, {
        // else pan is zero if only one element, otherwise spread it evenly
        panning = if (polys.size == 1, 0, -1 + (2/(polys.size-1) * i));
      });

      pbinds.add(
        Pbind(
          \instrument, instrument,
          \sustain, sustain,
          \dur, 1/poly,
          \amp, amp,
          \freq, freqs,
          \pan, panning,
        )
      )
    };

    pbinds
  };

  "OK"
)

// EXAMPLES

// example 1
// simple sine instrument with 5 over 9 over 2 pattern
// first note of the bar is an octave above the rest
(
  TempoClock.tempo = 40/4/60;

  ~polys = ~poly.(
    polys: #[5, 9, 2],
    instrument: \sin,
    firstNoteMul: ~irat.(12),
    f: { |root, i| root + (root/1 * i) },
  );

  CmdPeriod.run;
  ~polys.do(_.play);

  "Playing ex1"
)

// example 2
// very close and quick polyrhythmic patterns
// try slowing down the tempo or changing the instrument to hihat
// or use e.g. [19, 20.14, 21.29, 22.43, 23.57, 24.71, 25.86] to desync over time
(
  TempoClock.tempo = 100/4/60;

  ~polys = ~poly.(
    polys: #[19, 20, 21, 22, 23, 24, 25],
    amp: 0.23,
    instrument: \saw,
    firstNoteMul: ~irat.(12),
    f: { |root, i| root + (1 * i) },
  );

  CmdPeriod.run;
  ~polys.do(_.play);

  "Playing ex2"
)

// example 3
// join only after one bar (quant: [0, i])
// you can give float numbers to polys to not be in sync all the time
// try adding for example [8.3, 0.7, 1.8] to the array of polys...
(
  TempoClock.tempo = 100/4/60;

  ~polys = ~poly.(
    polys: #[3, 9, 7, 11, 4, 2.5, 1.1],
    instrument: \saw,
    amp: 0.25,
    sustain: 0.1,
    firstNoteMul: ~irat.(0),
    f: { |root, i| 100 + (100/3 * i) },
  );

  CmdPeriod.run;
  ~polys.do({ |p, i| p.play(quant: [0, i]) });

  "Playing ex3"
)

// example 4
// alternating patterns are fun (small number, big number, small number...)
// small phase differences create even more rhythmic variation (quant: [0, i*0.01])
(
  TempoClock.tempo = 40/4/60;

  ~polys = ~poly.(
    polys: #[1, 9, 2, 8, 3, 7, 4, 6, 5],
    amp: 0.08,
    instrument: \sin,
    firstNoteMul: ~irat.(9),
    f: { |root, i| 100 + (100/3 * i) },
  );

  CmdPeriod.run;
  ~polys.do({ |p, i| p.play(quant: [0, i*0.01]) });

  "Playing ex4"
)

// example 5
// a polyrhythmic band
// you can also give explicit panning
// try uncommenting the instruments below one at a time
(
  TempoClock.tempo = 50/4/60;

  ~polys = [];

  ~polys = ~polys ++ ~poly.(
    polys: #[1, 9, 2, 8, 5],
    amp: 0.05,
    instrument: \sin,
    firstNoteMul: ~irat.(-12),
    f: { |root, i| root + (root/1 * i) },
  );

  ~polys = ~polys ++ ~poly.(
    polys: 9,
    amp: 0.4,
    instrument: \kick,
  );

  ~polys = ~polys ++ ~poly.(
    polys: 5,
    amp: 0.25,
    instrument: \snare,
    pan: 0.2,
  );

  ~polys = ~polys ++ ~poly.(
    polys: 17,
    amp: 0.3,
    instrument: \hihat,
    pan: -0.4,
  );

  // ~polys = ~polys ++ ~poly.(
  //   polys: 19,
  //   amp: 0.02,
  //   pan: -0.7,
  //   instrument: \sin,
  //   f: 550,
  // );

  // ~polys = ~polys ++ ~poly.(
  //   polys: 18,
  //   amp: 0.016,
  //   pan: 0.7,
  //   instrument: \sin,
  //   f: 616,
  // );

  // ~polys = ~polys ++ ~poly.(
  //   polys: 21,
  //   amp: 0.012,
  //   pan: 0.3,
  //   instrument: \sin,
  //   f: 825,
  // );

  // ~polys = ~polys ++ ~poly.(
  //   polys: 2.5,
  //   amp: 0.015,
  //   pan: -0.8,
  //   instrument: \sin,
  //   f: 1100,
  // );

  // ~polys = ~polys ++ ~poly.(
  //   polys: 1.1,
  //   amp: 0.005,
  //   pan: 0.8,
  //   instrument: \sin,
  //   f: #[1237.5, 1443.75, 1650],
  // );

  CmdPeriod.run;
  ~polys.do(_.play);

  "Playing ex5"
)

/* good candidates for the function f
  f: { |root, i| root + (root/4 * i) },
  f: { |root, i| root + (1 * i) },
  f: { #[220, 330, 440] },
*/
