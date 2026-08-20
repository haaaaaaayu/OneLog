import MapKit
import SwiftUI

/// Apple 주소 검색과 명시적인 1회 GPS 요청을 사용하되, 확인 화면은
/// Figma 최종본(790:26)의 단순화된 동네 반경 지도를 그대로 표시한다.
struct NeighborhoodSheet: View {
    @Binding var neighborhood: String
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var location = LocationProvider()
    @StateObject private var search = NeighborhoodSearchService()
    @State private var query = ""
    @State private var selection: NeighborhoodSelection?

    private var isUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestResetState") }
    private var visibleCandidates: [NeighborhoodSearchCandidate] {
        if isUITest, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [
                .init(title: "성수동1가", subtitle: "서울특별시 성동구 성수동1가"),
                .init(title: "성수동2가", subtitle: "서울특별시 성동구 성수동2가"),
                .init(title: "성수1가제1동", subtitle: "서울특별시 성동구 성수1가제1동"),
                .init(title: "성수1가제2동", subtitle: "서울특별시 성동구 성수1가제2동"),
                .init(title: "서울숲2길", subtitle: "서울특별시 성동구 서울숲2길")
            ]
        }
        return Array(search.candidates.prefix(5))
    }

    var body: some View {
        Group {
            if let selection { confirmation(selection) } else { searchScreen }
        }
        .background(Color(hex: 0xFFFEFB))
        .onChange(of: query) { _, value in search.update(query: value) }
    }

    private var searchScreen: some View {
        VStack(spacing: 0) {
            header

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.figma(14, .medium))
                    .foregroundStyle(Color.oneLogInk)
                TextField("동네, 도로명, 건물명으로 검색", text: $query)
                    .font(.figma(14))
                    .foregroundStyle(Color.oneLogInk)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("profile.neighborhoodInput")
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color(hex: 0xF8F5EE), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 22)

            Button {
                Task {
                    guard let coordinate = await location.requestOnce(),
                          let resolved = await search.reverseGeocode(coordinate) else { return }
                    selection = NeighborhoodSelection(
                        title: resolved.title,
                        address: resolved.address,
                        mapCoordinate: resolved.coordinate,
                        verifiedCoordinate: resolved.coordinate
                    )
                }
            } label: {
                HStack(spacing: 9) {
                    if location.isRequesting || search.isResolving {
                        ProgressView().tint(Color.oneLogInk)
                    } else {
                        Image("IconPin").resizable().scaledToFit().frame(width: 18, height: 18)
                    }
                    Text(location.isRequesting ? "현재 위치 확인 중…" : "현재 위치로 찾기").figmaText(14, .bold)
                }
                .foregroundStyle(Color.oneLogInk)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.oneLogInk, lineWidth: 1.5) }
            }
            .buttonStyle(.plain)
            .disabled(location.isRequesting || search.isResolving)
            .accessibilityIdentifier("neighborhood.currentLocation")
            .padding(.top, 14)

            Text(location.errorMessage ?? search.errorMessage ?? "버튼을 누를 때만 위치를 한 번 읽고 약 100m 단위로 저장해요.")
                .figmaText(11, .medium, lineHeight: 17)
                .foregroundStyle(location.errorMessage == nil && search.errorMessage == nil ? Color.oneLogFaint : Color.oneLogOrange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 13)

            Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "동네를 검색해 주세요" : "검색 결과")
                .figmaText(13, .bold)
                .foregroundStyle(Color(hex: 0x574F40))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 17)

            resultContent

            Text("주소 검색은 동네 이름만 저장하고, GPS를 직접 선택한 경우에만 대략 좌표를 저장해요.")
                .figmaText(11, .medium, lineHeight: 17)
                .foregroundStyle(Color.oneLogFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 14)

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 38)
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private var resultContent: some View {
        if search.isResolving {
            ProgressView("주소 확인 중…")
                .tint(Color.oneLogInk)
                .frame(maxWidth: .infinity)
                .frame(height: 72)
        } else if visibleCandidates.isEmpty, !query.isEmpty {
            Text(search.errorMessage ?? "검색 결과가 없어요. 동 이름이나 도로명을 다시 입력해 주세요.")
                .figmaText(12, .medium, lineHeight: 18)
                .foregroundStyle(Color.oneLogFaint)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
        } else if !visibleCandidates.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(visibleCandidates.enumerated()), id: \.element.id) { index, result in
                    Button { Task { await select(result) } } label: {
                        HStack(spacing: 12) {
                            Image("IconPin").resizable().scaledToFit().frame(width: 16, height: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayTitle(for: result)).figmaText(15, .bold).foregroundStyle(Color.oneLogInk).lineLimit(1)
                                Text(displaySubtitle(for: result)).figmaText(11, .medium).foregroundStyle(Color.oneLogFaint).lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Text("›").figmaText(19, .medium).foregroundStyle(Color.oneLogFaint)
                        }
                        .frame(height: 61)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("neighborhood.result.\(index)")
                    if index < visibleCandidates.count - 1 {
                        Rectangle().fill(Color.oneLogDivider).frame(height: 1).padding(.leading, 17)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0xE5DECC), lineWidth: 1) }
            .padding(.top, 11)
        }
    }

    private func select(_ candidate: NeighborhoodSearchCandidate) async {
        if isUITest {
            selection = NeighborhoodSelection(
                title: candidate.title,
                address: candidate.subtitle,
                mapCoordinate: ShareCoordinate(latitude: 37.544, longitude: 127.056),
                verifiedCoordinate: nil
            )
            return
        }
        guard let resolved = await search.resolve(candidate) else { return }
        selection = NeighborhoodSelection(
            title: resolved.title,
            address: resolved.address,
            mapCoordinate: resolved.coordinate,
            verifiedCoordinate: nil
        )
    }

    private func displayTitle(for candidate: NeighborhoodSearchCandidate) -> String {
        let trimmed = candidate.title
            .replacingOccurrences(of: "대한민국", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split(separator: " ").last.map(String.init) ?? trimmed
    }

    private func displaySubtitle(for candidate: NeighborhoodSearchCandidate) -> String {
        let value = candidate.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? candidate.title : value
    }

    private func confirmation(_ result: NeighborhoodSelection) -> some View {
        return VStack(spacing: 0) {
            header

            FigmaNeighborhoodMap(title: result.title)
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 22)

            VStack(alignment: .leading, spacing: 5) {
                Text(result.address.isEmpty ? result.title : result.address)
                    .figmaText(18, .bold)
                    .foregroundStyle(Color.oneLogInk)
                Text(result.verifiedCoordinate == nil
                     ? "이 동네 이름으로 나눔 글을 찾아요. 위치 좌표는 저장하지 않아요."
                     : "GPS 좌표는 약 100m 단위로 반올림해 도보 시간에만 사용해요.")
                    .figmaText(11, .medium, lineHeight: 17)
                    .foregroundStyle(Color.oneLogFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0xE5DECC), lineWidth: 1) }
            .padding(.top, 16)

            Spacer()

            Button {
                neighborhood = result.address
                if let verified = result.verifiedCoordinate {
                    store.setVerifiedNeighborhood(result.address, coordinate: verified)
                } else {
                    store.setNeighborhood(result.address)
                }
                dismiss()
            } label: {
                Text("이 동네로 인증하기")
                    .figmaText(15, .bold)
                    .foregroundStyle(Color(hex: 0xF5F5F5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: 0x2C2C2C), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .accessibilityIdentifier("neighborhood.confirm")
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 20)
        .padding(.top, 38)
        .ignoresSafeArea(edges: [.top, .bottom])
    }

    private var header: some View {
        ZStack {
            Text("동네 인증").figmaText(20, .bold).foregroundStyle(Color.oneLogInk)
            HStack {
                Button {
                    if selection != nil { selection = nil } else { dismiss() }
                } label: {
                    Image("IconBack").resizable().renderingMode(.template).scaledToFit()
                        .frame(width: 18, height: 18).foregroundStyle(Color.oneLogInk)
                        .frame(width: 36, height: 36).background(.white, in: Circle())
                        .overlay { Circle().stroke(Color(hex: 0xE3D9BF), lineWidth: 1) }
                }
                .accessibilityLabel("뒤로")
                Spacer()
            }
        }
        .frame(height: 44)
        .padding(.top, 8)
    }
}

/// 790:26의 지도는 실제 지도 타일이 아니라 개인정보를 드러내지 않는 개념도다.
/// 검색과 좌표 계산은 그대로 실제 데이터를 쓰고, 확인 UI만 이 정적인 반경 표현을 쓴다.
private struct FigmaNeighborhoodMap: View {
    let title: String

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                Color(hex: 0xE5ECE7)

                Path { path in
                    for fraction: CGFloat in [0.286, 0.687] {
                        let x = width * fraction
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    for fraction: CGFloat in [0.337, 0.675] {
                        let y = height * fraction
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(Color(hex: 0xD3DDD6), lineWidth: 3)

                Circle()
                    .fill(Color(hex: 0xFFF0A6).opacity(0.38))
                    .overlay { Circle().stroke(Color(hex: 0xFFC914), lineWidth: 2) }
                    .frame(width: 230, height: 230)

                VStack(spacing: 4) {
                    Text(title.isEmpty ? "현재 동네" : title)
                        .figmaText(11, .bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 25)
                        .background(Color.oneLogInk, in: Capsule())

                    Image("IconPin")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }

                VStack {
                    HStack {
                        Spacer()
                        Text("반경 1km")
                            .figmaText(11, .bold)
                            .foregroundStyle(Color(hex: 0x574F40))
                            .padding(.horizontal, 11)
                            .frame(height: 25)
                            .background(.white, in: Capsule())
                    }
                    Spacer()
                }
                .padding(12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) 반경 1킬로미터")
    }
}

private struct NeighborhoodSelection: Hashable {
    let title: String
    let address: String
    let mapCoordinate: ShareCoordinate
    let verifiedCoordinate: ShareCoordinate?
}
