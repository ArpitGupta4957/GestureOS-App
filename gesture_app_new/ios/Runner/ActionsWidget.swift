//
//  ActionsWidget.swift
//  Runner
//
//  Created by Gesture App on 2024.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), shortcuts: ["Call Mom", "Open WhatsApp"])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        // Read from Shared UserDefaults (App Group)
        let defaults = UserDefaults(suiteName: "group.com.yourcompany.gestureapp")
        let rawData = defaults?.string(forKey: "shortcuts_list") ?? "Draw,Bulk Dial"
        let shortcuts = rawData.components(separatedBy: ",")
        
        let entry = SimpleEntry(date: Date(), shortcuts: shortcuts)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        // Refresh every 15 minutes
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        
        // Read Data
        let defaults = UserDefaults(suiteName: "group.com.yourcompany.gestureapp")
        let rawData = defaults?.string(forKey: "shortcuts_list") ?? "Draw,Bulk Dial"
        let shortcuts = rawData.components(separatedBy: ",")

        let entry = SimpleEntry(date: currentDate, shortcuts: shortcuts)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let shortcuts: [String]
}

struct ActionsWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 8) {
            ForEach(entry.shortcuts.prefix(4), id: \.self) { shortcut in
                Link(destination: URL(string: "mydial://draw?action=\(shortcut)")!) {
                    HStack {
                        Image(systemName: "hand.draw")
                        Text(shortcut)
                            .font(.caption)
                            .bold()
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
    }
}

struct ActionsWidget: Widget {
    let kind: String = "ActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ActionsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Actions")
        .description("Quickly trigger your favorite gestures.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
