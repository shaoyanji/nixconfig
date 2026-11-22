# Pure Storage — Senior Systems & Storage Engineer

**No requisition on file.** This directory previously held a different application: *Cloud Native Architect, Strategic Accounts (EMEA)*,
Greenhouse **8379480**, a quota-carrying pre-sales role with mandatory French (DB `purestorage`, stage `prep`, fit 2, blocked; duplicate
row `rejected`). Those artefacts were: `lebenslauf.pdf` `e1e949b8dac615eb…` (2 pages, 652 words), `anschreiben.pdf` `fabeb6cc3f4f2970…`
(1 page, 457 words), `selection.json`.

This rebuild replaces them with a dossier for the role named in the instruction — **Senior Systems & Storage Engineer** — written against
the three pillars given (deep Linux systems, storage performance, declarative fleet management). No JD, req id or application URL for that
title exists anywhere in this repository or the apps DB, so **nothing here is tuned to a posting**. If the live req appears, take its
wording, re-check the gaps paragraph against it, and only then submit.

Native English Typst, 2026-11-22 — Typst 0.15.1, DejaVu Sans only.

## Files

| File | Pages | Words | Warnings | sha256 (first 16) |
| :--- | :--- | :--- | :--- | :--- |
| `lebenslauf.pdf` | 2 | 1106 | 0 | `6f7f5d656911d14e` |
| `anschreiben.pdf` | 1 | 441 | 0 | `4a9697a3a9c1da9e` |

`job-description.txt` is the **old CNA** posting and is now misleading in this directory; it is kept only because deleting a posting is
worse than labelling it. `selection.json` retired.

## What the CV argues

Storage as a measured practice rather than an inventory: a stated tiering taxonomy across local disk, NAS and object tiers, each with a
purpose, backup path and retention rule; restores rehearsed on a schedule instead of assumed; alerts on disk pressure and failed jobs.
Performance from the pressure signals upward — PSI on IO, memory and CPU, cgroup limits per slice, stall numbers read before a tunable is
touched, and a benchmark (fibtransponder) that falsified its own claim so the claim narrowed. Then the declarative fleet: thirteen NixOS
hosts from one flake, pinned inputs, hermetic builds, sops plus a certificate authority, rollback as a pointer, canary before fleet.

## Boundaries, stated in the CV and the letter

- No enterprise array: no FlashArray, no SAN fabric, no multipath, no NVMe-oF, no vendor escalation carried at 24/7.
- Scale is thirteen hosts and a PostgreSQL archive, not petabytes behind a controller pair.
- No quota, no pre-sales motion — that was the previous packet in this folder, not this one.

FlashArray, NVMe-oF, multipath, SAN and Portworx appear in the CV only inside the sentence declining them; the scan confirms no other
mention.

## Checks

| Gate | Result |
| :--- | :--- |
| `typst compile` both sources | 0 warnings each |
| Page budget | CV 2 pages, letter 1 page |
| `**` in sources | 0 |
| Unsupported storage-vendor claims | 0 outside the negation paragraph |
| `task checks:prose` | exit 0 |
| Commit | native sources, old CNA PDFs and `selection.json` replaced in the same commit |

## Before submitting

Get the requisition first. Without it the honest position is that this is a strong Linux-and-declarative-operations dossier with a
measured storage story and an explicit array-scale gap — not a packet matched to a band, a location or a level.
