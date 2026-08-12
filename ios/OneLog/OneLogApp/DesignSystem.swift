import SwiftUI

extension Color {
    static let oneLogInk = Color(red: 0.09, green: 0.13, blue: 0.10)
    static let oneLogGreen = Color(red: 0.20, green: 0.42, blue: 0.26)
    static let oneLogPaleGreen = Color(red: 0.91, green: 0.95, blue: 0.89)
    static let oneLogCream = Color(red: 0.985, green: 0.98, blue: 0.95)
    static let oneLogMuted = Color(red: 0.39, green: 0.45, blue: 0.40)
    static let oneLogOrange = Color(red: 0.78, green: 0.36, blue: 0.23)
    static let oneLogLine = Color(red: 0.86, green: 0.90, blue: 0.85)
}

struct OneLogCardModifier: ViewModifier {
    var fill: Color = .white

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.oneLogLine, lineWidth: 1)
            }
    }
}

extension View {
    func oneLogCard(fill: Color = .white) -> some View {
        modifier(OneLogCardModifier(fill: fill))
    }
}

struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(Color.oneLogGreen)
    }
}

struct SectionHeading: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.black))
                .foregroundStyle(Color.oneLogInk)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.oneLogMuted)
            }
        }
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.oneLogGreen)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.oneLogInk)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.oneLogMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = .oneLogGreen

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(tint.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.oneLogGreen)
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(Color.oneLogPaleGreen.opacity(configuration.isPressed ? 0.65 : 1), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

struct StatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.11), in: Capsule())
    }
}

struct IngredientLine: View {
    let name: String
    let value: String
    let note: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(name)
                .font(.subheadline)
                .foregroundStyle(Color.oneLogInk)
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Color.oneLogMuted)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.oneLogInk)
        }
        .padding(.vertical, 9)
    }
}
