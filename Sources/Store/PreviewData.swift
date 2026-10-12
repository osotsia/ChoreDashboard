import Foundation

public enum PreviewData {
    public static let defaultState = DashboardState(
        heroTitle: "Deep Bathroom\nSanitize",
        heroSubtitle: "Est: 35 min · Descaling + Mechanical Grout Clean",
        heroTools: "TOOLS: Enzymatic agent, stiff bristle brush, microfiber cloths.",
        heroTasks: [
            ChoreItem(title: "Descale showerhead & clean door track", durationMinutes: 10, tag: "10m"),
            ChoreItem(title: "Disinfect toilet base, bowl & seals", durationMinutes: 10, tag: "10m"),
            ChoreItem(title: "Pull hair trap & flush drain with enzyme", durationMinutes: 5, tag: "05m"),
            ChoreItem(title: "Damp mop floor tiles to baseboard", durationMinutes: 10, tag: "10m")
        ],
        baselineTasks: [
            ChoreItem(title: "Sink empty & prep counters sanitized", durationMinutes: 3, tag: "Kitchen"),
            ChoreItem(title: "Stovetop wiped clean of oil spatter", durationMinutes: 3, tag: "Kitchen"),
            ChoreItem(title: "Squeegee shower walls & hang towels", durationMinutes: 2, tag: "Bathroom"),
            ChoreItem(title: "Wet waste / compost to exterior bin", durationMinutes: 2, tag: "General"),
            ChoreItem(title: "Clear active desk & flat work surfaces", durationMinutes: 5, tag: "Living")
        ],
        upcomingEvents: [
            HorizonEvent(tag: "Tomorrow · Tue, Oct 13", title: "Range Hood Degreasing & Stovetop", notes: "Soak mesh filters overnight; wipe cooktop backsplash.", timeAnchor: "Tomorrow"),
            HorizonEvent(tag: "Appointment · Thu, Oct 15", title: "Dentist: Exam & Prophylaxis Cleaning", notes: "Dr. Marcus, Midtown Dental · Suite 400.", timeAnchor: "09:30 AM"),
            HorizonEvent(tag: "Deep Clean · Sat, Oct 17", title: "Oven Interior & Racks (Steam Cycle)", notes: "Apply baking soda paste; wipe late afternoon. Heavy fumes.", timeAnchor: "Saturday"),
            HorizonEvent(tag: "Appliance · Sat, Oct 24", title: "Pull Refrigerator & Clean Coils", notes: "Vacuum rear condenser coils, clean floor under.", timeAnchor: "In 12 Days"),
            HorizonEvent(tag: "Facilities · Sun, Nov 01", title: "Replace HVAC Intake Filter (MERV 11)", notes: "Standard 30-day replacement. 2 backups in storage.", timeAnchor: "In 20 Days")
        ],
        telemetryMetrics: [
            TelemetryMetric(label: "HVAC intake", status: "24 / 30d"),
            TelemetryMetric(label: "Bed linens", status: "Due Wed"),
            TelemetryMetric(label: "Degreaser", status: "Low (Order)"),
            TelemetryMetric(label: "Dish tabs", status: "14 loads")
        ]
    )
}