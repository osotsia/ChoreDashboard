import Testing
import Foundation
@testable import ChoreDashboard

@Suite("DashboardStore Presentation & Coordination Tests")
@MainActor
struct DashboardStoreTests {

    private func makeStore(tasks: [TaskItem] = []) -> (DashboardStore, InMemoryPersistenceClient, TestClock) {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1777636800))
        let mockStorage = InMemoryPersistenceClient(initialState: DashboardState(tasks: tasks))
        let store = DashboardStore(
            initialState: DashboardState(tasks: tasks),
            persistenceClient: mockStorage,
            clock: clock,
            enableSystemIntegration: false
        )
        return (store, mockStorage, clock)
    }

    @Test("selectRightTab manages active and previous tab transitions")
    func testTabNavigation() {
        let (store, _, _) = makeStore()

        #expect(store.activeRightTab == .status)
        #expect(store.previousRightTab == .status)

        store.selectRightTab(.backlog)
        #expect(store.activeRightTab == .backlog)
        #expect(store.previousRightTab == .status)

        store.selectRightTab(.history)
        #expect(store.activeRightTab == .history)
        #expect(store.previousRightTab == .backlog)
    }

    @Test("startCreatingTask initializes draft and routes to .create tab")
    func testStartCreatingTask() {
        let (store, _, _) = makeStore()

        store.selectRightTab(.backlog)
        store.startCreatingTask()

        #expect(store.activeRightTab == .create)
        #expect(store.previousRightTab == .backlog)
        #expect(store.taskDraft != nil)
        #expect(store.taskDraft?.isNew == true)
    }

    @Test("dismissDraft clears draft and restores previous navigation tab")
    func testDismissDraft() {
        let (store, _, _) = makeStore()

        store.selectRightTab(.history)
        store.startCreatingTask()
        #expect(store.activeRightTab == .create)

        store.dismissDraft()
        #expect(store.activeRightTab == .history)
        #expect(store.taskDraft == nil)
    }

    @Test("commitDraft inserts task into state and dismisses form")
    func testCommitDraft() {
        let (store, _, _) = makeStore()

        store.startCreatingTask()
        store.taskDraft?.title = "Sanitize Shelves"
        store.taskDraft?.tag = "KITCHEN"

        store.commitDraft()

        #expect(store.state.tasks.count == 1)
        #expect(store.state.tasks[0].title == "Sanitize Shelves")
        #expect(store.state.tasks[0].tag == "KITCHEN")
        #expect(store.taskDraft == nil)
        #expect(store.activeRightTab == .status)
    }

    @Test("deleteTask removes task and dismisses editing form")
    func testDeleteTaskFromEdit() {
        let taskId = UUID()
        let task = TaskItem(id: taskId, title: "Dust Fans", tag: "GENERAL")
        let (store, _, _) = makeStore(tasks: [task])

        store.startEditing(task: task)
        #expect(store.activeRightTab == .edit)

        store.deleteTask(id: taskId)

        #expect(store.state.tasks.isEmpty)
        #expect(store.taskDraft == nil)
        #expect(store.activeRightTab == .status)
    }
}