# Project Architecture & Structure: `ChoreDashboard`

### **Core Principles Embodied in This Structure**

*   **Architecture Pattern:** A strict **"Functional Core, Imperative Shell" (FCIS)** architecture with **Unidirectional Data Flow**.
    *   **Functional Core (`Domain/`):** Pure Swift data structures, deterministic state transition algorithms, and mathematical projections. Contains zero imports of `SwiftUI`, `AppKit`, or disk I/O frameworks. All time-sensitive operations are parameterized by an abstract `Clock`, enabling deterministic testing without system-clock dependencies.
    *   **Imperative Shell - Storage (`Storage/`):** Isolates all asynchronous persistence, atomic file transactions, POSIX file-descriptor hooks (`DirectoryWatcher`), and cryptographic change detection (`SHA256`). Communicates with the core strictly through value-typed domain snapshots.
    *   **Imperative Shell - Presentation (`Presentation/` & `App/`):** SwiftUI view hierarchy and AppKit window wrappers. Driven by a lightweight coordinator (`DashboardStore`) that holds ephemeral UI form drafts (`TaskDraft`) and active tab routes (`NavigationTab`), delegating all mutations to `ChoreEngine` and all queries to `ChoreProjections`.
*   **Separation of Concerns:** Ephemeral UI inputs (e.g., active task edits, custom tag text fields) are decoupled from the persisted domain schema (`DashboardState`), preventing partial form inputs or navigation transitions from corrupting persistent state.
*   **Low Onboarding Cognitive Load:** Strict, predictable single-responsibility boundaries. Business rules reside exclusively in `Domain/Logic/`, persistence mechanics in `Storage/`, and layout primitives in `Presentation/`. No single file exceeds ~200 lines.

```text
┌───────────────────────────────────────────────────────────────────────────────────┐
│                                 IMPERATIVE SHELL                                  │
│                                                                                   │
│   ┌─────────────────────────────┐         ┌───────────────────────────────────┐   │
│   │     Presentation Layer      │         │   Storage & System Integration    │   │
│   │   - SwiftUI Views & Layouts │         │   - FilePersistenceClient (Actor) │   │
│   │   - AppKit Chrome & Menus   │         │   - DirectoryWatcher (POSIX I/O)  │   │
│   │   - UI State (Tabs, Drafts) │         │   - Timer & OS Notifications      │   │
│   └──────────────┬──────────────┘         └─────────────────┬─────────────────┘   │
│                  │                                          │                     │
│                  │       ┌──────────────────────────┐       │                     │
│                  └──────►│      DashboardStore      │◄──────┘                     │
│                          │ (Observable Coordinator) │                             │
│                          └────────────┬─────────────┘                             │
└───────────────────────────────────────┼───────────────────────────────────────────┘
                                        │ Dispatches (inout State, Clock)
                                        │ Reads Invariant Projections
                                        ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│                       FUNCTIONAL CORE (Zero I/O, Pure Swift)                      │
│                                                                                   │
│   ┌───────────────────────────────────┐   ┌───────────────────────────────────┐   │
│   │            ChoreEngine            │   │         ChoreProjections          │   │
│   │   - (inout State, Clock) -> Bool  │   │   - (State, Clock) -> Snapshot    │   │
│   │   - Rollover, Toggle, Complete    │   │   - Queues, Pacing, Clearance     │   │
│   └─────────────────┬─────────────────┘   └─────────────────┬─────────────────┘   │
│                     │                                       │                     │
│                     ▼                                       ▼                     │
│   ┌───────────────────────────────────────────────────────────────────────────┐   │
│   │                               Domain Models                               │   │
│   │   - DashboardState (Codable Schema)   - Clock Protocol (System/Test)      │   │
│   │   - TaskItem & RecurrenceRule         - TaskHealthState (5-Tier Runway)   │   │
│   └───────────────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────────────┘
```

---

### **Execution Pipeline: 4-Stage Data Flow**

Every state modification and query follows a strict unidirectional lifecycle:

```text
 [1. INTENT CAPTURE]
  User Action / Form Edit ──► [TaskDraft (Ephemeral Form State)]
                                        │
                                        ▼ (Commit / Toggle)
                              [DashboardStore (Coordinator)]
                                        │
            ┌───────────────────────────┴───────────────────────────┐
            │ [2. FUNCTIONAL CORE]                                  │ [3. TELEMETRY QUERIES]
            │ Dispatches (inout State, Clock)                       │ Evaluates (State, Clock)
            ▼                                                       ▼
  [ChoreEngine (Pure Mutations)]                               [ChoreProjections]
   ├── Rollovers (Midnight crossing)                            ├── focusQueue (Today / Overdue)
   ├── Completions & History logs                               ├── baselineTasks (24h routines)
   └── Cascading tag cleanups                                   └── monthlyPacing (Velocity / Lead)
            │                                                       │
            ▼                                                       ▼
   (Updated DashboardState)                                    (@Observable Publish)
            │                                                       │
            ▼ [4. ASYNC PERSISTENCE]                                ▼
  [FilePersistenceClient (Actor)]                             [SwiftUI Views (Left/Right Decks)]
   ├── 120ms Debounced Queue                                   ├── PrimaryFocusView
   ├── ISO-8601 JSON Serializer                                ├── BaselineResetView
   └── Atomic Write + SHA-256 Digest                           └── StatusView / BacklogListView
            │                                                               ▲
            ▼                                                               │
   [state.json on Disk] ──► [DirectoryWatcher (POSIX)] ──(SHA-256 Diff)─────┘ (Hot Reload)
```

#### **Stage-by-Stage Breakdown**

**Stage 1: Intent Capture & Ephemeral UI Isolation (Presentation)**
*   **Elements:** `Presentation/State/TaskDraft.swift`, `Presentation/State/NavigationTab.swift`, and `Presentation/RightColumn/TaskEditorView.swift`.
*   **Mechanism:** User inputs, cadence adjustments, and tag configurations are isolated within value-typed `TaskDraft` instances. No mutations reach `DashboardState` during interactive entry. Canceling or switching tabs purges the draft and restores `previousRightTab`.
*   **Invariant:** Ephemeral UI churn cannot contaminate domain models or trigger premature disk serialization.

**Stage 2: Deterministic Functional Transitions & Invariants (Domain Core)**
*   **Elements:** `Domain/Logic/ChoreEngine.swift`, `Domain/Clock.swift`, and `Domain/Models/TaskItem.swift`.
*   **Mechanism:** `DashboardStore` forwards mutations to pure static methods on `ChoreEngine`, passing `(inout DashboardState, Clock)`. Transitions evaluate all calendar boundaries against `clock.now` and `clock.calendar` rather than system wall-clock time.
*   **Invariant:** Business rules have zero dependencies on SwiftUI, AppKit, or filesystem APIs. Rollovers, completions, and tag fallbacks execute deterministically in microseconds under `TestClock`.

**Stage 3: Pure Projection Synthesis & Telemetry Calculations (Domain Queries)**
*   **Elements:** `Domain/Logic/ChoreProjections.swift`.
*   **Mechanism:** Views never perform ad-hoc task filtering or progress arithmetic. `ChoreProjections` consumes an immutable `(DashboardState, Clock)` snapshot to compute derived queries (`focusQueue`, `baselineTasks`, `upcomingEvents`) and operational telemetry (`todaySnapshot`, `monthlyPacing`) via pure mathematical transforms.
*   **Invariant:** Complete mathematical disjointness across active operational queues:
    $$\text{focusQueue} \cap \text{baselineTasks} = \emptyset, \quad \text{focusQueue} \cap \text{upcomingEvents} = \emptyset$$

**Stage 4: Actor-Isolated Persistence & Cryptographic File Watching (Storage)**
*   **Elements:** `Storage/FilePersistenceClient.swift` and `Storage/DirectoryWatcher.swift`.
*   **Mechanism:** State mutations dispatch a 120ms debounced write to the `FilePersistenceClient` actor, which serializes the payload to atomic storage and records its SHA-256 digest. Concurrently, `DirectoryWatcher` monitors `state.json` via a POSIX `DispatchSourceFileSystemObject`. When external changes occur, `evaluateExternalChange()` validates the checksum before decoding.
*   **Invariant:** Offloads all disk I/O from the main thread. Atomic writes protect against process termination faults, while SHA-256 digest comparisons prevent write-and-watch feedback loops.

---

### **Project Structure: `ChoreDashboard/`**

```text
ChoreDashboard/
├── Package.swift                           # SPM manifest: defines executable & test targets (.macOS v14).
├── compile.sh                              # Standalone release compilation and .app bundle packager.
│
├── Sources/
│   ├── App/                                # --- SYSTEM INTEGRATION & ENTRY POINT ---
│   │   ├── ChoreDashboardApp.swift         # Declarative App scene, window bounds, and MenuBarExtra.
│   │   ├── AppConfig.swift                 # Central design tokens, 65/35 split geometry, and file URLs.
│   │   └── AspectLockView.swift            # AppKit NSViewRepresentable locking window aspect ratio.
│   │
│   ├── Domain/                             # --- FUNCTIONAL CORE (PURE SWIFT) ---
│   │   ├── Clock.swift                     # Clock protocol, SystemClock, and deterministic TestClock.
│   │   │
│   │   ├── Models/                         # Ground-truth entity definitions and codable schemas.
│   │   │   ├── TaskItem.swift              # Unified chore item (title, recurrence, cadence, due dates).
│   │   │   ├── TaskHealthState.swift       # 5-tier operational runway enum (GOOD, NOT YET, HALF, DUE, OVERDUE).
│   │   │   ├── HistoryRecord.swift         # Immutable historical completion entry with timestamps.
│   │   │   └── DashboardState.swift        # Root persistent document schema with Schema V1->V2 migration.
│   │   │
│   │   ├── Logic/                          # Pure business rules (zero external dependencies).
│   │   │   ├── ChoreEngine.swift           # State transitions (toggle, complete, rollover, upsert, delete).
│   │   │   └── ChoreProjections.swift      # Pure queries (focusQueue, todaySnapshot, monthlyPacing).
│   │   │
│   │   └── Seeds/
│   │       └── PreviewData.swift           # Ground-truth seed data for previews and default fallback.
│   │
│   ├── Storage/                            # --- PERSISTENCE & FILE SYSTEM I/O ---
│   │   ├── PersistenceClient.swift         # Async contract protocol for load/save/evaluate operations.
│   │   ├── FilePersistenceClient.swift     # Actor executing atomic disk writes and SHA-256 diff checks.
│   │   └── DirectoryWatcher.swift          # DispatchSource POSIX file-system descriptor observer.
│   │
│   └── Presentation/                       # --- IMPERATIVE SHELL (VIEWS & UI STATE) ---
│       ├── DashboardStore.swift            # Thin @Observable coordinator wiring Domain, Storage, and UI.
│       ├── DashboardView.swift             # Root 65/35 dual-column layout container with scaling scalar.
│       │
│       ├── State/                          # Transient form and navigation state.
│       │   ├── NavigationTab.swift         # RightPanelTab enum (status, backlog, history, create, edit).
│       │   └── TaskDraft.swift             # Ephemeral form model isolating live task editing from disk.
│       │
│       ├── Components/                     # Reusable Swiss-style tactile design components.
│       │   ├── CheckboxRow.swift           # High-visibility row with square checkbox and priority tags.
│       │   ├── FocusJobTile.swift          # Grid card component with inline overdue hazard warnings.
│       │   ├── HealthRunwayGauge.swift     # 4-segment operational buffer indicator with hazard alerts.
│       │   ├── PanelHeaderView.swift       # Monospaced section headers with tracking and action badges.
│       │   └── SectionBadge.swift          # Scaled typography badge primitives.
│       │
│       ├── LeftColumn/                     # 65% Dark Operational Focus Zones.
│       │   ├── PrimaryFocusView.swift      # Active operations grid (tasks due today or overdue).
│       │   └── BaselineResetView.swift     # Continuous 24-hour maintenance checklist and reset trigger.
│       │
│       └── RightColumn/                    # 35% Horizon, Status, and Inventory Deck.
│           ├── StatusView.swift            # Telemetry snapshot, monthly pacing velocity, and horizon queue.
│           ├── BacklogListView.swift       # Master item registry broken down into operational tiers.
│           ├── HistoryTimelineView.swift   # Chronological completion log grouped by day with JSON export.
│           ├── TaskEditorView.swift        # Task modification/creation form with cadence steppers.
│           └── BottomActionBarView.swift   # Primary dock switcher (NEW, STATUS, BACKLOG, HISTORY).
│
└── Tests/                                  # --- DETERMINISTIC TEST SUITE ---
    └── ChoreDashboardTests/
        ├── DomainTests/                    # Pure domain logic verification (Clock-driven).
        │   ├── TaskItemTests.swift         # Health runway heuristics and time anchor evaluations.
        │   ├── ChoreEngineTests.swift      # Task completions, deletions, and cascading tag cleanup.
        │   ├── RolloverTests.swift         # Midnight calendar crossings and cadence rollover checks.
        │   ├── ProjectionsTests.swift      # Partition disjointness, clearance rates, and monthly pacing.
        │   └── SystemInvariantTests.swift  # Idempotency, inventory conservation, and schema roundtrips.
        │
        ├── StorageTests/                   # I/O, atomicity, and serialization tests.
        │   └── PersistenceTests.swift      # Disk roundtrips, corrupted file handling, and SHA short-circuits.
        │
        ├── PresentationTests/              # UI coordination and workflow tests.
        │   └── DashboardStoreTests.swift   # Tab navigation, draft management, and cancel/commit lifecycles.
        │
        ├── TestDoubles/                    # Zero-I/O test doubles.
        │   └── InMemoryPersistenceClient.swift # In-memory storage mock tracking save calls without disk access.
        │
        └── ChoreDashboardTests.swift       # Smoke test for test target registration.
```

---

### **Architectural Invariants & Development Rules**

1. **Unidirectional Dependency Rules:**
   * `Domain` must **never** import `SwiftUI`, `AppKit`, `Storage`, or `Presentation`.
   * `Storage` depends only on `Domain/Models`. It has no reference to `Presentation` or UI state.
   * `Presentation` views receive data via `DashboardStore`. Views do not perform domain mutations directly.
2. **Deterministic Time Rules:**
   * Any function calculating dates, cadences, or relative time must accept a `Clock` or reference `Date` explicitly. Direct calls to `Date()` or `Calendar.current` inside domain logic are prohibited.
3. **Persistence Isolation Rules:**
   * All mutations to `DashboardState` occur in-memory first via `ChoreEngine`. Persistence to disk is debounced (120ms) and executed asynchronously via `FilePersistenceClient`.
   * Form inputs in `TaskEditorView` mutate an isolated `TaskDraft`. State reaches `DashboardState` only when explicitly committed via `ChoreEngine.upsertTask()`.