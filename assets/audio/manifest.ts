// GENERATED FILE — do not hand-edit. Regenerate via `audio/manifest.sh`.
export const FREQUENCIES = [31,62,125,250,500,1000,2000,4000,8000,16000] as const;
export type Frequency = (typeof FREQUENCIES)[number];

export const GAINS = [9,6,3,-3,-6,-9] as const;
export type Gain = (typeof GAINS)[number];

type ClipKey = `${Frequency}_${Gain}`;

export const CLIPS: Record<ClipKey, number> = {
  "31_9": require('./clips/00031hz_+09db.m4a'),
  "31_6": require('./clips/00031hz_+06db.m4a'),
  "31_3": require('./clips/00031hz_+03db.m4a'),
  "31_-3": require('./clips/00031hz_-03db.m4a'),
  "31_-6": require('./clips/00031hz_-06db.m4a'),
  "31_-9": require('./clips/00031hz_-09db.m4a'),
  "62_9": require('./clips/00062hz_+09db.m4a'),
  "62_6": require('./clips/00062hz_+06db.m4a'),
  "62_3": require('./clips/00062hz_+03db.m4a'),
  "62_-3": require('./clips/00062hz_-03db.m4a'),
  "62_-6": require('./clips/00062hz_-06db.m4a'),
  "62_-9": require('./clips/00062hz_-09db.m4a'),
  "125_9": require('./clips/00125hz_+09db.m4a'),
  "125_6": require('./clips/00125hz_+06db.m4a'),
  "125_3": require('./clips/00125hz_+03db.m4a'),
  "125_-3": require('./clips/00125hz_-03db.m4a'),
  "125_-6": require('./clips/00125hz_-06db.m4a'),
  "125_-9": require('./clips/00125hz_-09db.m4a'),
  "250_9": require('./clips/00250hz_+09db.m4a'),
  "250_6": require('./clips/00250hz_+06db.m4a'),
  "250_3": require('./clips/00250hz_+03db.m4a'),
  "250_-3": require('./clips/00250hz_-03db.m4a'),
  "250_-6": require('./clips/00250hz_-06db.m4a'),
  "250_-9": require('./clips/00250hz_-09db.m4a'),
  "500_9": require('./clips/00500hz_+09db.m4a'),
  "500_6": require('./clips/00500hz_+06db.m4a'),
  "500_3": require('./clips/00500hz_+03db.m4a'),
  "500_-3": require('./clips/00500hz_-03db.m4a'),
  "500_-6": require('./clips/00500hz_-06db.m4a'),
  "500_-9": require('./clips/00500hz_-09db.m4a'),
  "1000_9": require('./clips/01000hz_+09db.m4a'),
  "1000_6": require('./clips/01000hz_+06db.m4a'),
  "1000_3": require('./clips/01000hz_+03db.m4a'),
  "1000_-3": require('./clips/01000hz_-03db.m4a'),
  "1000_-6": require('./clips/01000hz_-06db.m4a'),
  "1000_-9": require('./clips/01000hz_-09db.m4a'),
  "2000_9": require('./clips/02000hz_+09db.m4a'),
  "2000_6": require('./clips/02000hz_+06db.m4a'),
  "2000_3": require('./clips/02000hz_+03db.m4a'),
  "2000_-3": require('./clips/02000hz_-03db.m4a'),
  "2000_-6": require('./clips/02000hz_-06db.m4a'),
  "2000_-9": require('./clips/02000hz_-09db.m4a'),
  "4000_9": require('./clips/04000hz_+09db.m4a'),
  "4000_6": require('./clips/04000hz_+06db.m4a'),
  "4000_3": require('./clips/04000hz_+03db.m4a'),
  "4000_-3": require('./clips/04000hz_-03db.m4a'),
  "4000_-6": require('./clips/04000hz_-06db.m4a'),
  "4000_-9": require('./clips/04000hz_-09db.m4a'),
  "8000_9": require('./clips/08000hz_+09db.m4a'),
  "8000_6": require('./clips/08000hz_+06db.m4a'),
  "8000_3": require('./clips/08000hz_+03db.m4a'),
  "8000_-3": require('./clips/08000hz_-03db.m4a'),
  "8000_-6": require('./clips/08000hz_-06db.m4a'),
  "8000_-9": require('./clips/08000hz_-09db.m4a'),
  "16000_9": require('./clips/16000hz_+09db.m4a'),
  "16000_6": require('./clips/16000hz_+06db.m4a'),
  "16000_3": require('./clips/16000hz_+03db.m4a'),
  "16000_-3": require('./clips/16000hz_-03db.m4a'),
  "16000_-6": require('./clips/16000hz_-06db.m4a'),
  "16000_-9": require('./clips/16000hz_-09db.m4a'),
};

export function getClip(frequency: Frequency, gain: Gain): number {
  return CLIPS[`${frequency}_${gain}` as ClipKey];
}
