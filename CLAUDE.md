# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

A Chinese-language book titled **"如何设计内核：权限、调度与结构"** (How to Design a Kernel: Permissions, Scheduling, and Structure). It covers operating system kernel design across 85+ chapters organized into 8 parts, focusing on three core models — permission, scheduling, and structure — and how they interact.

## Build Commands

```bash
# Concatenate all chapter files into a single book.md with YAML frontmatter
./scripts/build.sh                # outputs book.md (default)
./scripts/build.sh path/to/output.md

# Compile book.md to output formats (requires pandoc)
./scripts/compile.sh book.md             # all formats (PDF + EPUB + HTML)
./scripts/compile.sh book.md pdf         # PDF only (needs xelatex)
./scripts/compile.sh book.md epub        # EPUB only
./scripts/compile.sh book.md html        # HTML only

# Split book.md back into individual chapter files
./scripts/split.sh book.md
```

## Dependencies

- **pandoc** — required for all compilation
- **xelatex** (TeX Live) — required for PDF output
- **Noto Sans CJK SC** font — required for PDF CJK rendering

## Project Structure

```
/
├── book.md                    # Merged single-file book (935KB)
├── 目录.md                    # Table of contents
├── 引言.md                    # Introduction
├── 第1部分_总起-内核需要干嘛/   # Part 1 — Overview
├── 第2部分_资源-内核管理的对象/ # Part 2 — Resources
├── 第3部分_权限模型-谁可以用/   # Part 3 — Permission Model
├── 第4部分_调度模型-.../       # Part 4 — Scheduling Model
├── 第5部分_结构模型-.../       # Part 5 — Structure Model
├── 第6部分_打破模型-.../       # Part 6 — Breaking the Model
├── 第7部分_架构与实现-.../     # Part 7 — Architecture & Implementation
├── 第8部分_经典内核设计选择/    # Part 8 — Classic Kernel Designs
├── scripts/
│   ├── build.sh               # Merge chapters → book.md
│   ├── compile.sh             # book.md → PDF/EPUB/HTML
│   └── split.sh               # book.md → individual chapters
├── output/                    # Compiled artifacts
└── licenses/
```

## Content Architecture

Each part directory contains numbered markdown files (`NN_标题.md`). The parts are:

| Part | Theme |
|------|-------|
| 1 | What a kernel does — resource manager, execution environment, hardware abstraction |
| 2 | Resources: CPU, memory, I/O, devices; their abstractions and lifecycles |
| 3 | Permission models: subjects, operations, objects; delegation, revocation, attenuation |
| 4 | Scheduling: execution flows, priorities, interrupts, synchronization, deadlocks, power-aware scheduling, live migration |
| 5 | Structure: layering, modularity, messaging, error propagation, observability, extensibility |
| 6 | Designing your own kernel from scratch |
| 7 | Architecture-specific: x86 rings, ARM exception levels, RISC-V modes, page tables, interrupts, boot process |
| 8 | Case studies: Linux, seL4, QNX, L4 family, HIC |
