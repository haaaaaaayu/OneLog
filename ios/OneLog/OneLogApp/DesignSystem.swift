import SwiftUI

extension Color {
    /// 피그마 `유진) 수정완료` 프레임의 16진수 값을 그대로 옮긴다. 새 값을 넣기 전에 디자인에서 먼저 확인한다.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    // 기존 화면이 쓰던 이름은 유지하고 값만 새 팔레트로 바꾼다.
    static let oneLogInk = Color(hex: 0x141412)
    static let oneLogGreen = Color(hex: 0x141412)      // 주요 동작(검은 CTA)
    static let oneLogPaleGreen = Color(hex: 0xFFF4C9)  // 보조 버튼 배경(연노랑)
    static let oneLogCream = Color(hex: 0xFFFDF6)
    static let oneLogMuted = Color(hex: 0x6B6659)
    static let oneLogOrange = Color(hex: 0xC4761F)
    static let oneLogLine = Color(hex: 0xDED6C4)

    static let oneLogBrand = Color(hex: 0xFFD62E)      // 히어로 노랑
    static let oneLogBrandDeep = Color(hex: 0xFFC914)  // 탭 활성 노랑
    static let oneLogBand = Color(hex: 0xFDFAEB)       // 식단 영역 띠
    static let oneLogBody = Color(hex: 0x2B2418)
    static let oneLogFaint = Color(hex: 0x998C78)
    static let oneLogDivider = Color(hex: 0xEFE7D6)
    static let oneLogChip = Color(hex: 0xF0EDE5)
    static let oneLogChipLine = Color(hex: 0xDED4B5)
    static let oneLogSuccess = Color(hex: 0x338C4D)
    static let oneLogSuccessBackground = Color(hex: 0xE0F2E3)
    static let oneLogPhoto = Color(hex: 0xE0DDD1)
}

extension View {
    /// 카드 그림자: 피그마 `0px 4px 16px rgba(0,0,0,0.06)`.
    func oneLogCardShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

struct OneLogCardModifier: ViewModifier {
    var fill: Color = .white

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .oneLogCardShadow()
    }
}

extension View {
    func oneLogCard(fill: Color = .white) -> some View {
        modifier(OneLogCardModifier(fill: fill))
    }
}

// MARK: - 피그마 공통 컴포넌트

/// 피그마 `다음 버튼`(350:2302). 높이 50, radius 8, #FFC914 위에 16pt 볼드.
struct FigmaPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.oneLogInk)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.oneLogBrandDeep.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .disabled(!isEnabled)
    }
}

/// 피그마 칩. 노랑(#FFC914)과 알레르기용 빨강(#CC4242) 두 가지 강조를 쓴다.
struct FigmaChip: View {
    enum Accent {
        case yellow
        case red

        var background: Color { self == .yellow ? Color(hex: 0xFFF4C9) : Color(hex: 0xFCE6E1) }
        var border: Color { self == .yellow ? Color(hex: 0xFFC914) : Color(hex: 0xCC4242) }
        var foreground: Color { self == .yellow ? Color.oneLogInk : Color(hex: 0x9E2626) }
    }

    let title: String
    let isSelected: Bool
    var accent: Accent = .yellow
    var idleBorder: Color = Color(hex: 0xDFD3B6)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? accent.foreground : Color.oneLogBody)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)
                .padding(.vertical, 9)
                .background(isSelected ? accent.background : .white, in: Capsule())
                .overlay {
                    Capsule().stroke(isSelected ? accent.border : idleBorder, lineWidth: isSelected ? 1.5 : 1)
                }
        }
        .buttonStyle(.plain)
    }
}

/// 피그마 `Input / 이름`(350:2272). 높이 52, radius 14, 테두리 #DFD3B6.
struct FigmaField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.oneLogInk)
            content
        }
    }
}

struct FigmaTextInput: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color.oneLogFaint))
            .font(.system(size: 14))
            .foregroundStyle(Color.oneLogInk)
            .keyboardType(keyboard)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(hex: 0xDFD3B6), lineWidth: 1)
            }
    }
}

/// 피그마 `Progress Segment`(350:2261). 344x4, 3칸.
struct FigmaProgressSegments: View {
    let step: Int
    var total: Int = 3

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < step ? Color.oneLogBrandDeep : Color(hex: 0xECEBEB))
                    .frame(height: 4)
            }
        }
    }
}

/// 피그마 온보딩 상단(뒤로 ‹ + `n / 3`).
struct FigmaStepHeader: View {
    let step: Int
    var total: Int = 3
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Button(action: onBack) {
                        Text("‹")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.oneLogInk)
                            .frame(width: 30, height: 36, alignment: .leading)
                    }
                    .accessibilityLabel("뒤로")
                    Spacer()
                    Text("\(step) / \(total)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: 0x574F40))
                }
            }
            .frame(height: 36)
            .padding(.top, 11)

            FigmaProgressSegments(step: step, total: total)
                .padding(.top, 10)
        }
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
