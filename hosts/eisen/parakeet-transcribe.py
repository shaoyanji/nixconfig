# Vendored from https://huggingface.co/eschmidbauer/parakeet-redux-onnx (transcribe.py),
# the community ONNX export of Moondream's parakeet-redux. NOT Moondream-official:
# treat as experiment. Verbatim except this header; the HTTP wrapper lives in
# parakeet-server.py and imports this module as parakeet_stt.transcribe.

#!/usr/bin/env python3
"""Transcribe audio with the ONNX export of moondream/parakeet-redux.

Needs only onnxruntime and numpy (plus ffmpeg on the PATH for anything other
than 16 kHz wav). Mirrors Photon's pipeline: its mel features, its greedy
token-and-duration transducer loop, its word timing, and its pause-based
segmentation of recordings longer than 30 seconds using the model's own VAD head.

Examples:
    python transcribe.py speech.wav
    python transcribe.py speech.wav --timestamps word
    python transcribe.py talk.mp3 --json
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
import unicodedata
import wave
from pathlib import Path

import numpy as np
import onnxruntime as ort

HERE = Path(__file__).resolve().parent
SAMPLE_RATE = 16_000
SEGMENT_SECONDS = 30.0
MIN_PAUSE_SECONDS = 0.2
MIN_SEGMENT_SECONDS = 1.0
BLOCK_SECONDS = 120.0
MIN_FEATURE_SAMPLES = 320
PAUSE_EPSILON = 1e-6
SPEECH_THRESHOLD = 0.5
MIN_SPEECH_SECONDS = 0.1
MIN_GAP_SECONDS = 0.1
SKIP_PIECES = {"<unk>", "<pad>", "<blk>"}


# ----------------------------------------------------------------------------
# Audio
# ----------------------------------------------------------------------------

def read_audio(path: Path) -> np.ndarray:
    """Mono float32 PCM at 16 kHz, via ffmpeg, or the wave module for plain wav files."""
    if shutil.which("ffmpeg"):
        command = ["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-acodec", "pcm_f32le",
                   "-ac", "1", "-ar", str(SAMPLE_RATE), "-"]
        return np.frombuffer(subprocess.run(command, check=True, capture_output=True).stdout, dtype=np.float32).copy()
    with wave.open(str(path), "rb") as handle:
        if handle.getsampwidth() != 2:
            raise ValueError("without ffmpeg only 16-bit PCM wav files are supported")
        if handle.getframerate() != SAMPLE_RATE:
            raise ValueError(f"without ffmpeg the wav file must be {SAMPLE_RATE} Hz")
        data = np.frombuffer(handle.readframes(handle.getnframes()), dtype=np.int16)
        channels = handle.getnchannels()
        if channels > 1:
            data = data.reshape(-1, channels).mean(1)
        return data.astype(np.float32) / 32768.0


# ----------------------------------------------------------------------------
# Tokens and timestamps
# ----------------------------------------------------------------------------

def _is_punctuation(piece: str) -> bool:
    stripped = piece.strip()
    return bool(stripped) and all(unicodedata.category(character).startswith("P") for character in stripped)


class Vocabulary:
    """vocab.txt as onnx-asr writes it: one ``piece id`` per line, blank named <blk>."""

    def __init__(self, path: Path):
        self.pieces: dict[int, str] = {}
        for line in path.read_text(encoding="utf-8").splitlines():
            if line:
                piece, index = line.rsplit(" ", 1)
                self.pieces[int(index)] = piece
        self.blank_id = next(index for index, piece in self.pieces.items() if piece == "<blk>")
        self.skip = {index for index, piece in self.pieces.items() if piece in SKIP_PIECES}

    def decode(self, token_ids) -> str:
        text = "".join(self.pieces[token] for token in token_ids if token not in self.skip)
        text = text.replace("▁", " ")
        return text[1:] if text.startswith(" ") else text

    def words(self, token_ids, durations, frame_seconds: float) -> list[dict]:
        """Word start and end times from the transducer's token durations (Photon's rule)."""
        frame = 0
        words: list[dict] = []
        current: list[int] = []
        current_start = current_end = 0.0

        def flush() -> None:
            nonlocal current
            if current:
                text = self.decode(current).strip()
                if text:
                    words.append({"word": text, "start": current_start, "end": current_end})
                current = []

        for token, duration in zip(token_ids, durations):
            start = frame * frame_seconds
            frame += duration
            if token in self.skip:
                continue
            raw = self.pieces[token]
            piece = raw.replace("▁", " ")
            if raw.startswith("▁"):
                flush()
            if _is_punctuation(piece):
                if current:
                    current.append(token)
                    current_end = frame * frame_seconds
                elif words:
                    words[-1] = {"word": words[-1]["word"] + piece.strip(), "start": words[-1]["start"],
                                 "end": frame * frame_seconds}
                continue
            if not current:
                current_start = start
            current.append(token)
            current_end = frame * frame_seconds
        flush()
        return words


def sentence_segments(words: list[dict], include_words: bool, max_seconds: float = 30.0) -> list[dict]:
    segments: list[dict] = []
    pending: list[dict] = []
    for word in words:
        pending.append(word)
        if word["word"].rstrip().endswith((".", "?", "!")) or word["end"] - pending[0]["start"] >= max_seconds:
            segments.append(_segment(pending, include_words))
            pending = []
    if pending:
        segments.append(_segment(pending, include_words))
    return segments


def _segment(words: list[dict], include_words: bool) -> dict:
    segment = {"text": " ".join(word["word"] for word in words), "start": words[0]["start"], "end": words[-1]["end"]}
    if include_words:
        segment["words"] = list(words)
    return segment


# ----------------------------------------------------------------------------
# Long audio: cut at pauses found by the VAD head, at most 30 s per segment
# ----------------------------------------------------------------------------

def speech_regions_from_probabilities(probabilities: np.ndarray, frame_seconds: float) -> list[tuple[float, float]]:
    speaking = np.asarray(probabilities) >= SPEECH_THRESHOLD
    edges = np.flatnonzero(np.diff(np.r_[0, speaking.astype(np.int8), 0]))
    regions: list[list[float]] = []
    for start, end in edges.reshape(-1, 2) * frame_seconds:
        if regions and start - regions[-1][1] < MIN_GAP_SECONDS:
            regions[-1][1] = end
        else:
            regions.append([start, end])
    return [(start, end) for start, end in regions if end - start >= MIN_SPEECH_SECONDS]


def pauses_from_speech(speech, duration: float) -> list[tuple[float, float]]:
    least = MIN_PAUSE_SECONDS - PAUSE_EPSILON
    pauses = []
    previous = 0.0
    for start, end in sorted(speech):
        if start - previous >= least:
            pauses.append((previous, start))
        previous = max(previous, end)
    if duration - previous >= least:
        pauses.append((previous, duration))
    return pauses


def next_cut(pauses) -> float:
    inside = [item for item in pauses if item[0] >= MIN_SEGMENT_SECONDS and item[1] <= SEGMENT_SECONDS]
    if not inside:
        inside = [item for item in pauses if MIN_SEGMENT_SECONDS <= (item[0] + item[1]) / 2 <= SEGMENT_SECONDS]
    if not inside:
        return SEGMENT_SECONDS
    first, last = inside[-1]
    return (first + last) / 2


def has_speech(regions, seconds: float) -> bool:
    return any(end > 0 and start < seconds for start, end in regions)


# ----------------------------------------------------------------------------
# The model
# ----------------------------------------------------------------------------

class OnnxParakeet:
    def __init__(self, model_dir: Path, threads: int | None = None, providers=None):
        config = json.loads((model_dir / "config.json").read_text(encoding="utf-8"))
        self.durations = list(config["durations"])
        self.vocab_size = int(config["vocab_size"])
        self.max_symbols_per_step = int(config["max_tokens_per_step"])
        self.frame_seconds = float(config["encoder_frame_seconds"])
        self.vocab = Vocabulary(model_dir / "vocab.txt")
        self.blank_id = int(config.get("blank_token_id", self.vocab.blank_id))
        options = ort.SessionOptions()
        if threads:
            options.intra_op_num_threads = threads
        providers = providers or ["CPUExecutionProvider"]

        def session(name: str):
            return ort.InferenceSession(str(model_dir / name), options, providers=providers)

        self.preprocessor = session("preprocessor.onnx")
        self.encoder = session("encoder-model.onnx")
        self.decoder_joint = session("decoder_joint-model.onnx")
        self.vad = session("vad-model.onnx") if (model_dir / "vad-model.onnx").exists() else None
        state_shape = next(i.shape for i in self.decoder_joint.get_inputs() if i.name == "input_states_1")
        self.state_shape = (int(state_shape[0]), 1, int(state_shape[2]))

    # -- features and encoder --------------------------------------------------
    def features(self, pcm: np.ndarray):
        features, lengths = self.preprocessor.run(None, {"waveforms": pcm[None].astype(np.float32),
                                                         "waveforms_lens": np.array([pcm.size], dtype=np.int64)})
        return features, lengths

    def encode(self, pcm: np.ndarray) -> np.ndarray:
        features, lengths = self.features(pcm)
        outputs, out_lengths = self.encoder.run(None, {"audio_signal": features, "length": lengths})
        return np.ascontiguousarray(outputs[0, :, : int(out_lengths[0])].T)  # [frames, 1024]

    # -- greedy token-and-duration transducer decoding (Photon's loop) ------------
    def greedy(self, encoded: np.ndarray) -> tuple[list[int], list[int]]:
        frames = encoded.shape[0]
        state = (np.zeros(self.state_shape, np.float32), np.zeros(self.state_shape, np.float32))
        last_token = self.blank_id
        frame = 0
        steps = self.max_symbols_per_step * frames
        tokens: list[int] = []
        durations: list[int] = []
        target_length = np.ones(1, dtype=np.int32)
        while frame < frames and steps > 0:
            logits, _, hidden, cell = self.decoder_joint.run(None, {
                "encoder_outputs": encoded[frame][None, :, None],
                "targets": np.array([[last_token]], dtype=np.int32),
                "target_length": target_length,
                "input_states_1": state[0], "input_states_2": state[1]})
            logits = logits[0, 0, 0]
            token = int(logits[: self.vocab_size].argmax())
            duration = self.durations[int(logits[self.vocab_size:].argmax())]
            if token == self.blank_id and duration == 0:
                duration = 1
            tokens.append(token)
            durations.append(duration)
            frame += duration
            if token != self.blank_id:
                last_token = token
                state = (hidden, cell)
            steps -= 1
        return tokens, durations

    # -- segmentation --------------------------------------------------------------
    def speech_regions(self, pcm: np.ndarray) -> list[tuple[float, float]]:
        duration = pcm.size / SAMPLE_RATE
        if self.vad is None:
            return [(0.0, duration)]
        regions: list[tuple[float, float]] = []
        block_samples = round(BLOCK_SECONDS * SAMPLE_RATE)
        for offset in range(0, pcm.size, block_samples):
            block = pcm[offset: offset + block_samples]
            base = offset / SAMPLE_RATE
            block_duration = block.size / SAMPLE_RATE
            if block.size < MIN_FEATURE_SAMPLES:
                regions.append((base, base + block_duration))
                continue
            features, lengths = self.features(block)
            probabilities, valid = self.vad.run(None, {"audio_signal": features, "length": lengths})
            for start, end in speech_regions_from_probabilities(probabilities[0, : int(valid[0])], self.frame_seconds):
                regions.append((base + start, base + min(end, block_duration)))
        return regions

    def cut_segments(self, pcm: np.ndarray) -> list[tuple[int, int]]:
        cap = round(SEGMENT_SECONDS * SAMPLE_RATE)
        if pcm.size <= cap:
            return [(0, pcm.size)]
        regions = self.speech_regions(pcm)
        pieces: list[tuple[int, int]] = []
        start = 0
        cuts = 0
        while pcm.size - start > cap:
            origin = start / SAMPLE_RATE
            relative = [(max(s - origin, 0.0), e - origin) for s, e in regions if e > origin]
            cut = next_cut(pauses_from_speech(relative, (pcm.size - start) / SAMPLE_RATE))
            index = round(cut * SAMPLE_RATE)
            if has_speech(relative, index / SAMPLE_RATE):
                pieces.append((start, start + index))
            start += index
            cuts += 1
        origin = start / SAMPLE_RATE
        relative = [(max(s - origin, 0.0), e - origin) for s, e in regions if e > origin]
        tail = pcm.size - start
        if not (cuts and (tail < MIN_FEATURE_SAMPLES or not has_speech(relative, tail / SAMPLE_RATE))):
            pieces.append((start, pcm.size))
        return pieces

    # -- the whole thing -------------------------------------------------------------
    def transcribe(self, pcm: np.ndarray, timestamps: str = "segment") -> dict:
        if pcm.size < MIN_FEATURE_SAMPLES:
            raise ValueError("audio is too short to transcribe")
        duration = pcm.size / SAMPLE_RATE
        text_parts: list[str] = []
        segments: list[dict] = []
        for start, end in self.cut_segments(pcm):
            tokens, durations = self.greedy(self.encode(pcm[start:end]))
            text = self.vocab.decode(tokens)
            text_parts.append(text.strip())
            if timestamps == "none" or not text:
                continue
            clip_start, clip_end = start / SAMPLE_RATE, end / SAMPLE_RATE
            words = [{"word": w["word"], "start": min(clip_end, w["start"] + clip_start),
                      "end": min(clip_end, w["end"] + clip_start)}
                     for w in self.vocab.words(tokens, durations, self.frame_seconds)]
            if words:
                segments.extend(sentence_segments(words, include_words=timestamps == "word"))
            else:
                segments.append({"text": text, "start": clip_start, "end": clip_end})
        return {"text": " ".join(part for part in text_parts if part), "language": None, "task": "transcribe",
                "duration_seconds": duration, "source_duration_seconds": duration,
                "clip_start_seconds": 0.0, "clip_end_seconds": duration, "segments": segments}


# ----------------------------------------------------------------------------
# Command line
# ----------------------------------------------------------------------------

def parse_args(argv=None):
    parser = argparse.ArgumentParser(prog="transcribe", description="Speech to text with the ONNX export of parakeet-redux.",
                                     formatter_class=argparse.RawDescriptionHelpFormatter,
                                     epilog=__doc__.split("Examples:")[1])
    parser.add_argument("audio", nargs="+", type=Path, help="audio file(s)")
    parser.add_argument("--model-dir", default=str(HERE), help="directory with the ONNX files (default: next to this script)")
    parser.add_argument("--timestamps", choices=("none", "segment", "word"), default=None,
                        help="plain text (default), one line per sentence, or every word; --json defaults to segment")
    parser.add_argument("--threads", type=int, default=None, help="onnxruntime intra-op threads (default: auto)")
    parser.add_argument("--json", action="store_true", help="emit the full result as JSON")
    return parser.parse_args(argv)


def print_result(result: dict, timestamps: str, header: str | None) -> None:
    if header:
        print(f"== {header}")
    if timestamps == "none":
        print(result["text"])
    else:
        for segment in result["segments"]:
            print(f"[{segment['start']:7.2f} - {segment['end']:7.2f}]  {segment['text']}")
            for word in segment.get("words", ()):
                print(f"    {word['start']:7.2f} - {word['end']:7.2f}  {word['word']}")
    if header:
        print()


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def main(argv=None) -> int:
    args = parse_args(argv)
    timestamps = args.timestamps or ("segment" if args.json else "none")
    missing = [p for p in args.audio if not p.is_file()]
    if missing:
        sys.exit("error: no such file: " + ", ".join(str(p) for p in missing))
    model_dir = Path(args.model_dir).expanduser().resolve()
    if not (model_dir / "encoder-model.onnx").exists():
        sys.exit(f"error: no ONNX export in {model_dir} (run export_onnx.py first)")

    started = time.perf_counter()
    model = OnnxParakeet(model_dir, threads=args.threads)
    log(f"model loaded in {time.perf_counter() - started:.1f}s from {model_dir}")
    results = {}
    for path in args.audio:
        pcm = read_audio(path)
        started = time.perf_counter()
        result = model.transcribe(pcm, timestamps)
        elapsed = time.perf_counter() - started
        log(f"{path.name}: {result['duration_seconds']:.1f}s of audio in {elapsed:.2f}s, "
            f"{result['duration_seconds'] / elapsed:.0f}x real time")
        results[str(path)] = result
        if not args.json:
            print_result(result, timestamps, path.name if len(args.audio) > 1 else None)
    if args.json:
        payload = results if len(args.audio) > 1 else next(iter(results.values()))
        json.dump(payload, sys.stdout, indent=2, ensure_ascii=False)
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
