# Streets of Rage 4 (`0100EC9010258000`)

Update 1.0.9 (v458752; the base game v0 is not extracted), SDK 9.3.1. MonoGame for the Switch, as Celeste ([01002B30028F6000](../01002B30028F6000/README.md)) and Stardew Valley ([0100E65002BB8000](../0100E65002BB8000/README.md)): MonoGame's and the game's C# compiled to C++ by Sickhead's BRUTE into `main` (114 MB with its bss) with a Boehm collector; Wwise sound (`GeneratedSoundBanks/Switch`, 0.95 GB) through the audio renderer; the intro movies through `subsdk0` (NintendoSDK_movie); NVN.

## Status

- **iPhone:** the intro movies, the menus and a stage, at a steady 60 fps.
- **Mac:** boot and the three intro movies (`void`, `game_intro_logos`, `game_intro`): 59.5 fps (frame time p50 16.6 ms, p99 17.6 ms), 2.0 GB peak footprint, no red line (the regression route, [`smoke.tsv`](smoke.tsv)). The menus and a stage are not yet checked on the Mac.

## What it needs

| Setting | Where | Why |
|---|---|---|
| `sys_resource 0x0` | [`game.tsv`](game.tsv) | the NPDM declares no system resource, so `IsVirtualAddressMemoryEnabled` is false, as on Horizon: no virtual address memory. The game sets a heap of pool − used memory and hands it to one `StandardAllocator` (main's `malloc`) |
| 4 GB layout: `mem_reserve 0x100000000`, `mem_alias 0x10000000`, `mem_stack 0x10000000` | `game.tsv` | 256 MB in front + 256 MB alias region + 256 MB stack region + 3.25 GB heap region |
| `mem_used 0x76d8000` (119 MB) | `game.tsv` | the rewritten modules are larger than the default 64 MB of used memory, so the heap request plus the modules would exceed the pool |
| `app_pool 0xD5500000` (**workaround**) | `game.tsv` | 128 MB more than the Switch's 3285 MB; see [Memory](#memory) |
| `shader_groups /shader/=shader` | `game.tsv` | the MonoGame effects; see [Shaders](#shaders) |

No `pad_layout`: the virtual gamepad starts in the 2D layout (the default).

## Memory

- **Current (workaround, cause open):** with the Switch's pool the heap is 3.06 GB (the Switch's would be 6 MB larger: the host counts the rewritten modules). `main`'s `StandardAllocator` holds, by the first movie (about 4 s in): the graphics heap, a constant 2150 MB block (`main+0x30354` → `main+0x1d7f0`) that the texture pools are allocated from; 128 MB for MonoGame's audio renderer (`main+0x17ae4`); 116 MB of Wwise pools; and the Boehm heap, grown in 8 MB chunks to 420–437 MB. The video player then asks for 128 MB at 64 KB alignment (`main+0x2fea600`) and aborts when it fails (`nx_video_player_init : Failed to allocate 134217728 for video player !`, then `Break`). It failed in about one boot in two: at the failure the allocator had 274.7 MB free but no block larger than 104.8 MB, the Boehm chunks spread on both sides of the 2150 MB block. Passing and failing boots differed by a few MB of Boehm heap (421 MB passed, 429 MB failed), and boots slowed by probes passed at 426 MB, so it is the layout of the free space, not a larger heap. The pool is raised by 128 MB (a 3.19 GB heap, inside the 3.25 GB heap region; untouched heap costs nothing on the Mac or the iPhone); with it five boots in a row, and every boot since, played every movie. Why the Switch never fails is not known: the same game code lays out the same allocations, with a slightly larger heap and other thread timing.
- On the Mac 1.4 GB of footprint 4 s into the boot, 2.0 GB at the peak of the intro movies.

## Shaders

- **Current:** 127 (MonoGame effects, MGFX version 8): the 14 XNB files in `rom:/shader` and SpriteBatch's built-in effect in `main`, read by `shader_split.py` (`mgfx_effect`), as Celeste's. Every binding decodes.
- The prewarm list is empty, not recorded yet; the pipeline prebuild builds 98 pipelines in about a second.

## Movies

- The video player (`main+0x2fea4dc`) uses the SDK movie decoder in native-texture mode: the decoded frame goes into one of two NVN textures, registered as IDs 256 and 257 of a texture pool of the player's own, and the player draws the one holding the current frame with `nvnCommandBufferDrawTexture`, the two in turn. See [`DrawTexture` drawn as a scaling texture copy](../../../docs/reference/rendering.md#drawtexture-drawn-as-a-scaling-texture-copy).

## Mac routes

- `boot.sh` in the work folder runs `dm/host/dmhost` on the rewritten modules with the RomFS image (`DM_ROMFS`), a save folder and the shader libraries, as the NSP script's `--platform mac` run command does.
- The intro: `void` at about 4 s, then `game_intro_logos` and `game_intro`.

## Found on this game

General host changes first needed here; each applies to every game:

- **SVCs no longer write below the guest's stack pointer** (`entry.S`, a gate stack per thread): BRUTE's Boehm collector freed live objects four seconds into the boot. [SVCs write nothing below the guest's stack pointer](../../../docs/reference/threads.md#svcs-write-nothing-below-the-guests-stack-pointer).
- **`nvnCommandBufferDrawTexture`**, which the video player draws every movie frame with: [`DrawTexture` drawn as a scaling texture copy](../../../docs/reference/rendering.md#drawtexture-drawn-as-a-scaling-texture-copy).

## Open

- The pool workaround above: why the Switch's pool suffices.
- The menus and a stage on the Mac (played on the iPhone), then a prewarm list recorded over them and the README gallery entry.
- Only update 1.0.9 is extracted; the base game v0 is not.
