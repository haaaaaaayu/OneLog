// Noto Sans KR 가변 폰트가 wght 축으로 굵기를 만들어내는지 확인한다.
// FigmaFont.uiFont(size:weight:)와 같은 방식이라, 여기서 깨지면 앱에서도 깨진다.
//   swift ios/tools/check-figma-font.swift
import AppKit
import CoreText
import Foundation

let url = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()      // tools
    .deletingLastPathComponent()      // ios
    .appendingPathComponent("OneLog/OneLogApp/Fonts/NotoSansKR-VF.ttf")

guard CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) else {
    fatalError("폰트 등록 실패: \(url.path)")
}

/// FigmaFont와 같은 'wght' 태그.
let weightAxis = 0x7767_6874

func font(_ weight: CGFloat, size: CGFloat = 16) -> CTFont {
    let descriptor = CTFontDescriptorCreateWithAttributes([
        kCTFontFamilyNameAttribute: "Noto Sans KR",
        kCTFontVariationAttribute: [weightAxis: weight],
    ] as CFDictionary)
    return CTFontCreateWithFontDescriptor(descriptor, size, nil)
}

var names: [String] = []
for weight: CGFloat in [400, 500, 700] {
    let resolved = font(weight)
    let name = CTFontCopyPostScriptName(resolved) as String
    names.append(name)
    print("wght \(Int(weight)) -> \(name)")
}

// 기본 인스턴스가 Thin이라, 축이 안 먹으면 세 굵기가 전부 같은 이름으로 나온다.
assert(Set(names).count == 3, "wght 축이 적용되지 않았다: \(names)")
assert(names.contains { $0.hasSuffix("Bold") }, "Bold 인스턴스를 못 만들었다: \(names)")
print("OK")
