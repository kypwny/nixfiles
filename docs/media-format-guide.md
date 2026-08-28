# Media Format Guide (N100 + Jellyfin QSV)

N100 (Alder Lake-N) hardware codec support with ≤2 concurrent transcodes.

## Audio

N100 handles audio transcoding on CPU — trivial for 2 streams, but avoiding
it is still free performance.

| Format | Direct-play | Notes |
|--------|------------|-------|
| **AAC** | Everywhere | Universal safe pick; scene standard |
| **Opus** | Most clients | Modern, efficient, common in anime encodes |
| **AC3 / E-AC3** | Most clients | Dolby Digital; Jellyfin apps support it |
| **FLAC** | Most clients | Lossless, large per-track; common on AB |
| **DTS/DTS-HD/TrueHD** | Patchy | Often triggers audio transcode |
| **MP3** | Everywhere | Avoid — obsolete, bloated |

- Prefer **AAC or Opus** for broad compatibility, **FLAC** if you want lossless
  and your clients support it (Jellyfin apps do).
- **Subtitle burn-in** is the real CPU killer, not audio. Direct-play with
  external `.srt` or `.ass` subs whenever possible — avoid server-side burn-in.

## AnimeBytes notes

AB encodes often carry multiple audio tracks (JP + EN dubs), commentary,
and FLAC audio. The video stream is usually a well-tuned x265 10-bit encode
from a known encoder — grab those without hesitation. Just be aware:

- **FLAC audio tracks** are ~400–600 MB per cour at 16-bit stereo — budget
  disk accordingly
- **Dual-audio releases** double the audio footprint
- **Commentary tracks** are another track, not a separate file — only matters
  if you archive everything
- Group tags to trust: same encoder names you see on Nyaa (Beatrice-Raws,
  Koten_Gars, Vodes, etc.) — AB is where they post their untouched encodes

## Recommended

**HEVC 10-bit (x265)** — best general-purpose pick.

- ~40% smaller than H.264 at same quality
- Full hardware decode + encode pipeline on N100
- Broad client direct-play support
- Nyaa tags: `1080p`, `HEVC`, `x265`, `10bit`
- Uploaders: Judas, bonkai77, neoHEVC, SubsPlease (HEVC)

## When to grab AV1

- ~30% smaller than HEVC
- N100 hardware-decodes AV1 but **cannot hardware-encode it**
- Transcodes fall back to H.264/HEVC — fine, just not AV1 end-to-end
- Grab if your playback clients direct-play it natively
- Uploaders: amZero, ScarletNeko

## When to grab H.264

- Universal direct-play on any client, zero transcodes
- Larger files, but disk is cheap for 2 streams

## Skip

- **HDR-only** when clients are SDR — tone mapping works but adds a filter pass
- **VC-1 / MPEG-2** — old codecs, bloated
- **4K REMUX** — 80 GB/movie; x265 encodes are <5 GB

## Quick lookup

| Codec | Decode (HW) | Encode (HW) | Best for |
|-------|------------|------------|----------|
| HEVC 10-bit | ✅ | ✅ | Default pick |
| AV1 | ✅ | ❌ | Client-dependent |
| H.264 | ✅ | ✅ | Universal compatibility |
| VP9 | ✅ | ✅ | YouTube rips |

Generated 2026-06-18. Check `/home/ky/nixos-config/modules/services/jellyfin.nix` for the current hardware acceleration config.
