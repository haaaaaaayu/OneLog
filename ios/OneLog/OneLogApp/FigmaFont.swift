import CoreText
import SwiftUI

/// 피그마 `유진) 수정완료` 시안이 쓰는 Noto Sans KR. 가변 폰트 한 벌(wght 100~900)을 번들에 넣고
/// 앱 시작 시 등록한다. Info.plist가 생성 방식이라 `UIAppFonts` 대신 CoreText 런타임 등록을 쓴다.
enum FigmaFont {
    /// 타이포그래픽 패밀리 이름(name ID 16). 기본 인스턴스가 Thin이라 굵기는 항상 wght 축으로 지정해야 한다.
    static let family = "Noto Sans KR"

    /// 'wght' 4바이트 태그.
    private static let weightAxis = 0x77676874

    /// 피그마가 텍스트 박스 높이를 잡는 비율. CoreText는 Noto의 hhea 지표(1.448em)를 쓰는데
    /// 피그마는 훨씬 촘촘하게 잡는다. 시안 실측값(13→16, 15→18, 21→25, 24→29, 26→31)에서 역산했다.
    /// 이 보정이 없으면 모든 텍스트 블록이 시안보다 약 21% 높아진다.
    static let lineHeightRatio: CGFloat = 1.2

    private static let registered: Bool = {
        guard let url = Bundle.main.url(forResource: "NotoSansKR-VF", withExtension: "ttf", subdirectory: "Fonts") else {
            return false
        }
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    static func register() {
        _ = registered
    }

    static func uiFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        guard registered else { return .systemFont(ofSize: size, weight: weight) }
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: family,
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [weightAxis: axisValue(weight)],
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// UIFont.Weight → CSS 굵기. 시안은 Regular(400)·Medium(500)·Bold(700) 세 가지만 쓴다.
    private static func axisValue(_ weight: UIFont.Weight) -> CGFloat {
        switch weight {
        case .ultraLight: return 100
        case .thin: return 200
        case .light: return 300
        case .medium: return 500
        case .semibold: return 600
        case .bold: return 700
        case .heavy: return 800
        case .black: return 900
        default: return 400
        }
    }
}

extension Font {
    /// 시안 텍스트 스타일. 화면 코드에서는 `.system(size:weight:)` 대신 이걸 쓴다.
    /// `Text`에는 행간까지 맞춰주는 `.figmaText(_:_:)`를 쓰고, 이 쪽은 아이콘·입력 필드처럼
    /// 행간 보정이 필요 없는 곳에만 쓴다.
    static func figma(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> Font {
        Font(FigmaFont.uiFont(size: size, weight: weight))
    }
}

extension View {
    /// 시안 텍스트: 폰트와 행간을 함께 맞춘다. 시안에 line-height가 따로 적혀 있으면 `lineHeight`로 넘긴다.
    func figmaText(_ size: CGFloat, _ weight: UIFont.Weight = .regular, lineHeight: CGFloat? = nil) -> some View {
        font(.figma(size, weight))
            .figmaLineHeight(lineHeight ?? size * FigmaFont.lineHeightRatio, size: size, weight: weight)
    }
}
