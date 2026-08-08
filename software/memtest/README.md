# QL Flex Memory Expansion — RAM test

(C) 2026 Arley Silveira — CERN-OHL-S v2.

## What it is

A memory tester for validating a freshly built (or suspect) QL Flex card
on the QL itself — the software half of the board's bring-up procedure.
It consists of a SuperBASIC front-end (`memtest_bas`: splash screen,
menu, configuration checks, results) and a position-independent 68008
machine-code core (`memtest_bin`, source in `memtest_asm`) that runs the
actual test loops at full machine speed with a live progress overlay.

It is built as a diagnostic instrument, not just a pass/fail checker:
all five tests always run (a failure doesn't stop the suite), so one
session reports every problem at once. The results screen shows a
per-test OK/FAIL matrix with cumulative fail counts across passes, the
first failing address with expected/read bytes, and — since the board
has a single 8-bit SRAM — a direct diagnosis of which data line(s)
D0–D7 are stuck, or a GAL/address-decode hint for address-type
failures. Multi-pass soak runs keep intermittent faults visible
(`FAIL x2` after two bad passes out of ten).

## The five tests (reference)

All tests are byte-wide — the 68008 has an 8-bit external data bus, so
wider accesses would only re-exercise the same lines.

| # | Test | Method | What a failure means |
|---|------|--------|----------------------|
| 1 | **DATA BUS** | Walking 1s and 0s (16 patterns) at one location per 64K block | A data line D0–D7 stuck, shorted or unsoldered between the SRAM, GAL and edge connector. The report names the exact line(s). |
| 2 | **ADDR BUS** | Power-of-2 offset probes: `$AA` everywhere, then a `$55` "aggressor" at each single-address-line offset while every other probe cell is verified | An address line A0–A18 stuck or shorted — writes land at the wrong address. Points at connector/GAL/SRAM address routing. |
| 3 | **ALIAS** | A unique tag byte at the start of every 4K page across the window, then all pages re-verified (twice, second pass inverted) | Two addresses decode to the same RAM cell: a mis-programmed GAL, wrong jumper setting, or two stacked cards claiming the same window. The report shows which page was overwritten by which. |
| 4 | **MARCH C−** | The classic six-element march: ascending `w0; r0,w1; r1,w0`, descending `r0,w1; r1,w0; r0` over the whole range | Cell-level faults the simple tests miss: stuck-at cells, transition faults, coupling between adjacent cells. |
| 5 | **PATTERN** | `$55/$AA` checkerboard fill, ~2 s retention delay, verify; repeated with the inverted pattern | Neighbouring-cell shorts and weak or leaky cells that lose data over time; marginal timing. The delay can be skipped for emulator runs. |

## The three test modes

| Menu option | What it does | When to use it |
|---|---|---|
| 2 — safe test | Allocates a QDOS buffer (up to 448K) and tests it. The QL keeps running. | Card in 512K config, seen by QDOS. The buffer sits at the top of RAM, i.e. in the expansion itself, so a pass already exercises the card's silicon — just not the whole window. |
| 3 — window test | Tests the card's whole window directly, but only when QDOS does not manage it. The QL keeps running. | A `$C0000`-config card (+256K/+192K/+128K) installed **alone**: QDOS stops sizing RAM at the `$40000` hole, so the window is free and can be tested completely, aliasing checks included, without crashing anything. |
| 4 — destructive test | Takes over the machine (supervisor mode, interrupts off), relocates itself into base RAM at `$30000` and tests the **entire** configured window. Results are drawn directly on screen; reset the QL afterwards. | Full bring-up validation of a 512K card, or of any stacked configuration. |

Option 1 first: pick the jumper configuration, and the program checks that
the RAM top QDOS detected at boot matches what the GAL should decode.

## Usage

### Files

| File | What it is | Copy to the QL? |
|------|-----------|-----------------|
| `memtest_bas` | SuperBASIC front-end (plain text program) | **Yes** |
| `memtest_bin` | Assembled 68008 test core, loaded by the front-end | **Yes** |
| `memtest_asm` | Source of the core — only needed to rebuild | No |
| `build.ps1` | Windows build script (vasm) | No |
| `checkbin_bas` | Tiny diagnostic that checks what `memtest_bin` loads as | Optional |

Both files are ordinary data files (nothing is `EXEC`ed, no executable
header), so any transfer method works — see "Getting the files onto a
real QL" below.

### Running it

Put `memtest_bas` and `memtest_bin` together on any device the QL can
read (`flp1_`, `mdv1_`, `win1_`, …), then from a **fresh boot** type:

    LRUN flp1_memtest_bas

(replace `flp1_` with the device you copied them to).

1. **Splash** shows for ~3 s (any key skips it), then the menu appears.
   The program locates `memtest_bin` by itself, probing
   flp1/mdv1/win1/flp2/mdv2/ram1 with a QDOS `IO.OPEN` helper; it only
   asks for a device if none has the file.
2. **The menu header** shows the RAM top QDOS found at boot and the
   expansion size derived from it — the first thing to sanity-check.
3. **Option 1** — tell the program the card's JP1/JP2 jumper setting and
   NORMAL/TRUMP position. It predicts the memory window and compares it
   against what QDOS actually found (see the table below).
4. **Options 2/3/4** run the tests (see the modes table above). Each asks
   for a pass count (1–99; more passes = soak test for intermittent
   faults) and whether to skip the retention delay (say `y` only in
   emulators). An estimated duration is shown, then a centred overlay
   panel tracks progress: `PASS n/N`, the running test's name, and a bar
   that fills once per pass.
5. **Results**: after `TESTS FINISHED — PRESS ENTER`, the screen clears
   and shows the verdict (green `ALL TESTS PASSED` / red `FAULTS
   FOUND`), passes completed, the per-test OK/FAIL×n matrix, and for
   failures the first fault's address, expected/read bytes and the
   data-line or address-decode diagnosis.
6. **The destructive test** additionally asks you to type `YES` and
   flashes a warning; it then owns the machine — test list with live
   `RUN` marker, progress panel, green/red verdict banner, ending in
   `DONE - RESET QL`. Reset or power-cycle afterwards. Expect roughly a
   minute per pass for a 512K window at real QL speed.

## Expected results per jumper configuration

Jumper fitted = ON. Addresses from the GAL equations in
[`gal/qlram_v2.pld`](../../gal/qlram_v2.pld).

| JP1 | JP2 | Config | Window | QDOS RAM top (`PEEK_L(163872)`) |
|-----|-----|--------|--------|-------------------------------|
| OFF | OFF | 512K  | `$40000–$BFFFF` | `$C0000` (786432) |
| OFF | ON  | +256K | `$C0000–$FFFFF` | `$100000` stacked on a 512K card; `$40000` alone |
| ON  | OFF | +192K | `$C0000–$EFFFF` | `$F0000` stacked; `$40000` alone |
| ON  | ON  | +128K | `$C0000–$DFFFF` | `$E0000` stacked; may not boot alone (see below) |

With the mode header on **TRUMP** (TC2 active) the first 32K of the window
disappears: the three `$C0000` configs start at `$C8000` instead. A quick
hardware check of the TRUMP jumper: run the window test — it must *fail*
if you tell it NORMAL while the jumper is on TRUMP, because `$C0000–$C7FFF`
no longer responds.

**Warnings**

* A `$C0000`-config card alone leaves a RAM hole at `$40000`, so QDOS shows
  only 128K. That is expected — use the window test (option 3).
* Per the original design notes, the **+128K config cannot boot alone**:
  the QL ROM start-up check trips over the address overlap unless another
  card provides ROM just above the window. Test that card jumpered as 512K
  or +256K instead.
* Reads outside a decoded window return floating-bus garbage on a QL; the
  tests only ever assert on addresses inside the window under test.

## Fresh boots and RESPR

A fresh boot matters because the loader uses `RESPR`, which fails with
"not complete" on stock ROMs once any job has been started. The stock QL
has no way to free `RESPR` memory, so repeated safe tests reuse the
first buffer.

**Reboot between sessions.** Every `LRUN` and every safe-test buffer
permanently consumes `RESPR` memory until the next reboot, and Minerva
will keep lowering the allocation boundary into used memory without
complaint — enough repeated runs and `RESPR` hands back addresses inside
QDOS or even 0. The program defends itself (the core rejects any test
range below `$20000` and the front-end refuses a buffer below the free
area, telling you to reboot), but the habit to build is: one boot, one
test session.

### Emulators (sQLux / QPC2)

Program-logic validation only — an emulator can't reproduce GAL or solder
faults. Answer `y` to "skip retention delay" to shorten the checkerboard
test.

**sQLux** — in `sqlux.ini`:

    RAMTOP = 768
    DEVICE = FLP1,C:\path\to\ql-flex-memory\software\memtest\,qdos-like

`RAMTOP = 768` simulates a 512K card (RAMTOP is the top *address* in K:
128K base ends at 256K, plus 512K expansion → RAM top `$C0000` = 768K);
the size check for config 1 must then PASS, and safe/destructive tests must
run clean. The destructive test works in sQLux (it emulates the real screen
at `$20000`).

**QPC2** runs SMSQ/E on a different memory map — use it for the front-end
and safe test only; the size-check table and the destructive test assume
real QL hardware or sQLux.

### ROM compatibility (JM/JS, Minerva, Minerva MK2)

The program uses only stock SuperBASIC keywords and standard QDOS traps, so
it runs on JM/JS ROMs and on **Minerva** (including the Minerva MK2 board —
its extra clock/I²C hardware touches nothing the test uses).

Rather than assuming the system variables live at `$28000`, the front-end
asks the OS where they really are (`MT.INF` via the core's info entry).
One consequence is handled automatically: in **Minerva's dual-screen
mode** the second display occupies `$28000` and the system variables move
to `$30000`. The size checks keep working there, but the **destructive
test refuses to run** (it relocates into `$30000` and draws on the screen
at `$20000`, which may not be the one displayed) — the menu shows a
warning and asks you to reboot with the second screen off. The same guard
disables the destructive test on SMSQ/E systems such as QPC2, where the
memory map is not a QL's.

The "+128K alone may not boot" warning below is based on the JM/JS ROM
start-up check; Minerva sizes RAM with its own algorithm and may behave
differently in that corner case.

### Getting the files onto a real QL

Whatever you normally use works: a Gotek/floppy with a QDOS disk image
(build one with [qltools](https://github.com/SinclairQL/qltools)), QL-SD,
a Qubide CF card, or a serial link. Both files are ordinary data files
with no executable header, so any transfer method is fine.

## Building from source

`memtest_bin` is committed, so you only need this after editing
`memtest_asm`. Get `vasmm68k_mot_Win64.zip` from the
[vasm site](http://sun.hasenbraten.de/vasm/) ("Last release binaries"),
then:

    .\build.ps1 -Vasm C:\path\to\vasmm68k_mot.exe

The script assembles with `-Fbin -m68008 -no-opt`, checks the binary fits
the 4096-byte slot the BASIC loader reserves and that the `QFMT` magic sits
at offset 8 (the fixed entry offsets +0/+4 depend on it). `-Deploy <dir>`
additionally copies both files into an emulator-mapped directory.

## Core interface (for hacking)

`CALL base,mode,start,end,flags,result` runs the safe suite
(`mode` 0 = buffer, 1 = unmanaged window; parameters land in D1–D5).
`CALL base+4,start,end,flags` runs the destructive suite and never returns.
`CALL base+16,result` stores the system-variables base (from `MT.INF`) as
a long at `result`.
`flags`: bits 0–7 = pass count, bit 8 = skip retention delay. Results are
longs in the 80-byte block at `result`: +0 fail bitmap, +4 fail address,
+8 expected, +12 actual, +16 first failing test 1–5, +20 passes done,
+24 bytes tested, +28 running test, +32 done flag, +36 (input)
progress-overlay enable — any address inside the frame buffer
(`$20000–$27C00`) makes the core draw a bordered panel centred on the
screen with `PASS n/N`, the running test's name and a per-pass green
progress bar, ending in `TESTS FINISHED / PRESS ENTER`; 0 disables it
(the front-end does this on SMSQ/E). +44…+60 are per-test fail counters,
+64 the pass target, +76 selects the panel border (white = safe, red =
destructive). After the CALL returns the front-end waits for Enter and
clears the screen, removing the overlay. See `memtest_asm`.
