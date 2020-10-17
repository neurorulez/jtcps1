# jtcps1

Capcom System 1 compatible verilog core for FPGA by Jose Tejada (jotego).

# Control

MiSTer allows for gamepad redifinition. However, the keyboard can be used with more or less the same layout as MAME for MiST(er) platforms. Some important keys:

-F12 OSD menu
-P   Pause. Press 1P during pause to toggle the credits on and off
-5,6 1P coin, 2P coin
-1,2 1P, 2P

For MiST, the first 6 gamepad buttons are used for game buttons, the next 2 buttons are used for credit and start buttons. If there is still one button left in the gamepad, it will be used for pause.

# MiSTer

Copy the RBF file to `_Arcade/cores` and the MRA files to `_Arcade`. Copy zipped MAME romsets to `_Arcade/mame`. Enjoy.

It is also possible to keep the MAME romsets in `_Arcade/mame` but have the MRA files in `_CPS` and the RBF files in `_CPS/cores`

## Notes

The _rotate screen_ OSD option is ignored for horizontal games.

# MiST

## Setup

You need to generate the .rom file using this (tool)[https://github.com/sebdel/mra-tools-c/tree/master/release]. Basically call it like this:

`mra ghouls.mra -z rompath -A`

And that will produce the .rom file and a .arc file. The .arc file can be used to start the core and directly load the game rom file. Note that the RBF name must be JTCPS1.RBF for it to work. The three files must be in the root folder.

*Important*: make sure to have the latest firmware and latest version of the mra tool.

Copy the RBF, .arc and .rom files to MiST and enjoy!

## Notes

Note that there is no screen rotation in MiST. Vertical games require you to turn your screen around. You can however flip the image through the OSD.

# Issues

Known issues:

-Fuel hoses in Carrier Airwing appear on top of the airplane
-12MHz games may run slightly slower than the original

Please report issues (here)[https://github.com/jotego/jtbin/issues].

# PAL Dumps
PAL dumps cam be obtained from MAME rom sets directly. Use the tool jedutil in order to extract the equations from them. The device is usually a gal16v8. For instance:

```
jedutil -view wl24b.1a gal16v8
```

In order to see the equations for Willow's PAL.

# Compilation
The core is compiled using jtcore from **JTFRAME**. Follow the instructions in the README file of (JTFRAME)[https://github.com/jotego/jtframe] and then:

```
source setprj.sh
jtcore -mister
```

This will produce the mister file.

## Static Time Analysis (STA)

MiST and SiDi compilations produce STA clean files with the default seed. However the MiSTer RBF file with everything enabled doesn't always come STA clean. If you disable HDMI or sound during compilation the RBF file will normally be STA clean. Public binary distribution in [jtbin](https://github.com/jotego/jtbin) are either STA clean or violations are below 99ps.

# MRA Format

Offset | Length | Use
-------|--------|-------------
 0     |  2     | Sound CPU ROM*
 2     |  2     | PCM data*
 4     |  2     | GFX ROM*
 6     |  2     | QSound firmware*
10h    | 18     | CPS-B configuration
22h    |  1     | Game ID
23h    |  2     | Bank offset
25h    |  2     | Bank mask
27h    |  1     | CPS-A board type
30h    | 11     | Kabuki keys (CPS 1.5 only)

* All offset values are expressed in kilobytes and stored with MSB byte second


# SDRAM Usage

## CPS 1

Some games do not fit in one memory bank (8MB) so three banks are used. The largest game (SF2) uses 6MB for GFX.

SDRAM bank | Usage
-----------|-------
0          | Sound: Z80 plus samples
1          | M68000
2          | GFX

## CPS 1.5

The SDRAM layout is the same as for CPS 1. Although samples are much larger than in CPS 1 titles, they still fit in one SDRAM bank sharing space with the Z80 ROM.

Game                  | CPU     |   Z80       | GFX     | Q-Sound |
----------------------|---------|-------------|---------|---------|
Warriors of Fate      | 1   MB  |  128 kB     | 4 MB    | 2 MB    |
Cadillacs & Dinosaurs | 1.5 MB  |  128 kB     | 4 MB    | 2 MB    |
The Punisher          | 1.5 MB  |  128 kB     | 4 MB    | 2 MB    |
S.N. Slam Masters     | 2.0 MB  |  128 kB     | 6 MB    | 4 MB    |
Muscle Bomber Duo     | 2.0 MB  |  128 kB     | 6 MB    | 4 MB    |


## CPS 2

Game                  | CPU     |   Z80       | GFX     | Q-Sound |
----------------------|---------|-------------|---------|---------|
19XX                  | 2.5 MB  |  128 kB     | 10 MB   | 4 MB    |
Alien vs Predator     | 2.0 MB  |  128 kB     | 16 MB   | 4 MB    |
Armored Warriors      | 4.0 MB  |  256 kB     | 20 MB   | 4 MB    |
Battle Circuit        | 3.5 MB  |  256 kB     | 16 MB   | 4 MB    |
Capcom Sports Club    | 2.5 MB  |  128 kB     |  8 MB   | 4 MB    |
Cyberbots             | 4.0 MB  |  256 kB     | 32 MB   | 4 MB    |
Darkstalkers          | 4.0 MB  |  256 kB     | 20 MB   | 4 MB    |
Dimahoo               | 2.0 MB  |  256 kB     | 16 MB   | 8 MB    |
DnD Shadow o. Mystara | 4.0 MB  |  256 kB     | 24 MB   | 4 MB    |
DnD Tower of Doom     | 2.5 MB  |  128 kB     | 12 MB   | 4 MB    |
Eco Fighters          | 2.0 MB  |  128 kB     | 12 MB   | 4 MB    |
Giga Wing             | 1.5 MB  |  128 kB     | 16 MB   | 8 MB    |
Hyper SF II           | 4.0 MB  |  256 kB     | 32 MB   | 8 MB    |
Janpai                | 1.0 MB  |  128 kB     | 16 MB   | 4 MB    |
Jyangokushi           | 0.5 MB  |  128 kB     | 16 MB   | 4 MB    |
Mars Matrix           | 1.5 MB  |  128 kB     | 32 MB   | 8 MB    |
Marvel Super Heroes   | 4.0 MB  |  256 kB     | 32 MB   | 4 MB    |
Marvel vs SF          | 4.0 MB  |  256 kB     | 32 MB   | 8 MB    |
Marvel vs CAPCOM      | 4.0 MB  |  256 kB     | 32 MB   | 8 MB    |
Megaman 2             | 1.5 MB  |  256 kB     |  8 MB   | 4 MB    |
Darkstalker's revenge | 4.0 MB  |  256 kB     | 32 MB   | 4 MB    |
Progear               | 1.0 MB  |  128 kB     | 16 MB   | 8 MB    |
Puzz Loop 2           | 2.0 MB  |  128 kB     | 16 MB   | 4 MB    |
Quiz Nanairo Dreams   | 2.0 MB  |  128 kB     |  8 MB   | 4 MB    |
Slam Masters 2        | 3.0 MB  |  256 kB     | 18 MB   | 4 MB    |
SF alpha 1            | 2.0 MB  |  256 kB     |  8 MB   | 4 MB    |
SF alpha 2            | 3.0 MB  |  256 kB     | 20 MB   | 4 MB    |
SF alpha 3            | 4.0 MB  |  256 kB     | 32 MB   | 8 MB    |
SF zero 2 alpha       | 3.0 MB  |  256 kB     | 20 MB   | 4 MB    |
Super Gem Fighter     | 2.5 MB  |  256 kB     | 20 MB   | 8 MB    |
Super Puzzle Fighter 2| 1.0 MB  |  256 kB     |  4 MB   | 4 MB    |
SF2 New Challengers   | 2.5 MB  |  128 kB     | 12 MB   | 4 MB    |
SF2 Turbo             | 3.5 MB  |  256 kB     | 16 MB   | 4 MB    |
Vampire Savior 1      | 4.0 MB  |  256 kB     | 32 MB   | 8 MB    |
Vampire Savior 2      | 4.0 MB  |  256 kB     | 32 MB   | 8 MB    |
X-Men Children of A.  | 4.0 MB  |  256 kB     | 32 MB   | 4 MB    |
X-Men vs SF           | 3.5 MB  |  256 kB     | 32 MB   | 4 MB    |

# Simulation

## Game
1. Generate a rom file using the MRA tool
2. Update the symbolic link rom.bin in ver/game to point to it
3. If all goes well, `go.sh` should update the sdram.hex file
   But if sdram.hex is a symbolic link to something else it might
   fail. You can delete sdram.hex first so it gets recreated

   `go.sh` will fill up sdram.hex with zeros in order to avoid x's in
   simulation.

4. Apply patches if appropiate. The script `apply_patches.sh` can generate
   some alternative hex files which skip some of the test code of the game
   so it boots up more quickly

5. While simulation is running, it is possible to update the output video
   files by running `raw2jpg.sh`

Some Verilog macros:

1. FORCE_GRAY ignore palette and use a 4-bit gray scale for everything
2. REPORT_DELAY will print the average CPU delay at the end of each frame
   in system ticks (number of 48MHz clocks)

## Video

Video only simulations can be done using mame dumps. Use the tool *cfg2mame* in the *ver/video* folder
to create two *.mame* files that can invoked from mame to dump the simulation data. Run the game in debug
mode but source from MAME the register file that *cfg2mame* creates. Then at the point of interest souce *vram.mame*. That creates the file vram.bin. Copy that file to a directory with the mame name of the game. Add a numerical index (see the other folders for examples). Create a hex file following the examples in
the other files too. Now you run go.sh like this:

```
go.sh -g game -s number -frame 2
```

This will run the simulation for the folder *game* and looking for files with the *number* index. If you
 need to look at the sprites too, you need to run more than one frame as the object DMA needs a frame to
 fill in the data.

# Support

You can show your appreciation through
* Patreon: https://patreon.com/topapate
* Paypal: https://paypal.me/topapate

# Licensing

Contact the author for special licensing needs. Otherwise follow the GPLv3 license attached.