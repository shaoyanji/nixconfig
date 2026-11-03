#!/usr/bin/env python3
"""Fine-tune a small sentence encoder on the selector dataset (the v1 backend).

NOT RUN IN THIS TREE. Measured 2026-11-02: delphi has no torch, transformers,
onnx, numpy or sklearn, 2 cores and no GPU, and the predesign puts training on
eisen (docs/selector-daemon-predesign.md §7). This file exists so the recipe is
executable when someone is on eisen, not so a claim can be made from delphi. If
it has never printed a metric, it has proven nothing.

The label space is the same closed set the Naive Bayes backend uses
(`inventory|filter:status`, `notes|id:kind`, `abstain`, ...), so the two backends
are comparable on the same held-out split and the same battery.

    # on eisen
    nix shell nixpkgs#python3Packages.torch nixpkgs#python3Packages.transformers \
              nixpkgs#python3Packages.onnx nixpkgs#python3Packages.accelerate
    tools/selector/build.sh /tmp/sel            # dataset.jsonl (+ payloads)
    python3 tools/selector/train_encoder.py --dataset /tmp/sel/dataset.jsonl \
        --out /tmp/sel/encoder --model sentence-transformers/all-MiniLM-L6-v2 \
        --epochs 3 --batch 32 --lr 3e-5

Then compare `metrics.json` here with `model.py train`'s held-out row before
switching the daemon's `p`; a heavier encoder that does not beat the template
classifier is the decoration the predesign warns about.

Runtime is not Python: export ONNX (`model.onnx` + `labels.json`) and load it with
`onnxruntime` from nixpkgs (confirm the aarch64 builds first) or `candle`.
"""
import argparse
import json
import sys
from pathlib import Path


def require():
    missing = []
    for mod in ("torch", "transformers", "onnx"):
        try:
            __import__(mod)
        except ImportError:
            missing.append(mod)
    if missing:
        sys.exit(
            "train_encoder: missing " + ", ".join(missing) + "\n"
            "  this path needs eisen (GPU) or a codespace; delphi has no ML stack.\n"
            "  nix shell nixpkgs#python3Packages.torch nixpkgs#python3Packages.transformers "
            "nixpkgs#python3Packages.onnx nixpkgs#python3Packages.accelerate"
        )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--model", default="sentence-transformers/all-MiniLM-L6-v2")
    ap.add_argument("--epochs", type=int, default=3)
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--lr", type=float, default=3e-5)
    ap.add_argument("--max-len", type=int, default=64)
    args = ap.parse_args()

    require()
    import numpy as np
    import torch
    from torch.utils.data import Dataset
    from transformers import (
        AutoModelForSequenceClassification,
        AutoTokenizer,
        Trainer,
        TrainingArguments,
    )

    pairs = [json.loads(line) for line in Path(args.dataset).read_text().splitlines() if line.strip()]
    labels = sorted({p["label"] for p in pairs})
    index = {label: i for i, label in enumerate(labels)}
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    (out / "labels.json").write_text(json.dumps(labels, indent=2))

    tokenizer = AutoTokenizer.from_pretrained(args.model)

    class Rows(Dataset):
        def __init__(self, rows):
            self.rows = rows

        def __len__(self):
            return len(self.rows)

        def __getitem__(self, i):
            row = self.rows[i]
            enc = tokenizer(
                row["q"], truncation=True, max_length=args.max_len, padding="max_length", return_tensors="pt"
            )
            return {
                "input_ids": enc["input_ids"][0],
                "attention_mask": enc["attention_mask"][0],
                "labels": torch.tensor(index[row["label"]]),
            }

    train_rows = [p for p in pairs if p["split"] == "train"]
    test_rows = [p for p in pairs if p["split"] == "test"]

    model = AutoModelForSequenceClassification.from_pretrained(args.model, num_labels=len(labels))
    trainer = Trainer(
        model=model,
        args=TrainingArguments(
            output_dir=str(out / "checkpoints"),
            num_train_epochs=args.epochs,
            per_device_train_batch_size=args.batch,
            per_device_eval_batch_size=args.batch,
            learning_rate=args.lr,
            eval_strategy="epoch",
            save_strategy="no",
            report_to=[],
            logging_steps=50,
        ),
        train_dataset=Rows(train_rows),
        eval_dataset=Rows(test_rows),
    )
    trainer.train()
    metrics = trainer.evaluate()
    (out / "metrics.json").write_text(json.dumps(metrics, indent=2))
    print(json.dumps(metrics, indent=2))

    model.eval()
    dummy = tokenizer("which notes are blocked", return_tensors="pt", truncation=True, max_length=args.max_len)
    torch.onnx.export(
        model,
        (dummy["input_ids"], dummy["attention_mask"]),
        str(out / "model.onnx"),
        input_names=["input_ids", "attention_mask"],
        output_names=["logits"],
        dynamic_axes={"input_ids": {0: "batch", 1: "seq"}, "attention_mask": {0: "batch", 1: "seq"}},
        opset_version=17,
    )
    print(f"exported {out / 'model.onnx'} and {out / 'labels.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
