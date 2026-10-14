import SwiftUI

public enum TaskEditorMode {
    case create
    case edit(EditableTaskTarget)
}

public struct TaskEditorView: View {
    public var store: DashboardStore
    public let mode: TaskEditorMode
    @Environment(\.scaleFactor) private var s

    @State private var title: String = ""
    @State private var selectedTag: String = ""
    @State private var isCreatingCustomTag: Bool = false
    @State private var customTagText: String = ""
    @State private var isOneTime: Bool = false
    @State private var repeatCount: Int = 1
    @State private var repeatUnit: CadenceUnit = .month
    @State private var durationMinutes: Int = 15
    @State private var selectedState: TaskHealthState = .good

    public init(store: DashboardStore, mode: TaskEditorMode) {
        self.store = store
        self.mode = mode
    }

    private var effectiveTag: String {
        if isCreatingCustomTag {
            return customTagText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }
        return selectedTag.uppercased()
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !effectiveTag.isEmpty
    }

    private var routingInfo: (icon: String, text: String, isImmediate: Bool) {
        if isOneTime {
            switch selectedState {
            case .due, .overdue:
                return ("bolt.fill", "Immediate action: Added to Today's Focus Queue.", true)
            case .good, .notYet:
                return ("calendar", "Scheduled execution: Placed in Upcoming Horizon (In 3 Days).", false)
            }
        }

        let intervalDays = repeatUnit.days(count: repeatCount)
        switch selectedState {
        case .overdue:
            return ("exclamationmark.triangle.fill", "Overdue hazard: Assigned high priority on Active Focus.", true)
        case .due:
            if repeatUnit == .day && repeatCount == 1 {
                return ("checklist", "Daily routine: Assigned to Daily Baseline (\(durationMinutes) min).", true)
            }
            return ("bolt.fill", "Due today: Active on Today's Focus Queue.", true)
        case .notYet:
            let daysLeft = max(1, intervalDays / 2)
            return ("clock", "In progress: Estimated due in ~\(daysLeft) days (Upcoming Horizon).", false)
        case .good:
            return ("checkmark.circle", "Cycle fresh: Next due in \(intervalDays) days (Upcoming Horizon).", false)
        }
    }

    private func confirmCustomTag() {
        let trimmed = customTagText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        store.addCustomTag(trimmed)
        selectedTag = trimmed
        customTagText = ""
        isCreatingCustomTag = false
    }

    private func commit() {
        guard isValid else { return }
        if isCreatingCustomTag && !customTagText.isEmpty {
            confirmCustomTag()
        }

        switch mode {
        case .create:
            store.dispatchConfiguredTask(
                title: title,
                tag: effectiveTag,
                durationMinutes: durationMinutes,
                isOneTime: isOneTime,
                repeatCount: repeatCount,
                repeatUnit: repeatUnit,
                healthState: selectedState
            )
            cancelOut()
        case .edit(let target):
            store.applyEditedTask(
                target: target,
                title: title,
                tag: effectiveTag,
                durationMinutes: durationMinutes,
                isOneTime: isOneTime,
                repeatCount: repeatCount,
                repeatUnit: repeatUnit,
                healthState: selectedState
            )
        }
    }

    private func cancelOut() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            switch mode {
            case .create: store.dismissCreateTask()
            case .edit:   store.dismissEditTask()
            }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16 * s) {
            // 1. Task Title
            VStack(alignment: .leading, spacing: 6 * s) {
                Text("TASK IDENTIFIER")
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(1.4 * s)
                    .foregroundColor(AppConfig.Colors.subtextGrey)

                TextField("e.g. Sanitize ice machine coils", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13 * s, weight: .semibold))
                    .padding(.horizontal, 12 * s)
                    .padding(.vertical, 10 * s)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6 * s))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6 * s)
                            .strokeBorder(Color.black.opacity(0.18), lineWidth: 1 * s)
                    )
            }

            // 2. System Tag Registry
            VStack(alignment: .leading, spacing: 6 * s) {
                Text("SYSTEM TAG")
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(1.4 * s)
                    .foregroundColor(AppConfig.Colors.subtextGrey)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 72 * s), spacing: 6 * s)],
                    spacing: 6 * s
                ) {
                    ForEach(store.availableTags, id: \.self) { tag in
                        let isSelected = !isCreatingCustomTag && selectedTag == tag
                        ZStack {
                            RoundedRectangle(cornerRadius: 5 * s)
                                .fill(isSelected ? Color.black : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5 * s)
                                        .strokeBorder(isSelected ? Color.black : Color.black.opacity(0.15), lineWidth: 1 * s)
                                )

                            Text(tag)
                                .font(.system(size: 9.5 * s, weight: .bold))
                                .tracking(0.8 * s)
                                .lineLimit(1)
                                .foregroundColor(isSelected ? .white : Color.black)
                                .padding(.horizontal, 4 * s)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 28 * s)
                        .contentShape(RoundedRectangle(cornerRadius: 5 * s))
                        .onTapGesture {
                            isCreatingCustomTag = false
                            selectedTag = tag
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteTag(tag)
                                if selectedTag == tag {
                                    selectedTag = store.availableTags.first ?? "GENERAL"
                                }
                            } label: {
                                Label("Delete Tag \"\(tag)\"", systemImage: "trash")
                            }
                        }
                    }

                    // Add Custom Tag Trigger
                    ZStack {
                        RoundedRectangle(cornerRadius: 5 * s)
                            .fill(isCreatingCustomTag ? Color.black : Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5 * s)
                                    .strokeBorder(isCreatingCustomTag ? Color.black : Color.black.opacity(0.2), lineWidth: 1 * s)
                            )

                        HStack(spacing: 3 * s) {
                            Image(systemName: "plus")
                                .font(.system(size: 8 * s, weight: .black))
                            Text("CUSTOM")
                                .font(.system(size: 9.5 * s, weight: .bold))
                                .tracking(0.8 * s)
                        }
                        .foregroundColor(isCreatingCustomTag ? .white : Color.black)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 28 * s)
                    .contentShape(RoundedRectangle(cornerRadius: 5 * s))
                    .onTapGesture {
                        isCreatingCustomTag = true
                    }
                }

                if isCreatingCustomTag {
                    HStack(spacing: 6 * s) {
                        TextField("ENTER NEW TAG (e.g. HVAC)", text: $customTagText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11 * s, weight: .bold))
                            .padding(.horizontal, 10 * s)
                            .padding(.vertical, 8 * s)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 5 * s))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5 * s)
                                    .strokeBorder(Color.black, lineWidth: 1.2 * s)
                            )
                            .onSubmit { confirmCustomTag() }

                        Button(action: confirmCustomTag) {
                            Text("ADD")
                                .font(.system(size: 10 * s, weight: .black))
                                .tracking(1.0 * s)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12 * s)
                                .frame(height: 33 * s)
                                .background(customTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.black.opacity(0.3) : Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 5 * s))
                        }
                        .buttonStyle(.plain)
                        .disabled(customTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button(action: {
                            isCreatingCustomTag = false
                            customTagText = ""
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11 * s, weight: .bold))
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                                .frame(width: 28 * s, height: 33 * s)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4 * s)
                }
            }

            // 3. Recurrence Cadence
            VStack(alignment: .leading, spacing: 8 * s) {
                HStack {
                    Text("RECURRENCE CADENCE")
                        .font(.system(size: 10 * s, weight: .bold))
                        .tracking(1.4 * s)
                        .foregroundColor(AppConfig.Colors.subtextGrey)

                    Spacer()

                    HStack(spacing: 2 * s) {
                        CadenceTypeTab(title: "RECURRING", isSelected: !isOneTime, s: s) { isOneTime = false }
                        CadenceTypeTab(title: "ONE-TIME", isSelected: isOneTime, s: s) { isOneTime = true }
                    }
                    .padding(2 * s)
                    .background(Color.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6 * s))
                }

                if !isOneTime {
                    HStack(spacing: 10 * s) {
                        HStack(spacing: 0) {
                            Button(action: { if repeatCount > 1 { repeatCount -= 1 } }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 11 * s, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 36 * s, height: 42 * s)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(SubtlePressStyle())

                            Divider().frame(height: 20 * s)

                            Text("\(repeatCount)")
                                .font(.system(size: 18 * s, weight: .black, design: .monospaced))
                                .frame(maxWidth: .infinity)

                            Divider().frame(height: 20 * s)

                            Button(action: { repeatCount += 1 }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11 * s, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 36 * s, height: 42 * s)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(SubtlePressStyle())
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 7 * s))
                        .overlay(RoundedRectangle(cornerRadius: 7 * s).strokeBorder(Color.black.opacity(0.15), lineWidth: 1 * s))

                        HStack(spacing: 0) {
                            Button(action: { repeatUnit = repeatUnit.previous() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11 * s, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 34 * s, height: 42 * s)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(SubtlePressStyle())

                            Divider().frame(height: 20 * s)

                            Text(repeatUnit.displayString(count: repeatCount).uppercased())
                                .font(.system(size: 12 * s, weight: .bold))
                                .tracking(0.6 * s)
                                .frame(maxWidth: .infinity)

                            Divider().frame(height: 20 * s)

                            Button(action: { repeatUnit = repeatUnit.next() }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11 * s, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 34 * s, height: 42 * s)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(SubtlePressStyle())
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 7 * s))
                        .overlay(RoundedRectangle(cornerRadius: 7 * s).strokeBorder(Color.black.opacity(0.15), lineWidth: 1 * s))
                    }

                    if repeatUnit == .day && repeatCount == 1 {
                        HStack {
                            Text("DAILY DURATION")
                                .font(.system(size: 10 * s, weight: .bold))
                                .tracking(1.4 * s)
                                .foregroundColor(AppConfig.Colors.subtextGrey)

                            Spacer()

                            HStack(spacing: 0) {
                                Button(action: { if durationMinutes > 5 { durationMinutes -= 5 } }) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 10 * s, weight: .bold))
                                        .frame(width: 28 * s, height: 30 * s)
                                }
                                .buttonStyle(SubtlePressStyle())

                                Text("\(durationMinutes) MIN")
                                    .font(.system(size: 11 * s, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6 * s)

                                Button(action: { durationMinutes += 5 }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10 * s, weight: .bold))
                                        .frame(width: 28 * s, height: 30 * s)
                                }
                                .buttonStyle(SubtlePressStyle())
                            }
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 5 * s))
                            .overlay(RoundedRectangle(cornerRadius: 5 * s).strokeBorder(Color.black.opacity(0.15), lineWidth: 1 * s))
                        }
                        .padding(.top, 4 * s)
                    }
                } else {
                    HStack(spacing: 6 * s) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10 * s))
                            .foregroundColor(AppConfig.Colors.subtextGrey)
                        Text("Task will execute once without recurring horizon intervals.")
                            .font(.system(size: 11 * s, weight: .medium))
                            .foregroundColor(AppConfig.Colors.subtextGrey)
                    }
                    .padding(.horizontal, 12 * s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 42 * s)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7 * s))
                    .overlay(RoundedRectangle(cornerRadius: 7 * s).strokeBorder(Color.black.opacity(0.12), lineWidth: 1 * s))
                }
            }

            // 4. Current Status & Runway Gauge
            VStack(alignment: .leading, spacing: 8 * s) {
                Text("CURRENT OPERATIONAL STATUS")
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(1.4 * s)
                    .foregroundColor(AppConfig.Colors.subtextGrey)

                HStack(spacing: 5 * s) {
                    ForEach(TaskHealthState.allCases, id: \.self) { state in
                        let isSelected = selectedState == state
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedState = state
                            }
                        }) {
                            VStack(spacing: 2 * s) {
                                Text(state.rawValue)
                                    .font(.system(size: 10 * s, weight: .black))
                                    .tracking(0.5 * s)
                                Text(state.subtitle)
                                    .font(.system(size: 7.5 * s, weight: .bold))
                                    .opacity(isSelected ? 0.75 : 0.6)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 40 * s)
                            .background(isSelected ? (state == .overdue ? Color.red : Color.black) : Color.white)
                            .foregroundColor(isSelected ? .white : Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 6 * s))
                            .overlay(RoundedRectangle(cornerRadius: 6 * s).strokeBorder(isSelected ? Color.clear : Color.black.opacity(0.15), lineWidth: 1 * s))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HealthRunwayGauge(state: selectedState, s: s)

                HStack(alignment: .center, spacing: 8 * s) {
                    Image(systemName: routingInfo.icon)
                        .font(.system(size: 11 * s, weight: .bold))
                        .foregroundColor(routingInfo.isImmediate ? (selectedState == .overdue ? .red : Color.black) : AppConfig.Colors.subtextGrey)

                    Text(routingInfo.text)
                        .font(.system(size: 10.5 * s, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.85))
                        .lineLimit(2)
                }
                .padding(.horizontal, 10 * s)
                .padding(.vertical, 8 * s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6 * s))
            }

            // 5. Execution Dock
            VStack(spacing: 8 * s) {
                Button(action: commit) {
                    HStack(spacing: 6 * s) {
                        Image(systemName: isEditMode ? "checkmark" : "plus")
                            .font(.system(size: 10 * s, weight: .black))
                        Text(isEditMode ? "SAVE MODIFICATIONS" : "DISPATCH TASK TO BOARD")
                            .font(.system(size: 11 * s, weight: .bold))
                            .tracking(1.4 * s)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42 * s)
                    .background(isValid ? Color.black : Color.black.opacity(0.25))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6 * s))
                }
                .disabled(!isValid)
                .buttonStyle(.plain)

                Button(action: cancelOut) {
                    Text("CANCEL")
                        .font(.system(size: 10 * s, weight: .bold))
                        .tracking(1.2 * s)
                        .foregroundColor(AppConfig.Colors.subtextGrey)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32 * s)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])

                if case .edit(let target) = mode {
                    Button(action: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            store.deleteTask(target: target)
                        }
                    }) {
                        HStack(spacing: 4 * s) {
                            Image(systemName: "trash")
                                .font(.system(size: 10 * s))
                            Text("DELETE TASK")
                                .font(.system(size: 9.5 * s, weight: .bold))
                                .tracking(1.0 * s)
                        }
                        .foregroundColor(Color.red.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28 * s)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2 * s)
                }
            }
            .padding(.top, 4 * s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onExitCommand(perform: cancelOut)
        .onAppear {
            seedInitialValues()
        }
    }

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func seedInitialValues() {
        switch mode {
        case .create:
            if selectedTag.isEmpty, let firstTag = store.availableTags.first {
                selectedTag = firstTag
            }
        case .edit(let target):
            switch target {
            case .focus(let job):
                title = job.title
                selectedTag = job.tag.uppercased()
                durationMinutes = 15
                isOneTime = false
                repeatCount = 1
                repeatUnit = .week
                selectedState = job.isOverdue ? .overdue : (job.isCompleted ? .good : .due)
            case .baseline(let task):
                title = task.title
                selectedTag = task.tag.uppercased()
                durationMinutes = task.durationMinutes
                isOneTime = false
                repeatCount = 1
                repeatUnit = .day
                selectedState = task.isCompleted ? .good : .due
            case .horizon(let event):
                title = event.title
                selectedTag = event.tag.uppercased()
                durationMinutes = 15
                isOneTime = false
                repeatCount = event.repeatCount
                repeatUnit = event.repeatUnit
                selectedState = event.healthState
            }
        }
    }
}

// MARK: - Runway Gauge & Reusable Button Styles
public struct HealthRunwayGauge: View {
    public let state: TaskHealthState
    public let s: CGFloat

    public init(state: TaskHealthState, s: CGFloat) {
        self.state = state
        self.s = s
    }

    private var filledSegments: Int {
        switch state {
        case .good:    return 4
        case .notYet:  return 3
        case .due:     return 1
        case .overdue: return 0
        }
    }

    private var stateColor: Color {
        switch state {
        case .good:    return Color(red: 16/255, green: 185/255, blue: 129/255)
        case .notYet:  return Color(red: 234/255, green: 179/255, blue: 8/255)
        case .due:     return Color(red: 249/255, green: 115/255, blue: 22/255)
        case .overdue: return Color(red: 239/255, green: 68/255, blue: 68/255)
        }
    }

    private var runwayLabel: String {
        switch state {
        case .good:    return "RUNWAY: 100% (HEALTHY BUFFER)"
        case .notYet:  return "RUNWAY: 75% (MID-CYCLE RUNNING)"
        case .due:     return "RUNWAY: 25% (CYCLE EXHAUSTED)"
        case .overdue: return "RUNWAY: 0% (DECAY HAZARD)"
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5 * s) {
            HStack {
                Text(runwayLabel)
                    .font(.system(size: 8.5 * s, weight: .black, design: .monospaced))
                    .tracking(0.8 * s)
                    .foregroundColor(stateColor)

                Spacer()

                if state == .overdue {
                    HStack(spacing: 3 * s) {
                        Image(systemName: "radiation")
                            .font(.system(size: 11 * s, weight: .black))
                            .foregroundColor(stateColor)
                        Text("DECAY HAZARD")
                            .font(.system(size: 8 * s, weight: .black))
                            .foregroundColor(stateColor)
                    }
                }
            }

            HStack(spacing: 3 * s) {
                ForEach(0..<4, id: \.self) { index in
                    let isFilled = index < filledSegments
                    RoundedRectangle(cornerRadius: 1.5 * s)
                        .fill(isFilled ? stateColor : stateColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 1.5 * s)
                                .strokeBorder(isFilled ? stateColor.opacity(0.4) : Color.clear, lineWidth: 0.5 * s)
                        )
                }
            }
            .padding(3.5 * s)
            .frame(height: 18 * s)
            .background(stateColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 4 * s))
            .overlay(
                RoundedRectangle(cornerRadius: 4 * s)
                    .strokeBorder(stateColor.opacity(0.75), lineWidth: 1.5 * s)
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: state)
        }
        .padding(.vertical, 2 * s)
    }
}

public struct CadenceTypeTab: View {
    let title: String
    let isSelected: Bool
    let s: CGFloat
    let action: () -> Void

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 8.5 * s, weight: isSelected ? .black : .bold))
                .tracking(0.6 * s)
                .padding(.horizontal, 8 * s)
                .padding(.vertical, 4 * s)
                .background(isSelected ? Color.white : Color.clear)
                .foregroundColor(isSelected ? .black : AppConfig.Colors.subtextGrey)
                .clipShape(RoundedRectangle(cornerRadius: 4 * s))
                .shadow(color: isSelected ? Color.black.opacity(0.08) : Color.clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

public struct SubtlePressStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.06) : Color.clear)
    }
}