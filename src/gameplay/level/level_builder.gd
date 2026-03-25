## LevelBuilder — Generates all 5 MVP levels as LevelData Resources in code.
##
## Used by LevelSystem.load_level() as a fallback when a .tres file is not
## found under res://resources/levels/. Avoids PackedInt32Array .tres
## serialisation complexity while keeping level data fully in version control.
##
## Usage:
##   var data: LevelData = LevelBuilder.build("level_001")
##
## LevelSystem integration note:
##   In LevelSystem.load_level(), after ResourceLoader.load() returns null,
##   call LevelBuilder.build(level_id) before emitting the error:
##
##     var data: LevelData = ResourceLoader.load(path) as LevelData
##     if data == null:
##         data = LevelBuilder.build(level_id)
##     if data == null:
##         push_error(...)
##         return
##
## ASCII map key (used in every _level_NNN function):
##   '#' → SOLID (1)   — impassable wall / platform
##   'D' → DIRT_SLOW (2) — diggable; hole closes slowly
##   'F' → DIRT_FAST (3) — diggable; hole closes fast (trap mechanic)
##   'L' → LADDER (4)  — climbable vertical column; solid for gravity
##   'R' → ROPE (5)    — traversable horizontal hang; gravity suspended
##   ' ' / '.' / any — EMPTY (0) — open space
##
## Terrain physics rules (from TerrainSystem):
##   • SOLID and LADDER are_solid → entity stands on them.
##   • EMPTY, LADDER, ROPE are_traversable → entity can occupy them.
##   • DIRT_SLOW/DIRT_FAST are solid while INTACT/DIGGING; traversable when
##     OPEN/CLOSING. Player stands above DIRT tiles just like SOLID.
##
## Level geometry convention used in all designs:
##   • Row 0                 — ceiling (all SOLID)
##   • Row (grid_rows − 1)  — floor   (all SOLID)
##   • Col 0 and Col (grid_cols − 1) — side walls (SOLID)
##   • "Walk rows"  — mostly EMPTY; entities move horizontally here.
##   • "Platform rows" — SOLID/DIRT; entities stand on these from above.
##   • LADDER columns pass through platform rows to connect walk rows.
##   • ROPE tiles sit in walk rows; accessed from an adjacent LADDER.
##
## Implements: production/sprints/sprint-04.md#LVL-03
class_name LevelBuilder
extends RefCounted

# ---------------------------------------------------------------------------
# Public constants
# ---------------------------------------------------------------------------

## Ordered list of all builder-provided level IDs.
## Referenced by LevelSystem._get_next_level_id() when no .tres files exist.
const LEVEL_IDS: Array[String] = [
	"level_001",
	"level_002",
	"level_003",
	"level_004",
	"level_005",
	"level_006",
	"level_007",
	"level_008",
	"level_009",
	"level_010",
]

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Build and return a fully-configured LevelData for the given level_id.
## Returns null when level_id is not recognised.
static func build(level_id: String) -> LevelData:
	match level_id:
		"level_001": return _level_001()
		"level_002": return _level_002()
		"level_003": return _level_003()
		"level_004": return _level_004()
		"level_005": return _level_005()
		"level_006": return _level_006()
		"level_007": return _level_007()
		"level_008": return _level_008()
		"level_009": return _level_009()
		"level_010": return _level_010()
		_:
			return null

# ---------------------------------------------------------------------------
# Level 001 — "Welcome to Dig & Dash"
# ---------------------------------------------------------------------------
## 10 × 8 · 1 guard · 3 pickups · mechanics: DIRT_SLOW, LADDER
##
## Two vertical ladder columns (col 2, col 5) connect three walk rows.
## Guard patrols upper walk row. Player digs DIRT_SLOW to clear paths and
## descends to collect the two lower pickups before reaching the exit.
##
## Grid (each char = one cell; left = col 0, top = row 0):
##
##   R0  ##########   ceiling
##   R1  #........#   [player@1,1]  [guard@7,1]
##   R2  ##LDDD####   platform — L@2; DIRT_SLOW@3,4,5
##   R3  #.L......#   walk row  — L@2
##   R4  ##L##L####   platform — L@2; L@5
##   R5  #....L...#   walk row  — L@5  [pickup@4,5]  [exit@8,5]
##   R6  ##DDDL####   platform — DIRT_SLOW@2,3,4; L@5
##   R7  ##########   floor
##
## Reachability path:
##   (1,1) →walk right→ (3,1) pickup
##   (2,1) →L@2 down→ (2,3) →walk right→ (6,3) pickup
##   (5,3) →L@5 down through R4→ (5,5) →walk left→ (4,5) pickup
##   →walk right→ (8,5) exit
static func _level_001() -> LevelData:
	var data := LevelData.new()
	data.level_id = "level_001"
	data.level_index = 1
	data.level_name = "Welcome to Dig & Dash"
	data.grid_cols = 10
	data.grid_rows = 8

	var rows: Array[String] = [
		"##########",  # R0 — ceiling
		"#........#",  # R1 — upper walk row
		"##LDDD####",  # R2 — upper platform; L@2; DIRT_SLOW@3,4,5
		"#.L......#",  # R3 — mid walk row; L@2
		"##L##L####",  # R4 — mid platform; L@2; L@5
		"#....L...#",  # R5 — lower walk row; L@5
		"##DDDL####",  # R6 — lower platform; DIRT_SLOW@2,3,4; L@5
		"##########",  # R7 — floor
	]
	data.terrain_map = _map_from_ascii(rows, 10)

	data.player_spawn = Vector2i(1, 1)

	var spawns_001: Array[Vector2i] = [Vector2i(7, 1)]
	data.enemy_spawns = spawns_001

	var rescate_001: Array[Vector2i] = [Vector2i(7, 0)]
	data.enemy_rescate_positions = rescate_001

	# (3,1) reachable by walking along R1 (stands on DIRT_SLOW at (3,2))
	# (6,3) reachable via ladder at col 2, then walk right along R3
	# (4,5) reachable via ladder at col 5, then walk left along R5
	var pickups_001: Array[Vector2i] = [
		Vector2i(3, 1),
		Vector2i(6, 3),
		Vector2i(4, 5),
	]
	data.pickup_cells = pickups_001
	data.exit_cell = Vector2i(8, 5)

	return data

# ---------------------------------------------------------------------------
# Level 002 — "Fast Ground"
# ---------------------------------------------------------------------------
## 10 × 8 · 1 guard · 4 pickups · mechanics: DIRT_FAST (new)
##
## A single tall ladder at col 1 gives vertical access across all walk rows.
## The guard patrols the middle walk row over a DIRT_FAST platform.
## Player must dig fast holes under the guard to trap it, then collect the
## pickups while the holes are open.  Holes close quickly — no camping!
##
## Grid:
##
##   R0  ##########   ceiling
##   R1  #L.......#   [player@1,1]
##   R2  #L########   platform — L@1
##   R3  #L.FFFF..#   walk row  — L@1; DIRT_FAST@3,4,5,6  [guard@8,3]
##   R4  #L########   platform — L@1
##   R5  #L.......#   walk row  — L@1
##   R6  #L########   platform — L@1
##   R7  ##########   floor
##
## Reachability path:
##   (1,1) →walk right→ (3,1) & (8,1) pickups
##   (1,1) →L@1 down→ (1,3) →walk right→ dig DIRT_FAST to pass mid section
##   (1,3) →L@1 down→ (1,5) →walk right→ (3,5) & (7,5) pickups → (8,5) exit
static func _level_002() -> LevelData:
	var data := LevelData.new()
	data.level_id = "level_002"
	data.level_index = 2
	data.level_name = "Fast Ground"
	data.grid_cols = 10
	data.grid_rows = 8

	var rows: Array[String] = [
		"##########",  # R0 — ceiling
		"#L.......#",  # R1 — upper walk row; L@1
		"#L########",  # R2 — upper platform; L@1
		"#L.FFFF..#",  # R3 — mid walk row; L@1; DIRT_FAST@3,4,5,6
		"#L########",  # R4 — mid platform; L@1
		"#L.......#",  # R5 — lower walk row; L@1
		"#L########",  # R6 — lower platform; L@1
		"##########",  # R7 — floor
	]
	data.terrain_map = _map_from_ascii(rows, 10)

	data.player_spawn = Vector2i(1, 1)

	var spawns_002: Array[Vector2i] = [Vector2i(8, 3)]
	data.enemy_spawns = spawns_002

	var rescate_002: Array[Vector2i] = [Vector2i(8, 0)]
	data.enemy_rescate_positions = rescate_002

	# (3,1) & (8,1): on upper walk row — player walks to collect
	# (3,5) & (7,5): on lower walk row — player descends via ladder
	var pickups_002: Array[Vector2i] = [
		Vector2i(3, 1),
		Vector2i(8, 1),
		Vector2i(3, 5),
		Vector2i(7, 5),
	]
	data.pickup_cells = pickups_002
	data.exit_cell = Vector2i(8, 5)

	return data

# ---------------------------------------------------------------------------
# Level 003 — "Two Guards"
# ---------------------------------------------------------------------------
## 12 × 8 · 2 guards · 4 pickups · mechanics: LADDER multi-level traversal
##
## Two independent LADDER columns (col 2 and col 8) give two vertical paths
## across three walk rows.  Guard 1 patrols the upper row; guard 2 patrols
## the mid row.  Player must use both ladders to stay ahead of the guards
## and reach all pickups before the exit.
##
## Grid (12 cols, 0–11):
##
##   R0  ############   ceiling
##   R1  #..........#   [player@1,1]  [guard1@10,1]
##   R2  ##LDDD######   platform — L@2; DIRT_SLOW@3,4,5
##   R3  #.L.....L..#   walk row  — L@2; L@8  [guard2@10,3]
##   R4  ##L#####L###   platform — L@2; L@8
##   R5  #.L.....L..#   walk row  — L@2; L@8
##   R6  ##LDDD###L##   platform — L@2; DIRT_SLOW@3,4,5; L@9
##   R7  ############   floor
##
## Reachability path:
##   (1,1) →walk right→ (3,1) pickup (stands on DIRT_SLOW at R2)
##   (2,1) →L@2 down→ (2,3) →walk right→ (7,3) pickup
##   (2,3) →L@2 down→ (2,5) →walk right→ (3,5) pickup
##   (8,5) →walk right→ (9,5) pickup → (10,5) exit
##   Alternative: (8,3) →L@8 down→ (8,5)
static func _level_003() -> LevelData:
	var data := LevelData.new()
	data.level_id = "level_003"
	data.level_index = 3
	data.level_name = "Two Guards"
	data.grid_cols = 12
	data.grid_rows = 8

	var rows: Array[String] = [
		"############",  # R0 — ceiling
		"#..........#",  # R1 — upper walk row
		"##LDDD######",  # R2 — upper platform; L@2; DIRT_SLOW@3,4,5
		"#.L.....L..#",  # R3 — mid walk row; L@2; L@8
		"##L#####L###",  # R4 — mid platform; L@2; L@8
		"#.L.....L..#",  # R5 — lower walk row; L@2; L@8
		"##LDDD###L##",  # R6 — lower platform; L@2; DIRT_SLOW@3,4,5; L@9
		"############",  # R7 — floor
	]
	data.terrain_map = _map_from_ascii(rows, 12)

	data.player_spawn = Vector2i(1, 1)

	var spawns_003: Array[Vector2i] = [Vector2i(10, 1), Vector2i(10, 3)]
	data.enemy_spawns = spawns_003

	var rescate_003: Array[Vector2i] = [Vector2i(10, 0), Vector2i(5, 0)]
	data.enemy_rescate_positions = rescate_003

	# (3,1): upper row — stands on DIRT_SLOW below (3,2)
	# (7,3): mid row   — reachable via L@2 then walk right
	# (3,5): lower row — reachable via L@2 through R4
	# (9,5): lower row — reachable by walking right; stands on L@9 at (9,6)
	var pickups_003: Array[Vector2i] = [
		Vector2i(3, 1),
		Vector2i(7, 3),
		Vector2i(3, 5),
		Vector2i(9, 5),
	]
	data.pickup_cells = pickups_003
	data.exit_cell = Vector2i(10, 5)

	return data

# ---------------------------------------------------------------------------
# Level 004 — "Rope Walk"
# ---------------------------------------------------------------------------
## 12 × 8 · 2 guards · 5 pickups · mechanics: ROPE (new)
##
## A ROPE segment spans cols 3–6 of the mid walk row.  Player must descend
## via the ladder at col 2, grab the rope, traverse it to collect the two
## rope pickups, then drop down from ladder col 7 to the lower level.
## Guard 1 patrols the upper walk row (right side); guard 2 patrols the
## lower walk row (left-centre), standing on the DIRT_SLOW platform below.
##
## Grid (12 cols, 0–11):
##
##   R0  ############   ceiling
##   R1  #..........#   [player@1,1]  [guard1@10,1]
##   R2  ##L#########   platform — L@2 only
##   R3  #.LRRRRL...#   walk row  — L@2; ROPE@3,4,5,6; L@7  [guard1 patrols R1]
##   R4  ##L####L####   platform — L@2; L@7
##   R5  #.L....L...#   walk row  — L@2; L@7  [guard2@5,5]
##   R6  ##LDDD##L###   platform — L@2; DIRT_SLOW@3,4,5; L@8
##   R7  ############   floor
##
## Reachability path:
##   (1,1) →walk right→ (3,1) & (9,1) pickups
##   (2,1) →L@2 down→ (2,3) →walk right→ (3,3) ROPE
##   →traverse rope right→ (4,3) pickup; (5,3) pickup
##   →continue rope→ (7,3) L; →L@7 down→ (7,5)
##   (7,5) →walk left→ (3,5) pickup; →walk right→ (9,5) pickup → exit
static func _level_004() -> LevelData:
	var data := LevelData.new()
	data.level_id = "level_004"
	data.level_index = 4
	data.level_name = "Rope Walk"
	data.grid_cols = 12
	data.grid_rows = 8

	var rows: Array[String] = [
		"############",  # R0 — ceiling
		"#..........#",  # R1 — upper walk row
		"##L#########",  # R2 — upper platform; L@2 only
		"#.LRRRRL...#",  # R3 — mid walk row; L@2; ROPE@3,4,5,6; L@7
		"##L####L####",  # R4 — mid platform; L@2; L@7
		"#.L....L...#",  # R5 — lower walk row; L@2; L@7
		"##LDDD##L###",  # R6 — lower platform; L@2; DIRT_SLOW@3,4,5; L@8
		"############",  # R7 — floor
	]
	data.terrain_map = _map_from_ascii(rows, 12)

	data.player_spawn = Vector2i(1, 1)

	var spawns_004: Array[Vector2i] = [Vector2i(10, 1), Vector2i(5, 5)]
	data.enemy_spawns = spawns_004

	var rescate_004: Array[Vector2i] = [Vector2i(10, 0), Vector2i(5, 0)]
	data.enemy_rescate_positions = rescate_004

	# (3,1) & (9,1): upper walk row
	# (4,3) & (5,3): on ROPE in mid walk row — player hangs to collect
	# (3,5): lower walk row — stands on DIRT_SLOW at (3,6)
	# (9,5): lower walk row — stands on SOLID at (9,6)
	var pickups_004: Array[Vector2i] = [
		Vector2i(3, 1),
		Vector2i(9, 1),
		Vector2i(4, 3),
		Vector2i(5, 3),
		Vector2i(3, 5),
	]
	data.pickup_cells = pickups_004
	data.exit_cell = Vector2i(9, 5)

	return data

# ---------------------------------------------------------------------------
# Level 005 — "Multi-Platform"
# ---------------------------------------------------------------------------
## 14 × 8 · 2 guards · 5 pickups · mechanics: DIRT_SLOW + DIRT_FAST + LADDER + ROPE
##
## The widest level uses every mechanic.  Two ladder columns (col 2 and col 11)
## form the vertical skeleton.  A ROPE segment at the mid walk row gives
## horizontal access to the right half, where pickups sit above DIRT_FAST
## tiles.  Guard 1 patrols the upper row (far right); guard 2 patrols the
## lower row (centre-right).  DIRT_SLOW appears on the left side of both
## platforms; DIRT_FAST on the right side — forcing different timing decisions.
##
## Grid (14 cols, 0–13):
##
##   R0  ##############   ceiling
##   R1  #............#   [player@1,1]  [guard1@12,1]
##   R2  ##LDDD##FFF###   platform — L@2; DIRT_SLOW@3,4,5; DIRT_FAST@8,9,10
##   R3  #.L....RRRRL.#   walk row  — L@2; ROPE@7,8,9,10; L@11
##   R4  ##L########L##   platform — L@2; L@11
##   R5  #.L........L.#   walk row  — L@2; L@11  [guard2@10,5]
##   R6  ##LDDD###FFF##   platform — L@2; DIRT_SLOW@3,4,5; DIRT_FAST@9,10,11
##   R7  ##############   floor
##
## Reachability path:
##   (1,1) →walk right→ (3,1) pickup (stands on DIRT_SLOW)
##   (1,1) →walk right→ (10,1) pickup (stands on DIRT_FAST; dig to access)
##   (2,1) →L@2 down→ (2,3) →walk right→ (4,3) pickup
##   (6,3) →enter ROPE@7→ traverse right→ (9,3) pickup
##   (11,3) L; →L@11 down→ (11,5)
##   (11,5) →walk left→ (4,5) pickup; →walk right→ (12,5) exit
static func _level_005() -> LevelData:
	var data := LevelData.new()
	data.level_id = "level_005"
	data.level_index = 5
	data.level_name = "Multi-Platform"
	data.grid_cols = 14
	data.grid_rows = 8

	var rows: Array[String] = [
		"##############",  # R0 — ceiling
		"#............#",  # R1 — upper walk row
		"##LDDD##FFF###",  # R2 — upper platform; L@2; DIRT_SLOW@3,4,5; DIRT_FAST@8,9,10
		"#.L....RRRRL.#",  # R3 — mid walk row; L@2; ROPE@7,8,9,10; L@11
		"##L########L##",  # R4 — mid platform; L@2; L@11
		"#.L........L.#",  # R5 — lower walk row; L@2; L@11
		"##LDDD###FFF##",  # R6 — lower platform; L@2; DIRT_SLOW@3,4,5; DIRT_FAST@9,10,11
		"##############",  # R7 — floor
	]
	data.terrain_map = _map_from_ascii(rows, 14)

	data.player_spawn = Vector2i(1, 1)

	var spawns_005: Array[Vector2i] = [Vector2i(12, 1), Vector2i(10, 5)]
	data.enemy_spawns = spawns_005

	var rescate_005: Array[Vector2i] = [Vector2i(12, 0), Vector2i(10, 0)]
	data.enemy_rescate_positions = rescate_005

	# (3,1):  upper row — stands on DIRT_SLOW at (3,2)
	# (10,1): upper row — stands on DIRT_FAST at (10,2); guard1@(12,1) nearby
	# (4,3):  mid walk row  — reachable by walking right from L@2
	# (9,3):  on ROPE in mid walk row — player hangs to collect
	# (4,5):  lower walk row — stands on DIRT_SLOW at (4,6)
	var pickups_005: Array[Vector2i] = [
		Vector2i(3, 1),
		Vector2i(10, 1),
		Vector2i(4, 3),
		Vector2i(9, 3),
		Vector2i(4, 5),
	]
	data.pickup_cells = pickups_005
	data.exit_cell = Vector2i(12, 5)

	return data

# ---------------------------------------------------------------------------
# Level 006 — "The Descent"
# ---------------------------------------------------------------------------
## 14 × 8 · 2 guards · 5 pickups · mechanics: DIRT_SLOW multi-level dig strategy
##
## Two DIRT_SLOW platform bands (R2, R4) create a layered descent puzzle.
## A central LADDER column at col 7 threads through both platform rows,
## connecting the three walk rows.  Guard 1 patrols the upper walk row (far
## right); Guard 2 patrols the mid walk row (centre-left).  Player must dig
## through R2 DIRT to reach the mid row, collect the pickup there, then use
## the col-7 ladder to descend to the lower row where three more pickups and
## the exit wait.  Flanking ladders at col 2 and col 11 give return routes.
##
## Grid (14 cols, 0–13):
##
##   R0  ##############   ceiling
##   R1  #............#   [player@1,1]  [guard1@12,1]
##   R2  ##DDDD###DDD##   platform — DIRT_SLOW@2,3,4,5; DIRT_SLOW@9,10,11
##   R3  #......L.....#   walk row  — LADDER@7  [guard2@6,3]
##   R4  ##DDD##L##DDD#   platform — DIRT_SLOW@2,3,4; LADDER@7; DIRT_SLOW@10,11,12
##   R5  #.L........L.#   walk row  — LADDER@2; LADDER@11
##   R6  ##L########L##   platform — LADDER@2; LADDER@11
##   R7  ##############   floor
##
## Reachability path:
##   (1,1) →walk right→ (3,1) pickup; (10,1) pickup [guard1@12,1 nearby]
##   (3,1) →dig (4,2)→ fall to (4,3) →walk right→ (4,3) pickup
##   (4,3) →walk right→ (7,3) L@7 →descend→ (7,5) in R5
##   (7,5) →walk left→ (2,5) pickup; →walk right→ (9,5) pickup → (12,5) exit
##
## Design note: guard2@(6,3) is bypassed by digging a pit in R4 at col 4
## (DIRT_SLOW) while standing at (5,3), trapping the guard before passing.
static func _level_006() -> LevelData:
	var data := LevelData.new()
	data.level_id = "level_006"
	data.level_index = 6
	data.level_name = "The Descent"
	data.grid_cols = 14
	data.grid_rows = 8

	var rows: Array[String] = [
		"##############",  # R0 — ceiling
		"#............#",  # R1 — upper walk row
		"##DDDD###DDD##",  # R2 — upper platform; DIRT_SLOW@2,3,4,5; DIRT_SLOW@9,10,11
		"#......L.....#",  # R3 — mid walk row; LADDER@7
		"##DDD##L##DDD#",  # R4 — mid platform; DIRT_SLOW@2,3,4; LADDER@7; DIRT_SLOW@10,11,12
		"#.L........L.#",  # R5 — lower walk row; LADDER@2; LADDER@11
		"##L########L##",  # R6 — lower platform; LADDER@2; LADDER@11
		"##############",  # R7 — floor
	]
	data.terrain_map = _map_from_ascii(rows, 14)

	data.player_spawn = Vector2i(1, 1)

	var spawns_006: Array[Vector2i] = [Vector2i(12, 1), Vector2i(6, 3)]
	data.enemy_spawns = spawns_006

	var rescate_006: Array[Vector2i] = [Vector2i(12, 0), Vector2i(6, 0)]
	data.enemy_rescate_positions = rescate_006

	# (3,1):  upper walk row — walks right from player spawn
	# (10,1): upper walk row — near guard1; collected before guard closes in
	# (4,3):  mid walk row   — reached by digging R2 DIRT and falling
	# (2,5):  lower walk row — LADDER tile; collected while descending/traversing
	# (9,5):  lower walk row — walked to after using L@7 to reach R5
	var pickups_006: Array[Vector2i] = [
		Vector2i(3, 1),
		Vector2i(10, 1),
		Vector2i(4, 3),
		Vector2i(2, 5),
		Vector2i(9, 5),
	]
	data.pickup_cells = pickups_006
	data.exit_cell = Vector2i(12, 5)

	return data

# ---------------------------------------------------------------------------
# Level 007 — "Fast or Die"
# ---------------------------------------------------------------------------
## 14 × 8 · 3 guards · 5 pickups · mechanics: DIRT_FAST throughout — timing
##
## Every platform is DIRT_FAST — holes open instantly and close fast.  Three
## guards cover all three walk rows.  Player must exploit the brief window
## that each dug hole provides: trap guards by digging under them, then sprint
## through before the ground closes.  The wide grid and three active guards
## mean standing still is death.
##
## Grid (14 cols, 0–13):
##
##   R0  ##############   ceiling
##   R1  #............#   [player@1,1]  [guard1@12,1]
##   R2  ##FFFF###FFFF#   platform — DIRT_FAST@2,3,4,5; DIRT_FAST@9,10,11,12
##   R3  #......L.....#   walk row  — LADDER@7  [guard2@6,3]
##   R4  ##FFF##L##FFF#   platform — DIRT_FAST@2,3,4; LADDER@7; DIRT_FAST@10,11,12
##   R5  #.L........L.#   walk row  — LADDER@2; LADDER@11  [guard3@8,5]
##   R6  ##L########L##   platform — LADDER@2; LADDER@11
##   R7  ##############   floor
##
## Reachability path:
##   (1,1) →walk right→ (3,1) pickup; (10,1) pickup [guard1@12,1 — dig (12,2)!]
##   (3,1) →dig (4,2) DIRT_FAST→ fall to (4,3); →walk left→ (3,3) pickup
##   (3,3) →walk right→ (7,3) L@7 →descend through R4→ (7,5) in R5
##   (7,5) →walk left→ (6,5) pickup; →walk right→ (10,5) pickup → (12,5) exit
##   [guard3@8,5 — dig (7,6) or (9,6) SOLID... use timing to sprint past]
static func _level_007() -> LevelData:
	var data := LevelData.new()
	data.level_id = "level_007"
	data.level_index = 7
	data.level_name = "Fast or Die"
	data.grid_cols = 14
	data.grid_rows = 8

	var rows: Array[String] = [
		"##############",  # R0 — ceiling
		"#............#",  # R1 — upper walk row
		"##FFFF###FFFF#",  # R2 — upper platform; DIRT_FAST@2,3,4,5; DIRT_FAST@9,10,11,12
		"#......L.....#",  # R3 — mid walk row; LADDER@7
		"##FFF##L##FFF#",  # R4 — mid platform; DIRT_FAST@2,3,4; LADDER@7; DIRT_FAST@10,11,12
		"#.L........L.#",  # R5 — lower walk row; LADDER@2; LADDER@11
		"##L########L##",  # R6 — lower platform; LADDER@2; LADDER@11
		"##############",  # R7 — floor
	]
	data.terrain_map = _map_from_ascii(rows, 14)

	data.player_spawn = Vector2i(1, 1)

	var spawns_007: Array[Vector2i] = [Vector2i(12, 1), Vector2i(6, 3), Vector2i(8, 5)]
	data.enemy_spawns = spawns_007

	var rescate_007: Array[Vector2i] = [Vector2i(12, 0), Vector2i(6, 0), Vector2i(8, 0)]
	data.enemy_rescate_positions = rescate_007

	# (3,1):  upper walk row — walks right from spawn
	# (10,1): upper walk row — guard1@12,1 is right next door; dig (12,2) first!
	# (3,3):  mid walk row   — reached after digging R2 and falling to R3
	# (6,5):  lower walk row — left of guard3@8,5; sprint timing required
	# (10,5): lower walk row — right of guard3@8,5; sprint timing required
	var pickups_007: Array[Vector2i] = [
		Vector2i(3, 1),
		Vector2i(10, 1),
		Vector2i(3, 3),
		Vector2i(6, 5),
		Vector2i(10, 5),
	]
	data.pickup_cells = pickups_007
	data.exit_cell = Vector2i(12, 5)

	return data

# ---------------------------------------------------------------------------
# Level 008 — "The Rope Bridge"
# ---------------------------------------------------------------------------
## 14 × 8 · 2 guards · 6 pickups · mechanics: ROPE traversal central
##
## A central ROPE segment (cols 4–10) in the mid walk row is the only way to
## reach the three rope pickups and cross to the right side of the level.
## Flanking LADDER columns at col 2 and col 11 connect all three walk rows.
## Guard 1 patrols the right end of the mid walk row; Guard 2 starts in the
## lower walk row centre and must be outmanoeuvred while collecting the final
## lower pickup.  DIRT_SLOW in R5 provides trapping opportunities.
##
## Grid (14 cols, 0–13):
##
##   R0  ##############   ceiling
##   R1  #............#   [player@1,1]  ← exit@12,1
##   R2  ##L########L##   platform — LADDER@2; LADDER@11
##   R3  #.L.RRRRRRRL.#   walk row  — LADDER@2; ROPE@4,5,6,7,8,9,10; LADDER@11
##                                      [guard1@12,3]
##   R4  ##L########L##   platform — LADDER@2; LADDER@11
##   R5  #.LDDD..DDDL.#   walk row  — LADDER@2; DIRT_SLOW@3,4,5;
##                                      DIRT_SLOW@8,9,10; LADDER@11  [guard2@7,5]
##   R6  ##L########L##   platform — LADDER@2; LADDER@11
##   R7  ##############   floor
##
## Reachability path:
##   (1,1) →walk right→ (3,1) pickup; (5,1) pickup
##   (2,1) →L@2 down→ (2,2) →(2,3) on L; →step right→ ROPE@4
##   →traverse rope→ (7,3),(8,3),(9,3) pickups
##   (11,3) L; →L@11 down→ (11,5) in R5 → (11,5) LADDER: collect (11,5)
##   wait! pickup is at (6,5); walk left from (11,5): →(6,5) pickup
##   →(2,5) →L@2 up→ (2,3) →(2,2) →(2,1) →walk right→ (12,1) exit
##
## Design note (spec correction):
##   Original spec placed guard2@(5,5) on DIRT_SLOW and pickup@(4,5) on
##   DIRT_SLOW — both invalid for occupancy.  Guard2 moved to (7,5) '.' and
##   pickup moved to (6,5) '.' to place them on traversable empty cells.
##   Rescate updated from (5,0) to (7,0) accordingly.
static func _level_008() -> LevelData:
	var data := LevelData.new()
	data.level_id = "level_008"
	data.level_index = 8
	data.level_name = "The Rope Bridge"
	data.grid_cols = 14
	data.grid_rows = 8

	var rows: Array[String] = [
		"##############",  # R0 — ceiling
		"#............#",  # R1 — upper walk row; exit@(12,1)
		"##L########L##",  # R2 — upper platform; LADDER@2; LADDER@11
		"#.L.RRRRRRRL.#",  # R3 — mid walk row; LADDER@2; ROPE@4,5,6,7,8,9,10; LADDER@11
		"##L########L##",  # R4 — mid platform; LADDER@2; LADDER@11
		"#.LDDD..DDDL.#",  # R5 — lower walk row; LADDER@2; DIRT_SLOW@3,4,5; DIRT_SLOW@8,9,10; LADDER@11
		"##L########L##",  # R6 — lower platform; LADDER@2; LADDER@11
		"##############",  # R7 — floor
	]
	data.terrain_map = _map_from_ascii(rows, 14)

	data.player_spawn = Vector2i(1, 1)

	# guard2 corrected from (5,5) [DIRT tile] to (7,5) [EMPTY tile]
	var spawns_008: Array[Vector2i] = [Vector2i(12, 3), Vector2i(7, 5)]
	data.enemy_spawns = spawns_008

	# rescate updated from (5,0) to (7,0) to match guard2 correction
	var rescate_008: Array[Vector2i] = [Vector2i(12, 0), Vector2i(7, 0)]
	data.enemy_rescate_positions = rescate_008

	# (3,1) & (5,1): upper walk row — walked to from spawn
	# (7,3),(8,3),(9,3): on ROPE in mid walk row — player hangs to collect
	# (6,5): lower walk row — corrected from (4,5) which was on DIRT_SLOW;
	#         guard2@(7,5) is one cell right; player approaches from left via L@2
	var pickups_008: Array[Vector2i] = [
		Vector2i(3, 1),
		Vector2i(5, 1),
		Vector2i(7, 3),
		Vector2i(8, 3),
		Vector2i(9, 3),
		Vector2i(6, 5),
	]
	data.pickup_cells = pickups_008
	data.exit_cell = Vector2i(12, 1)

	return data

# ---------------------------------------------------------------------------
# Level 009 — "Guard Rush"
# ---------------------------------------------------------------------------
## 14 × 8 · 3 guards · 6 pickups · mechanics: guards converge from right
##
## All three guards spawn at col 12 — one per walk row — and rush left
## simultaneously.  The exit is at the far LEFT of the bottom walk row,
## forcing the player to race right for pickups then sprint back left to
## escape.  DIRT_SLOW in R2 creates trapping opportunities above the mid
## and lower guards.  Twin LADDER columns at col 4 and col 10 let the
## player descend quickly while creating natural chokepoints.
##
## Grid (14 cols, 0–13):
##
##   R0  ##############   ceiling
##   R1  #............#   [player@1,1]  [guard1@12,1]
##   R2  ####DDD###DDD#   platform — DIRT_SLOW@4,5,6; DIRT_SLOW@10,11,12
##   R3  #...L.....L..#   walk row  — LADDER@4; LADDER@10  [guard2@12,3]
##   R4  ####L#####L###   platform — LADDER@4; LADDER@10
##   R5  #...L.....L..#   walk row  — LADDER@4; LADDER@10  [guard3@12,5]
##   R6  ##############   solid bottom platform
##   R7  ##############   floor
##
## Reachability path:
##   (1,1) →walk right→ (4,1),(7,1),(10,1) pickups — guard1 closing in!
##   (5,1) →dig (4,2) DIRT_SLOW→ walk to (4,1) →fall to (4,3) ← on L@4
##   (4,3) pickup collected while on ladder; →L@4 down→ (4,5) in R5
##   (4,5) →walk right→ (7,5) pickup; →(10,5) pickup on L@10
##   →walk left all the way→ (1,5) exit  [guards from col 12 converging!]
##
## Design note (spec correction):
##   Original R6 "#.L........L.#" left col 12 in R6 as EMPTY, so guard3
##   at (12,5) would have no solid tile below.  R6 changed to "##############"
##   (solid platform) so all entities in R5 stand firm at every column.
static func _level_009() -> LevelData:
	var data := LevelData.new()
	data.level_id = "level_009"
	data.level_index = 9
	data.level_name = "Guard Rush"
	data.grid_cols = 14
	data.grid_rows = 8

	var rows: Array[String] = [
		"##############",  # R0 — ceiling
		"#............#",  # R1 — upper walk row
		"####DDD###DDD#",  # R2 — upper platform; DIRT_SLOW@4,5,6; DIRT_SLOW@10,11,12
		"#...L.....L..#",  # R3 — mid walk row; LADDER@4; LADDER@10
		"####L#####L###",  # R4 — mid platform; LADDER@4; LADDER@10
		"#...L.....L..#",  # R5 — lower walk row; LADDER@4; LADDER@10
		"##############",  # R6 — solid bottom platform (all cols must be SOLID
						   #       so guard3@12,5 stands on a solid tile below)
		"##############",  # R7 — floor
	]
	data.terrain_map = _map_from_ascii(rows, 14)

	data.player_spawn = Vector2i(1, 1)

	var spawns_009: Array[Vector2i] = [Vector2i(12, 1), Vector2i(12, 3), Vector2i(12, 5)]
	data.enemy_spawns = spawns_009

	var rescate_009: Array[Vector2i] = [Vector2i(12, 0), Vector2i(12, 0), Vector2i(12, 0)]
	data.enemy_rescate_positions = rescate_009

	# (4,1),(7,1),(10,1): upper walk row — sprint right from spawn before guard1
	# (4,3): on LADDER@4 in mid walk row — collected while descending
	# (7,5):  lower walk row — EMPTY cell; collected quickly before guards arrive
	# (10,5): on LADDER@10 in lower walk row — collected at ladder; then sprint left
	var pickups_009: Array[Vector2i] = [
		Vector2i(4, 1),
		Vector2i(7, 1),
		Vector2i(10, 1),
		Vector2i(4, 3),
		Vector2i(7, 5),
		Vector2i(10, 5),
	]
	data.pickup_cells = pickups_009
	data.exit_cell = Vector2i(1, 5)

	return data

# ---------------------------------------------------------------------------
# Level 010 — "The Final Puzzle"
# ---------------------------------------------------------------------------
## 14 × 10 · 3 guards · 7 pickups · mechanics: all combined, extra-tall grid
##
## The widest and tallest level combines every mechanic.  An upper ROPE band
## (R3) spans cols 3–10 between LADDER columns at col 2 and col 11.  A middle
## DIRT_SLOW/DIRT_FAST band (R5) requires careful digging to navigate.  The
## DIRT_FAST-rich lower platform (R8) provides trapping opportunities near
## the exit.  Guard 3 starts ON the exit cell — the player must dig the
## DIRT_SLOW tile below the guard to open a pit, drop the guard in, then
## sprint to the exit before the tile closes.
##
## Grid (14 cols, 0–13; 10 rows, 0–9):
##
##   R0  ##############   ceiling
##   R1  #............#   [player@1,1]  [guard1@12,1]
##   R2  ##LDDD###FFF##   platform — LADDER@2; DIRT_SLOW@3,4,5; DIRT_FAST@9,10,11
##   R3  #.LRRRRRRRRL.#   rope walk — LADDER@2; ROPE@3,4,5,6,7,8,9,10; LADDER@11
##   R4  ##L########L##   mid platform — LADDER@2; LADDER@11
##   R5  #.LDDD..DDDL.#   mid walk — LADDER@2; DIRT_SLOW@3,4,5;
##                                    DIRT_SLOW@8,9,10; LADDER@11  [guard2@7,5]
##   R6  ##L########L##   lower platform — LADDER@2; LADDER@11
##   R7  #.L........L.#   lower walk — LADDER@2; LADDER@11  [guard3@12,7] ←exit
##   R8  ##DDDD###FDDD#   lower platform — DIRT_SLOW@2,3,4,5; DIRT_FAST@9;
##                                         DIRT_SLOW@10,11,12
##   R9  ##############   floor
##
## Reachability path:
##   (1,1) →walk right→ (3,1) pickup; (10,1) pickup [guard1@12,1 nearby]
##   (2,1) →L@2 down through R2→ (2,3) →step right→ ROPE@3
##   →traverse rope→ (4,3),(9,3) pickups; →(11,3) L@11
##   (2,3) or (11,3) L →down through R4→ (2,5) or (11,5) — collect LADDER pickups
##   (2,5) or (11,5) →down through R6→ (2,7) or (11,7) in R7
##   (2,7) →walk right→ (6,7) pickup → near guard3@(12,7)
##   (11,7) →dig (12,8) DIRT_SLOW from (11,7)→ guard3 falls into pit
##   →sprint to (12,7) exit before DIRT_SLOW closes!
##
## Design notes (spec corrections):
##   • R2 changed from "##DDD####FFF##" to "##LDDD###FFF##": LADDER added at
##     col 2 so the player can descend from R1 into R3 to access the ROPE.
##     DIRT_SLOW shifts from cols 2,3,4 to cols 3,4,5 (functionally equivalent).
##   • guard2 moved from (7,4) [inside solid platform R4] to (7,5) [EMPTY in R5].
##     Rescate remains at (7,0).
##   • guard3@(12,7) intentionally occupies the exit cell — final-puzzle design.
static func _level_010() -> LevelData:
	var data := LevelData.new()
	data.level_id = "level_010"
	data.level_index = 10
	data.level_name = "The Final Puzzle"
	data.grid_cols = 14
	data.grid_rows = 10

	var rows: Array[String] = [
		"##############",  # R0 — ceiling
		"#............#",  # R1 — upper walk row
		"##LDDD###FFF##",  # R2 — upper platform; LADDER@2; DIRT_SLOW@3,4,5; DIRT_FAST@9,10,11
		"#.LRRRRRRRRL.#",  # R3 — rope walk row; LADDER@2; ROPE@3,4,5,6,7,8,9,10; LADDER@11
		"##L########L##",  # R4 — mid platform; LADDER@2; LADDER@11
		"#.LDDD..DDDL.#",  # R5 — mid walk row; LADDER@2; DIRT_SLOW@3,4,5; DIRT_SLOW@8,9,10; LADDER@11
		"##L########L##",  # R6 — lower platform; LADDER@2; LADDER@11
		"#.L........L.#",  # R7 — lower walk row; LADDER@2; LADDER@11
		"##DDDD###FDDD#",  # R8 — lower platform; DIRT_SLOW@2,3,4,5; DIRT_FAST@9; DIRT_SLOW@10,11,12
		"##############",  # R9 — floor
	]
	data.terrain_map = _map_from_ascii(rows, 14)

	data.player_spawn = Vector2i(1, 1)

	# guard2 corrected from (7,4) [solid R4 platform tile] to (7,5) [EMPTY in R5]
	# guard3 intentionally placed on exit (12,7) — player must trap it to win
	var spawns_010: Array[Vector2i] = [Vector2i(12, 1), Vector2i(7, 5), Vector2i(12, 7)]
	data.enemy_spawns = spawns_010

	var rescate_010: Array[Vector2i] = [Vector2i(12, 0), Vector2i(7, 0), Vector2i(12, 0)]
	data.enemy_rescate_positions = rescate_010

	# (3,1):  upper walk row — walked to from spawn
	# (10,1): upper walk row — guard1@12,1 nearby; collect quickly
	# (4,3):  on ROPE in rope walk row — player hangs to collect
	# (9,3):  on ROPE in rope walk row — player hangs to collect
	# (2,5):  on LADDER@2 in mid walk row — collected while descending
	# (11,5): on LADDER@11 in mid walk row — collected while descending
	# (6,7):  lower walk row — EMPTY; collected during sprint to exit
	var pickups_010: Array[Vector2i] = [
		Vector2i(3, 1),
		Vector2i(10, 1),
		Vector2i(4, 3),
		Vector2i(9, 3),
		Vector2i(2, 5),
		Vector2i(11, 5),
		Vector2i(6, 7),
	]
	data.pickup_cells = pickups_010
	data.exit_cell = Vector2i(12, 7)

	return data

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Build a flat row-major PackedInt32Array from a 2D ASCII grid.
##
## rows  — array of strings; each string must be exactly cols characters long.
## cols  — declared grid width; strings shorter than this are right-padded with
##         EMPTY tiles so the map length is always rows.size() × cols.
##
## Character → TileType mapping:
##   '#' = 1 (SOLID)    'D' = 2 (DIRT_SLOW)  'F' = 3 (DIRT_FAST)
##   'L' = 4 (LADDER)   'R' = 5 (ROPE)       _   = 0 (EMPTY)
static func _map_from_ascii(rows: Array[String], cols: int) -> PackedInt32Array:
	var map := PackedInt32Array()
	map.resize(rows.size() * cols)
	for r: int in rows.size():
		var row_str: String = rows[r]
		for c: int in cols:
			var ch: String = row_str[c] if c < row_str.length() else " "
			map[r * cols + c] = _char_to_tile(ch)
	return map


## Map a single ASCII character to a TerrainSystem.TileType int value.
static func _char_to_tile(ch: String) -> int:
	match ch:
		"#": return 1  # SOLID
		"D": return 2  # DIRT_SLOW
		"F": return 3  # DIRT_FAST
		"L": return 4  # LADDER
		"R": return 5  # ROPE
		_:   return 0  # EMPTY — space, dot, or any other character
