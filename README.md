# QL Flex Memory Expansion

A 512kB external RAM expansion for the Sinclair QL, based on Alvaro Alea
Fernandez's design. The circuit is unchanged. This version reworks the board to
make assembly and reconfiguration easier, hence the name.

Original project: https://github.com/alvaroalea/QL_512kb_External_Expansion

## Changes in the 2025 revision

* Standard 2.54mm pin headers replace the configuration solder jumpers. Jumper
  caps now control the memory configuration and Trump Card mode.
* The GAL16V8 uses a PLCC-20 SMD socket instead of a DIP-20 through-hole package.
  The GAL remains removable and reprogrammable while taking up less board space.
* The resistors and 100nF capacitors use the 0805 size instead of 1206.
* The silkscreen includes the memory configuration table
  (00-512kB / 01-256kB / 10-192kB / 11-128kB), NORMAL/TRUMP labels for the mode
  header, and the board dimensions.
* All fabrication outputs are in one `gerbers/` folder.

Board size (97.79 × 35.56 mm) and the circuit itself are unchanged from the
original rev 3.

## About the board

The board adds up to 512kB of static RAM (fast RAM) to the Sinclair QL.

Stacking two boards provides up to 896kB of memory, the same capacity as
Miracle's Trump Card.

Two memory expansions cannot occupy the same address range. This applies to
Jose Leandro's QBide, the Trump Card, and similar hardware.

The board has an expansion connector for additional interfaces.

The configuration headers provide four settings. The original board uses solder
jumpers instead.

* 512kB: The standard expansion for any QL.
* 256kB: Used as a second expansion to reach the QL's 896kB maximum. This setting
  conflicts with many expansion cards. Any card without configuration jumpers
  will be incompatible.
* 192kB: Similar to the 256kB setting, but leaves more address space for properly
  configured expansion cards.
* 128kB: Similar to the 256kB setting, with still more address space left for
  properly configured expansion cards.

The 128kB configuration cannot be installed alone. To use it for a total of
768kB, another expansion card must provide ROM at address E00000h. Without that
ROM, an overlap between the internal and external 128kB causes the QL ROM to
report a RAM malfunction and hang.

https://www.instagram.com/p/CZWfWcUM5mx/

The `gal` folder contains source code for GALasm:
https://github.com/daveho/GALasm

## RAM test software

`software/memtest/` contains a RAM test for checking an assembled card on the QL.
It combines a SuperBASIC front end with a 68008 machine-code core. The suite
tests the data bus, address bus, aliasing (GAL decode), March C-minus, and
checkerboard patterns. It supports a QDOS-safe mode and a destructive test of
the complete window. See
[software/memtest/README.md](software/memtest/README.md).

## Mini Trump Card compatibility

Alvaro also made the MiniTrump version of the Trump Card disk interface:
https://github.com/alvaroalea/QL_MiniTrump3. Unlike the original, the MiniTrump
does not include memory. Combining it with two of these RAM cards provides the
same functions as the original Trump Card.

Connect the 512kB card to the QL, the MiniTrump to the 512kB card, and the +256kB
card to the MiniTrump. Set this board's three-pin mode header, labelled
NORMAL/TRUMP on the silkscreen, to TRUMP so the MiniTrump can coordinate with
the second memory card.

## Credits and license

Original design (C) 2022 Alvaro Alea Fernandez, based on the work of McLeod
Ideafix, Jose Leandro, Zerover and tcat among others, with contributions from
www.va-de-retro.com

2025 revisions by ArleyJr.

Licensed under: CERN Open Hardware Licence Version 2 - Strongly Reciprocal

https://ohwr.org/cern_ohl_s_v2.txt

<img src="20260807_212727.jpg" width="2203" alt="QL Flex Memory Expansion board">
