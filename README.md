<div align="center">

<img src="assets/sprites/ui/title.png" height="120" alt="BOX SIEGE">

# BOX SIEGE

**A Chaotic Local Multiplayer Box Brawler with a 250-Level Solo Campaign, by Equinox Interactive**

[![Engine](https://img.shields.io/badge/Engine-Godot%204.7-478CBF?style=for-the-badge&logo=godotengine&logoColor=white)]()
[![Language](https://img.shields.io/badge/Language-GDScript-355570?style=for-the-badge&logo=godotengine&logoColor=white)]()
[![Renderer](https://img.shields.io/badge/Renderer-GL%20Compatibility-FF4040?style=for-the-badge)]()
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-0078D6?style=for-the-badge)]()
[![Players](https://img.shields.io/badge/Players-1--4-A855F7?style=for-the-badge)]()

[About](#about) • [Getting Started](#getting-started) • [Game Modes](#game-modes) • [Controls](#controls) • [Development](#development) • [Disclaimer](#disclaimer)

---

## About

BOX SIEGE is a fast, chaotic, arcade-style brawler where boxes fight with guns and knives on mirrored arenas. Two to four players share one screen in local Versus matches, on a single keyboard, with controllers, or with any mix of both. A solo Campaign adds 250 levels, 50 bosses, and a perk system for players who want to fight alone.

Every fighter has 3 hearts, every match is a first-to-N-rounds showdown, and every arena is a symmetrical trap-filled stage with its own hazards: lava, ice, crumbling platforms, spikes, arrow traps, geysers, teleport portals, conveyor belts, and spinning saw blades. Coins earned in the Campaign are spent in the Shop on character skins, weapon skins, and accessories, which can then be equipped from the Inventory.

The game is built in Godot 4.7 with GDScript and the GL Compatibility renderer, so it runs on a wide range of hardware. The whole user interface is drawn in code and shares one arcade visual identity: comic-style fonts, skewed buttons, animated screen transitions, and per-map color palettes.

---

## Getting Started

The simplest way to play is to download a build from the project's release page, extract it, and run the executable. To run the game from source, see [Development](#development) below.

### System Requirements

| Item | Requirement |
|---|---|
| Operating System | Windows (x86_64), Linux (x86_64), or macOS (11 or later on Intel, 13 or later on Apple Silicon) |
| Graphics | Any GPU with OpenGL compatibility support (the game uses the GL Compatibility renderer) |
| Display | 1280x720 base resolution, scaled automatically to any window size or fullscreen |
| Input | Keyboard, one or more game controllers, or both |
| Players | 1 player (Campaign) or 2 to 4 players on one screen (Versus) |

### Quick Play

1. Launch the game and choose **VERSUS** for local multiplayer or **CAMPAIGN** for the solo mode.
2. Pick your fighter and main weapon on the select screen.
3. Adjust the battle settings (map, time, rounds, objects, and power-ups) and start the match.
4. Win the required number of rounds to win the match.

---

## Game Modes

The main menu offers five entries: **CAMPAIGN** (1 player), **VERSUS** (2 to 4 players), **CONTROLS**, **SETTINGS**, and **QUIT**. The **SHOP** and **INVENTORY** are available as buttons at the bottom right of the main menu.

### Versus

Local PvP for 2 to 4 players. The match flow is:

| Step | Screen | Description |
|---|---|---|
| 1 | Player Count | Choose 2, 3, or 4 players |
| 2 | Select | Each player picks a fighter, a main weapon, a skin, and accessories, then confirms with READY |
| 3 | Teams | Only for 3 and 4 players. Players slide their cards between four team lanes to form teams |
| 4 | Battle Settings | Choose the map, time, rounds, object density, and power-up rules |
| 5 | Match | Fight until one player or team wins the required number of rounds |

At the end of a match the result screen offers **REMATCH**, **CHANGE FIGHTERS**, and **MAIN MENU**. The pause menu offers **RESUME**, **CHANGE FIGHTERS**, and **MAIN MENU**.

### Team Battles

With 3 or 4 players, the Teams screen lets players share lanes to form teams, for example 2v2, 2v1v1, 3v1, or free-for-all 1v1v1v1.

| Rule | Detail |
|---|---|
| Team lanes | Four lanes, TEAM 01 to TEAM 04, each with its own color |
| Team size limit | Maximum 3 members per team with 4 players, maximum 2 per team with 3 players |
| Default | Every player starts alone in their own lane (free-for-all) |
| Handicap | A team larger than the smallest team receives a light nerf, shown on its lane |

| Team Size Difference | Bullet Damage | Fire Delay | Run Speed | Jump Height |
|---|---|---|---|---|
| 0 | 100% | 100% | 100% | 100% |
| 1 | 85% | 110% | 96% | 100% |
| 2 or more | 70% | 122% | 92% | 97% |

The handicap never changes maximum health, knife damage, or weapons that already kill in one hit.

### Match Rules

| Setting | Options | Default |
|---|---|---|
| Health | 3 hearts per fighter | 3 |
| Rounds to win | 1 to 5 | 3 |
| Round timer | 30 seconds to 5 minutes in 30 second steps, or infinite | 90 seconds |
| Time up | The fighter or team with the highest remaining health percentage wins the round | - |
| Tie | A tie triggers SUDDEN DEATH | - |
| Objects | FEWER, NORMAL, MORE, or EXTREME arena object density | NORMAL |
| Power-ups | On or off, with an individual allow list | All on |
| Power-up amount | FEW, NORMAL, MANY, or CHAOS | NORMAL |

Battle settings are saved between sessions.

### Campaign

A single-player run of 250 levels. Each level is made of one or more enemy waves, and the last level of every world is a boss fight.

| Item | Detail |
|---|---|
| Structure | 5 chapters, 10 worlds per chapter, 5 levels per world, 250 levels in total |
| Chapters | First Blood, Aftershock, Last Siege, Dark Horizon, No Mercy |
| Bosses | 50 (one at the end of every world, in every chapter) |
| Enemy types | 12 regular enemy types, with difficulty scaling from chapter to chapter |
| Map variants | Chapters 2 to 5 use their own map variants, and chapters 4 and 5 use a late-game variant set |
| Lives | Start with 3, up to 5, with extra lives from the SECOND WIND perk |
| Checkpoints | A checkpoint is saved at the start of every world. Game Over resumes from the last checkpoint |
| Wave retry | After dying in a multi-wave level, you can retry from the wave where you fell |
| Progress | Stars, best scores, rank, unlocked levels, and the current run are saved automatically |

Worlds (repeated in every chapter):

| World | Arena | Levels in Chapter |
|---|---|---|
| Green Fields | Earth | 1 to 5 |
| Canopy | Jungle | 6 to 10 |
| Frozen Pass | Snow | 11 to 15 |
| Dune Ruins | Desert | 16 to 20 |
| Thorn Savanna | Safari | 21 to 25 |
| Inferno | Hell | 26 to 30 |
| Ziggurat | Temple | 31 to 35 |
| Shipwreck Bay | Ocean | 36 to 40 |
| Star Station | Space | 41 to 45 |
| Iron Foundry | Factory | 46 to 50 |

Enemy types:

| Enemy | Weapon | Role |
|---|---|---|
| Grunt | Smith | Basic soldier |
| Rusher | Knife | Fast melee attacker |
| Gunner | Kurval | Slow, heavy-hitting shooter |
| Burner | Flamer | Close-range flame attacker |
| Sniper | Scream | Long-range one-shot threat |
| Guard | Smith | Carries a shield |
| Hopper | Pistol | High jumper with strong shots |
| Brute | Kurval | Large, high-health enemy |
| Veteran | Smith | Shielded elite (Chapter 2 and later) |
| Assassin | Knife | Very fast melee elite |
| Marksman | Scream | Shielded long-range elite |
| Juggernaut | Flamer | Large, high-health flame elite |

Bosses are larger and have much more health. Each boss combines special traits: **enrage** (becomes more aggressive at low health), **summon** (calls in helpers), **leap** (jumps across the arena), and **dash** (charges at the player).

#### Perks

After clearing a level, the player chooses one of three random perks (four after a boss level). Perks are weighted by rarity, and a perk that reached its maximum stack no longer appears.

| Perk | Effect | Max Stacks |
|---|---|---|
| Heavy Rounds | +12% weapon damage | 5 |
| Quick Trigger | +10% fire rate | 5 |
| Deep Pockets | +20% ammo capacity | 5 |
| Swift Soles | +6% run speed | 5 |
| Spring Step | +5% jump height | 3 |
| Iron Skin | -10% damage taken | 5 |
| Extra Heart | +1 maximum heart | 2 |
| Vampire | Kills may heal you | 3 |
| Aegis | Start every level with a shield | 1 |
| Scavenger | Enemies drop more power-ups | 3 |
| Sharp Knife | +25% knife damage | 3 |
| Second Wind | +1 life (boss reward only) | Unlimited |

#### Scoring, Stars, and Rank

| Element | Rule |
|---|---|
| Par time | 25 seconds per wave, plus 50 seconds on boss levels |
| Time bonus | 10 points for every second under par |
| Flawless bonus | 1000 points for taking no damage |
| 1 star | Clear the level |
| 2 stars | Take 4 damage or less |
| 3 stars | Take 1.5 damage or less and never die in the level |
| Rank | C, B, and A follow the star count, and S is awarded for a flawless 3-star clear |

### Shop and Inventory

Coins are earned by clearing Campaign levels and are spent in the **SHOP**. Owned items are equipped in the **INVENTORY**, and the equipped look is used in both Versus and Campaign.

| Item Type | Amount | Rarities |
|---|---|---|
| Character skins | 240 (10 themes for each of the 24 fighters) | Common, Rare, Epic, Legendary |
| Weapon skins | 30 (5 for each of the 6 weapons, with matching bullet colors) | Common, Rare, Epic, Legendary |
| Accessories | 31 across four slots: head, face, neck, back | Common, Rare, Epic, Legendary |

| Rarity | Character Skin Price | Weapon Skin Price |
|---|---|---|
| Common | 150 | 250 |
| Rare | 350 | 600 |
| Epic | 700 | 1200 |
| Legendary | 1400 | 2400 |

Accessory prices range from 150 to 1200 coins depending on the item.

Character skin themes: Gold Rush, Cosmic, Neon Pulse, Inferno, Glitch, Frostbite, Toxic, Shadow, Sakura, and 8-Bit.

Coin rewards for Campaign levels:

| Rule | Detail |
|---|---|
| Base value | 60 coins plus 1.2 coins per level number, multiplied by 1.5 on boss levels |
| Star multiplier | 1 star x1.0, 2 stars x1.35, 3 stars x1.8 |
| First clear | Full value |
| Replay | 20% of the value (minimum 5 coins) |
| Improving stars | The difference in value is paid out on top of the replay reward |

---

## Fighters

All 24 fighters are available to every player slot, and two players cannot pick the same fighter in one match. The roster is made of 16 original fighters and 8 newer faces. Every fighter has an alive sprite, a KO sprite, and a voice line.

| Group | Fighters |
|---|---|
| Original (16) | Angry, Melow, Bandel, Ninja, Calm, Baik, Silat, Mime, Spiderweaver, Blind, Joker, Drunk, Bald Man, Savior, Spiderblack, Deadswim |
| New (8) | Robot, Zombie, Pirate, Pocong, Vampire, Cyclops, Pumpkin, Alien |

Each player slot has its own color (red, blue, purple, orange), applied to weapons and the player indicator.

---

## Arsenal

Each fighter picks one of four main weapons. Every fighter also carries a knife, and the Scream switches to a pistol when its ammo runs out.

| Weapon | Type | Damage | Ammo per Round | Fire Delay | Fire Mode | Notes |
|---|---|---|---|---|---|---|
| Smith | Gun | 1.0 | 25 | 0.30 s | Tap | Balanced all-rounder |
| Kurval | Gun | 1.5 | 10 | 0.55 s | Tap | Heavy recoil, strong hits |
| Flamer | Gun | 0.5 | 30 | 0.07 s | Hold | Very fast fire with bullet spread |
| Scream | Gun | 3.0 | 3 | 1.30 s | Tap | Kills in one hit, huge recoil, falls back to the pistol |
| Pistol | Backup gun | 0.25 | Unlimited | 0.30 s | Tap | Only available after the Scream runs dry |
| Knife | Melee | 3.0 | Unlimited | 0.45 s | Tap | Kills in one hit, 83 px reach |

Damage is measured against the 3 hearts every fighter has, so a damage value of 3.0 is an instant kill.

---

## Arenas

There are 10 playable arenas plus a **RANDOM** option that picks a different arena every time a match starts. Every layout is mirrored left to right for fairness: platforms, hazards, moving parts, and spawn points all have a matching counterpart on the other side.

| Arena | Hazards and Features |
|---|---|
| Earth | Open baseline arena with a fall zone |
| Hell | Lava fall zone |
| Snow | Slippery ice, drifting ice floes, and icy water below |
| Desert | Crumbling platforms and cactus spikes |
| Jungle | Bouncy mushrooms and moving wooden platforms |
| Safari | Spike strips and moving platforms |
| Temple | Spikes, wall-mounted arrow traps, and moving platforms |
| Ocean | Crumbling planks, erupting geysers, and ship cannons |
| Space | Anti-gravity lifts and paired teleport portals |
| Factory | Conveyor belts and saw blades on rails |

Falling into a fall zone or touching a hazard costs a heart, and the fighter respawns. The **OBJECTS** setting (Versus only) changes how many hazards appear:

| Level | Effect |
|---|---|
| FEWER | Lighter hazards: shorter spikes, rarer traps and geysers, and fewer saws |
| NORMAL | The map exactly as designed |
| MORE | Extra themed objects added in mirrored pairs |
| EXTREME | Even more objects with slightly tighter trap timing |

---

## Power-Ups

Power-ups appear in crates at random spots on the arena. Nine exist in total: seven in Versus, and two that appear only in the Campaign.

| Power-Up | Effect | Duration | Mode |
|---|---|---|---|
| Heal | Restores 1 heart | Instant | Versus and Campaign |
| Speed | Run faster | 10 seconds | Versus and Campaign |
| Jump | Jump higher | 10 seconds | Versus and Campaign |
| Shield | Absorbs 2 hits before breaking | Up to 7 seconds | Versus and Campaign |
| Invisible | The fighter fades from view | 3 seconds | Versus and Campaign |
| Ammo Refill | Refills the main weapon ammo | Instant | Versus and Campaign |
| Swap Position | Cannot shoot while active. Press shoot to shuffle the positions of all living fighters | 3 second window | Versus and Campaign |
| Nuke | Damages every enemy on screen | Instant | Campaign only |
| Freeze | Freezes all enemies in place | 4.5 seconds | Campaign only |

The **AMOUNT** setting controls how often crates appear in Versus:

| Amount | Spawn Interval | Crates at Once |
|---|---|---|
| FEW | 13 to 19 seconds | 1 |
| NORMAL | 6 to 10 seconds | 2 |
| MANY | 3.5 to 6 seconds | 3 |
| CHAOS | 1.5 to 3 seconds | 5 |

---

## Controls

Up to four players can share a single keyboard. Keys, controller buttons, and the device assigned to each player can all be changed in **CONTROLS** from the main menu.

### Default Keyboard Layout

| Player | Move | Jump | Drop Through Platform | Shoot | Knife |
|---|---|---|---|---|---|
| Player 1 | A / D | W | S | F | G |
| Player 2 | Left / Right arrows | Up arrow | Down arrow | / | . |
| Player 3 | J / L | I | K | H | U |
| Player 4 | Numpad 4 / 6 | Numpad 8 | Numpad 5 | Numpad 0 | Numpad . |

### Controllers

| Action | Default Binding |
|---|---|
| Move | Left stick (always active) or D-pad left / right |
| Jump | A button (also available on the left stick) |
| Drop through platform | D-pad down (also available on the left stick) |
| Shoot | X button |
| Knife | Y button |

| Feature | Description |
|---|---|
| Automatic assignment | Players are matched to connected controllers in order, and players left without a controller fall back to the keyboard |
| Hot-plug | Controllers can be connected or disconnected while the game is running |
| Manual assignment | Each player can be set to AUTO, KEYBOARD, or a specific controller number |
| Rebinding | Every keyboard key and controller button can be rebound per player, with reserved keys and buttons protected |
| Analog triggers | Triggers can be used as bindings |
| Vibration | Controller rumble on hits, which can be turned off in Settings |

### Settings

| Setting | Description |
|---|---|
| Music volume | Volume of the soundtrack |
| Sound FX volume | Volume of sound effects and voices |
| Vibration | Controller rumble on or off |
| Fullscreen | Fullscreen on or off |
| Screen shake | Camera shake on or off |
| Show FPS | Shows an FPS counter in the lower left corner |
| FPS limit | 30, 60, 90, 120, 240, or Unlimited |

Settings are edited as a draft and only saved after pressing **SAVE**. An unsaved banner warns about pending changes, and leaving the screen discards them.

---

## Core Features

| Feature | Description |
|---|---|
| Local Multiplayer | 2 to 4 players on one screen with any mix of keyboard and controllers |
| Team Battles | Flexible team lanes with a light handicap system that keeps uneven teams fair |
| 250-Level Campaign | 5 chapters, 50 bosses, 12 enemy types, 12 perks, checkpoints, stars, and ranks |
| Enemy AI | A dedicated AI brain with map navigation drives campaign enemies, with different ranges, burst patterns, and boss traits |
| Mirrored Arenas | Every arena is symmetrical so no side or spawn point has an advantage |
| Rich Hazards | Moving and crumbling platforms, ice, spikes, arrow traps, cannons, geysers, portals, conveyors, and saws |
| Cosmetics | 240 character skins, 30 weapon skins, and 31 accessories with four rarities |
| Persistent Progress | Settings, match setup, campaign progress, and cosmetics are all saved separately |
| Arcade Presentation | Code-drawn UI, animated slash screen transitions, per-map palettes, particles, and weapon effects |
| Audio | Four music tracks (menu, campaign, battle, boss), roughly 100 sound effects, and character voice lines, with separate music and effects buses |
| Smooth Loading | Textures and sounds are preloaded gradually in the background, followed by a GPU warm-up, to avoid hitches during play |
| Legacy Save Migration | Older campaign saves are mapped automatically to the current level numbering |

---

## Game Content at a Glance

| Content | Amount |
|---|---|
| Fighters | 24 (16 originals and 8 new faces) |
| Character Skins | 240 |
| Weapons | 6 (4 main weapons, a pistol, and a knife) |
| Weapon Skins | 30 |
| Accessories | 31 across four slots (10 head, 9 face, 6 neck, 6 back) |
| Arenas | 10, plus a random option |
| Power-Ups | 9 (7 in Versus, 2 exclusive to the Campaign) |
| Campaign | 250 levels, 5 chapters, 10 worlds, 50 bosses, 12 perks |
| Players | 1 to 4 on one screen, with keyboard and controller support |
| Music | 4 tracks (menu, campaign, battle, boss) |

---

## Save Data

All data is stored with Godot's `user://` directory, separate from the game files.

| File | Contents |
|---|---|
| `settings.cfg` | Volumes, fullscreen, vibration, screen shake, FPS options, key bindings, controller bindings, and device choices |
| `match.cfg` | The last used Versus battle settings |
| `campaign.cfg` | Unlocked levels, stars, best scores, ranks, the current run, and the chosen campaign fighter |
| `cosmetics.cfg` | Coins, owned items, and equipped loadouts |

Default location of the `user://` folder:

| Platform | Path |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\BoxSiege` |
| macOS | `~/Library/Application Support/Godot/app_userdata/BoxSiege` |
| Linux | `~/.local/share/godot/app_userdata/BoxSiege` |

Deleting a file resets that part of the game.

---

## Technology

| Layer | Technology |
|---|---|
| Game Engine | Godot 4.7 |
| Language | GDScript |
| Renderer | GL Compatibility (desktop and mobile settings) |
| Base Resolution | 1280x720 with `canvas_items` stretch mode |
| Autoloads | `Global` (game state, settings, audio, input, transitions) and `UIInput` (unified keyboard, controller, and mouse UI input) |
| User Interface | Drawn entirely in code with a custom UI kit |
| Typography | Badaboom, Lilita One, and Digital-7 |
| Graphics | PNG sprites and backdrops at 2D pixel-art filtering (nearest texture filter) |
| Audio | OGG music, WAV and MP3 sound effects, WAV voice lines |
| Asset Tooling | Python with Pillow, NumPy, and OpenCV (optional, maintainers only) |
| Version Control | Git, with `.godot/` and `*.translation` ignored |

---

## Development

### Prerequisites

- [Godot 4.7](https://godotengine.org/download) (the standard build is enough, no .NET build is needed)
- Git, for cloning the project

### Installation

```sh
git clone <this-repository-url>
cd BoxSiege
```

### Running the Project

1. Open Godot and choose **Import**.
2. Select the `project.godot` file in the project folder.
3. Open the project and wait for the first asset import to finish. This can take a while because the project contains over a thousand sprites.
4. Press **F5** to run. The main scene is `scenes/menu.tscn`.

### Exporting a Build

Export presets for **Windows Desktop** (x86_64), **Linux** (x86_64), and **macOS** (universal) are included in `export_presets.cfg`. The Windows and Linux presets embed the game data into a single executable.

1. Install the Godot 4.7 export templates from **Editor, Manage Export Templates**.
2. Open **Project, Export**.
3. Change the export path of each preset to a folder on your machine. The saved paths point to a `Games/BoxSiege` folder outside the project and will probably not exist on your computer.
4. Press **Export Project** for the platform you want.

---

## Configuration

Most gameplay tuning lives in a few data files, so common changes only need small edits.

| Task | Where |
|---|---|
| Change weapon stats (damage, ammo, fire delay, recoil, spread, hold size) | `WEAPONS` in `scripts/global.gd` |
| Enable or disable a weapon or an arena | The `enabled` flag inside `WEAPONS` or `MAPS` in `scripts/global.gd` |
| Change power-up spawn rates | `POWERUP_AMOUNTS` in `scripts/global.gd` |
| Change power-up durations and shield hits | Constants at the top of `scripts/player.gd` |
| Change default controls | `DEFAULT_KEYS` and `DEFAULT_PADS` in `scripts/global.gd` |
| Change the team handicap | `TEAM_NERF` in `scripts/global.gd` |
| Change match limits (health, time range, rounds) | `MAX_HP`, `MIN_TIME`, `MAX_TIME`, and `MAX_WINS` in `scripts/global.gd` |
| Edit a Versus arena layout | `scripts/map_data.gd` |
| Edit Campaign arena variants | `scripts/map_variants.gd` and `scripts/map_variants_late.gd` |
| Add or tune an enemy or boss | `ENEMIES` in `scripts/campaign_data.gd` |
| Edit levels and waves | `levels()` and `level()` in `scripts/campaign_data.gd` |
| Add or tune a perk | `PERKS` and `apply_perks()` in `scripts/campaign_data.gd` |
| Change Campaign coin rewards | `level_value()` and `award_level()` in `scripts/cosmetics.gd` |
| Add a new power-up | Add an icon to `assets/sprites/powerups/`, then register it in `POWERUPS` (`global.gd`) and `PU_INFO` and `apply_powerup()` (`player.gd`) |
| Add a new fighter | Add sprites to `assets/sprites/characters/`, add an entry to `CHARACTERS` in `global.gd`, and update the grid constants in `scripts/select.gd` |
| Change the music | Replace the `.ogg` files in `assets/music/` |

### Cosmetics Pipeline

The file `scripts/cosmetics_data.gd` and the sprites in `assets/sprites/skins/`, `assets/sprites/weaponskins/`, and `assets/sprites/accessories/` are generated by the Python tools in `tools/`. Do not edit `cosmetics_data.gd` by hand. Change the generator scripts instead and run them again:

```sh
pip install pillow numpy opencv-python
cd tools
python3 gen_all.py
```

The generator recolors the original fighter sprites into skins, builds the accessories and weapon skins, creates the coin icon, and rewrites `cosmetics_data.gd`. It must be run from inside the `tools/` folder.

---

</div>

## Project Structure

```
BoxSiege/
├── assets/
│   ├── fonts/                  # Badaboom, Lilita One, Digital-7 (plus the Badaboom license)
│   ├── music/                  # Soundtrack (.ogg): menu, campaign, game, boss
│   ├── sfx/                    # Sound effects, round announcers, and voice/ (fighter voice lines)
│   └── sprites/
│       ├── accessories/        # 31 accessory sprites
│       ├── campaign/           # Boss marker, perk icons, and star
│       ├── characters/         # Fighter sprites and KO sprites, grouped as p1 to p4
│       ├── guns/               # Bullet sprite and weapon sprites per player color
│       ├── powerups/           # 9 power-up icons
│       ├── skins/              # Character skins (240 skins, each with a KO variant)
│       ├── stages/             # Arena backdrops, floors, and spike sprites
│       ├── ui/                 # Title logo, hearts, coin, and infinity icon
│       └── weaponskins/        # 30 weapon skin sprites
├── scenes/                     # Thin scenes that load the matching script
│   ├── menu.tscn               # Main menu (main scene)
│   ├── select.tscn             # Fighter and weapon selection
│   ├── team.tscn               # Team lane selection (3 to 4 players)
│   ├── battle.tscn             # Battle settings
│   ├── game.tscn               # Versus match
│   ├── campaign_hub.tscn       # Campaign level map
│   ├── campaign.tscn           # Campaign level gameplay
│   ├── shop.tscn               # Cosmetic shop
│   └── inventory.tscn          # Cosmetic inventory
├── scripts/                    # All game logic (GDScript)
├── tools/                      # Optional Python asset generators
├── export_presets.cfg          # Windows, Linux, and macOS export presets
├── icon.jpg                    # Project icon
├── project.godot               # Godot project configuration
└── README.md
```

### Scripts Overview

| Script | Responsibility |
|---|---|
| `global.gd` | Autoload with game constants, characters, weapons, maps, settings, input devices, teams, audio, FPS limiter, and scene transitions |
| `ui_input.gd` | Autoload that unifies keyboard, controller, and mouse input for all menus |
| `ui_kit.gd` | Shared UI building blocks: buttons, banners, prompt bars, backgrounds, particles, and screen transitions |
| `menu.gd` | Main menu, player count, settings, controls setup, and the key and button rebinding editor |
| `select.gd` | Fighter, weapon, and skin selection for Versus and Campaign |
| `team.gd` | Team lane screen with handicap summary |
| `battle.gd` | Battle settings screen (map, time, rounds, objects, and power-up rules) |
| `game.gd` | Versus match loop: rounds, timer, sudden death, power-up spawns, pause menu, and results |
| `player.gd` | Player movement, shooting, knife, health, power-up effects, and animation |
| `bullet.gd` and `weapon_fx.gd` | Projectiles, muzzle effects, impacts, and floating text |
| `powerup.gd` | Power-up crate pickup behavior |
| `hazards.gd` | Moving and crumbling platforms, spikes, bounce pads, arrow traps, cannons, vents, portals, conveyors, saws, and ice |
| `map_data.gd` | Base arena layouts and the object density system |
| `map_variants.gd` and `map_variants_late.gd` | Arena variants for Campaign chapters 2 to 5 |
| `nav_map.gd` | Navigation data derived from arena layouts for AI movement |
| `ai_brain.gd` | Enemy AI behavior |
| `campaign_data.gd` | Campaign structure, enemies, bosses, levels, perks, save format, and ranks |
| `campaign_hub.gd` | Campaign level map, chapter and world navigation, and run management |
| `campaign.gd` | Campaign level gameplay: waves, scoring, stars, boss behavior, and rewards |
| `cosmetics.gd` | Coins, ownership, equipping, and cosmetic rendering |
| `cosmetics_data.gd` | Generated cosmetics catalog (do not edit by hand) |
| `cosmetic_ui.gd` | Shop and inventory interface |
| `shop.gd` and `inventory.gd` | Entry points that open the shop and inventory screens |

Each `.gd` file has a matching `.uid` file generated by Godot. Keep these files in version control.

### Scene Flow

```
menu
 ├── CAMPAIGN ──> select (first time only) ──> campaign_hub ──> campaign
 ├── VERSUS ──> select ──> team (3 to 4 players) ──> battle ──> game
 ├── SHOP / INVENTORY (opened from the main menu)
 ├── CONTROLS (controls sheet)
 └── SETTINGS (volume, display, input)
```

---

<div align="center">

## Disclaimer

BOX SIEGE is a game by Equinox Interactive. The game is currently in development, and the content, features, balance, and availability described here may change before release. All game artwork, characters, music, and sound effects belong to their respective creators and are used solely to present the game. The Badaboom font is distributed with its own license, included at `assets/fonts/badaboom_license.txt`. Third-party names and logos (such as Godot Engine, Windows, macOS, and Linux) belong to their respective owners.

---

*Built by Equinox Interactive.*

[Back to Top](#box-siege)

</div>