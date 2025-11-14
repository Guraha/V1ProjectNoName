# Difficulty System Implementation

## Overview
The minigame now has a fully functional difficulty system that adjusts button operations, goal calculations, and required button presses based on whether the player selects **Normal Mode** or **Hard Mode** from the main menu.

## Changes Made

### 1. GameData.gd (Global State)
- Added `minigame1_difficulty: String` variable (values: "normal" or "hard")
- Defaults to "normal"
- Properly resets in the `reset()` function

### 2. main_menu.gd (Difficulty Selection)
- `_on_normal_pressed()` → Sets `GameData.minigame1_difficulty = "normal"`
- `_on_hard_pressed()` → Sets `GameData.minigame1_difficulty = "hard"`
- Difficulty is set before loading the minigame scene

### 3. minigame_1_ui.gd (Core Difficulty Logic)

#### Button Generation (`_generate_round_config()`)
**Normal Mode:**
- 45% Addition (+)
- 40% Subtraction (-)
- 15% Multiplication (×)
- 0% Division (÷)

**Hard Mode:**
- 40% Multiplication (×)
- 40% Division (÷)
- 10% Addition (+)
- 10% Subtraction (-)

#### Goal Calculation
**Normal Mode:**
- Requires **2 button presses** to reach the goal
- Target goal value: **~15**
- Uses `compute_sequence_result(b1, b2)` for 2-button sequences

**Hard Mode:**
- Requires **3 button presses** to reach the goal
- Target goal value: **~20** (higher difficulty)
- Uses new `compute_3button_sequence(b1, b2, b3)` for 3-button sequences

#### New Function: `compute_3button_sequence()`
- Applies three operations in sequence
- Similar logic to 2-button version but handles one more operation
- Ensures result is never zero

#### Updated Function: `_compare_goal_pairs()`
- Now checks difficulty mode
- Normal mode targets value of **15**
- Hard mode targets value of **20**

#### Ready Screen Display (`_show_ready_screen()`)
- Shows `normal_mode` MarginContainer when difficulty is "normal"
- Shows `hardmode` MarginContainer when difficulty is "hard"
- Only one mode indicator visible at a time

## How It Works

### Flow:
1. Player clicks **Normal** or **Hard** in main menu
2. `GameData.minigame1_difficulty` is set to "normal" or "hard"
3. Minigame scene loads
4. Ready screen displays the selected difficulty mode
5. When game starts, `_generate_round_config()` generates buttons based on difficulty:
   - **Normal**: Easier operations (mostly +/-), 2-button solutions
   - **Hard**: Complex operations (mostly ×/÷), 3-button solutions
6. Goal calculation targets appropriate difficulty level
7. Players must find the correct sequence to reach the goal

## Difficulty Comparison

| Feature | Normal Mode | Hard Mode |
|---------|-------------|-----------|
| **Primary Operations** | Addition, Subtraction | Multiplication, Division |
| **Secondary Operations** | Multiplication (15%) | Addition, Subtraction (10% each) |
| **Button Presses Required** | 2 buttons | 3 buttons |
| **Goal Target** | ~15 | ~20 |
| **Operation Frequency** | 45% +, 40% -, 15% × | 40% ×, 40% ÷, 10% +, 10% - |

## Testing
- Select "Normal" in main menu → Should see mostly addition/subtraction buttons, 2-button solutions
- Select "Hard" in main menu → Should see mostly multiplication/division buttons, 3-button solutions
- Ready screen should display the correct difficulty indicator
- Goals should be achievable with the specified number of button presses

## Notes
- Division by zero is prevented in all calculations
- Results are always kept positive and non-zero
- The system uses the top 5 closest goal options for variety
- Difficulty persists across rounds until the game ends
