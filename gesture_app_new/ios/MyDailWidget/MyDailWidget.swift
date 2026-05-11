import WidgetKit
import SwiftUI

struct GestureWidgetEntry: TimelineEntry {
    let date: Date
}

struct GestureWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GestureWidgetEntry {
        GestureWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (GestureWidgetEntry) -> ()) {
        let entry = GestureWidgetEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GestureWidgetEntry>) -> ()) {
        let entry = GestureWidgetEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color(hex: "4ecca3"))
                
                Text("Quick Draw")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Tap to open")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .widgetURL(URL(string: "mydail://draw"))
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            HStack(spacing: 20) {
                // Draw button
                Link(destination: URL(string: "mydail://draw")!) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "4ecca3").opacity(0.2))
                                .frame(width: 50, height: 50)
                            Image(systemName: "hand.draw")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "4ecca3"))
                        }
                        Text("Draw")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                
                // Quick shortcuts
                VStack(alignment: .leading, spacing: 8) {
                    Text("MyDail")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Draw gestures to trigger actions")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        QuickActionButton(icon: "phone.fill", label: "Call")
                        QuickActionButton(icon: "globe", label: "Web")
                        QuickActionButton(icon: "flashlight.on.fill", label: "Light")
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "4ecca3"))
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Widget Configuration
struct MyDailWidget: Widget {
    let kind: String = "MyDailWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GestureWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                SmallWidgetView()
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                SmallWidgetView()
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Quick Draw")
        .description("Quickly open the gesture draw pad")
        .supportedFamilies([.systemSmall])
    }
}

struct MyDailMediumWidget: Widget {
    let kind: String = "MyDailMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GestureWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                MediumWidgetView()
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                MediumWidgetView()
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("MyDail Dashboard")
        .description("Quick access to gesture features")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Widget Bundle
@main
struct MyDailWidgetBundle: WidgetBundle {
    var body: some Widget {
        MyDailWidget()
        MyDailMediumWidget()
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview(as: .systemSmall) {
    MyDailWidget()
} timeline: {
    GestureWidgetEntry(date: .now)
}

#Preview(as: .systemMedium) {
    MyDailMediumWidget()
} timeline: {
    GestureWidgetEntry(date: .now)
}
