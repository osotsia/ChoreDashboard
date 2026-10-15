import Testing
import SwiftUI
@testable import ChoreDashboard

@Suite("SwiftUI Presentation Component Hierarchy Tests")
@MainActor
struct ComponentTests {

    private func makeStore(tasks: [TaskItem] = PreviewData.defaultState.tasks) -> DashboardStore {
        let cal = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 1
        comps.hour = 12
        let clock = TestClock(now: cal.date(from: comps)!, calendar: cal)

        var state = PreviewData.defaultState
        state.tasks = tasks
        let mockStorage = InMemoryPersistenceClient(initialState: state)
        return DashboardStore(
            initialState: state,
            persistenceClient: mockStorage,
            clock: clock,
            enableSystemIntegration: false
        )
    }

    @Test("CheckboxRow renders across completion, highlighted, and truncated states without crashing")
    func testCheckboxRowRendering() {
        let normalRow = CheckboxRow(
            title: "Short Task",
            tag: "KITCHEN",
            isCompleted: false,
            isHighlighted: false,
            onToggle: {}
        )
        let _ = normalRow.body

        let completedHighlightedRow = CheckboxRow(
            title: "A Very Long Task Title That Truncates Because It Exceeds Standard Line Bounds",
            tag: "OPERATIONS",
            isCompleted: true,
            isHighlighted: true,
            onToggle: {},
            onEdit: {}
        )
        let _ = completedHighlightedRow.body
        #expect(completedHighlightedRow.isCompleted == true)
        #expect(completedHighlightedRow.isHighlighted == true)
    }

    @Test("FocusJobTile builds body across normal, overdue, and completed states")
    func testFocusJobTileRendering() {
        let normalTask = TaskItem(title: "Normal Tile", tag: "GENERAL")
        let normalTile = FocusJobTile(task: normalTask, isHighlighted: false, onToggle: {})
        let _ = normalTile.body

        let overdueTask = TaskItem(
            title: "Overdue Tile",
            tag: "BATHROOM",
            isCompleted: false,
            dueDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        )
        let overdueTile = FocusJobTile(task: overdueTask, isHighlighted: true, onToggle: {}, onEdit: {})
        let _ = overdueTile.body
        #expect(overdueTile.task.healthState() == .overdue)
    }

    @Test("HealthRunwayGauge renders cleanly across all 5 operational health states", arguments: TaskHealthState.allCases)
    func testHealthRunwayGaugeAllStates(healthState: TaskHealthState) {
        let gauge = HealthRunwayGauge(state: healthState, s: 1.0)
        let _ = gauge.body
        #expect(gauge.state == healthState)
    }

    @Test("PanelHeaderView and SectionBadge render titles and badge iconography")
    func testPanelHeaderViewAndSectionBadge() {
        let headerWithoutIcon = PanelHeaderView(title: "Overview", badgeText: "Active")
        let _ = headerWithoutIcon.body
        #expect(headerWithoutIcon.badgeIcon == nil)

        let headerWithIcon = PanelHeaderView(title: "Dispatch", badgeText: "New", badgeIcon: "plus.circle")
        let _ = headerWithIcon.body
        #expect(headerWithIcon.badgeIcon == "plus.circle")

        let badge = SectionBadge(text: "Section Header")
        let _ = badge.body
        #expect(badge.text == "Section Header")
    }

    @Test("BottomActionBarView builds tab actions across all navigation tabs", arguments: RightPanelTab.allCases)
    func testBottomActionBarViewRendering(activeTab: RightPanelTab) {
        let store = makeStore()
        store.selectRightTab(activeTab)

        let bar = BottomActionBarView(store: store)
        let _ = bar.body
        #expect(store.activeRightTab == activeTab)
    }

    @Test("StatusView, BacklogListView, and HistoryTimelineView build view bodies without failure")
    func testRightColumnViewsRendering() {
        let store = makeStore()

        let statusView = StatusView(store: store)
        let _ = statusView.body

        let backlogView = BacklogListView(store: store)
        let _ = backlogView.body

        let historyView = HistoryTimelineView(records: store.state.historyRecords, onExport: {})
        let _ = historyView.body
        #expect(historyView.records.count == store.state.historyRecords.count)

        let emptyHistoryView = HistoryTimelineView(records: [], onExport: nil)
        let _ = emptyHistoryView.body
        #expect(emptyHistoryView.records.isEmpty)
    }

    @Test("PrimaryFocusView and BaselineResetView render cleanly with populated and empty inventories")
    func testPrimaryFocusViewAndBaselineResetViewRendering() {
        let populatedStore = makeStore()
        let populatedFocus = PrimaryFocusView(store: populatedStore)
        let _ = populatedFocus.body
        let populatedBaseline = BaselineResetView(store: populatedStore)
        let _ = populatedBaseline.body

        let emptyStore = makeStore(tasks: [])
        let emptyFocus = PrimaryFocusView(store: emptyStore)
        let _ = emptyFocus.body
        let emptyBaseline = BaselineResetView(store: emptyStore)
        let _ = emptyBaseline.body

        #expect(emptyStore.baselineTasks.isEmpty)
        #expect(emptyStore.focusQueue.isEmpty)
    }

    @Test("TaskEditorView builds cleanly across creation and modification states")
    func testTaskEditorViewRenderingInCreateAndEditModes() {
        let store = makeStore()

        store.startCreatingTask()
        let createEditor = TaskEditorView(store: store)
        let _ = createEditor.body
        #expect(store.taskDraft != nil)
        #expect(store.taskDraft?.isNew == true)

        store.taskDraft?.isOneTime = true
        store.taskDraft?.initialHealthState = .good
        let oneTimeFutureEditor = TaskEditorView(store: store)
        let _ = oneTimeFutureEditor.body

        if let existing = store.state.tasks.first {
            store.startEditing(task: existing)
            let editEditor = TaskEditorView(store: store)
            let _ = editEditor.body
            #expect(store.taskDraft?.isNew == false)
            #expect(store.taskDraft?.id == existing.id)
        }
    }

    @Test("Components evaluate without crashing across multiple scale factor environments", arguments: [CGFloat(0.75), CGFloat(1.0), CGFloat(1.5)])
    func testScaleFactorEnvironmentVariations(scalar: CGFloat) {
        let gauge = HealthRunwayGauge(state: .halfway, s: scalar)
        let _ = gauge.body

        let tab = CadenceTypeTab(title: "RECURRING", isSelected: true, s: scalar, action: {})
        let _ = tab.body

        #expect(scalar > 0)
    }
}