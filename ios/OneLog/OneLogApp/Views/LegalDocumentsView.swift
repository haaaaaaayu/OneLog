import SwiftUI

enum LegalDocumentKind: String, Identifiable, CaseIterable {
    case terms
    case privacy
    case community
    case openSource

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: "서비스 이용약관"
        case .privacy: "개인정보 처리방침"
        case .community: "커뮤니티 운영정책"
        case .openSource: "오픈소스 라이선스"
        }
    }

    var effectiveDate: String { "2026년 8월 20일" }

    var sections: [LegalSection] {
        switch self {
        case .terms:
            return [
                .init("1. 목적", "이 약관은 한끼로그 운영팀이 제공하는 식단 계획, 장보기·재고 관리, AI 식단 대화 및 동네 재료 나눔 서비스의 이용 조건을 정합니다."),
                .init("2. 계정과 기기 저장", "사용자는 Google 계정을 연결하거나 기기 전용으로 시작할 수 있습니다. 기기 전용 데이터는 앱 삭제·기기 변경 시 복구되지 않을 수 있습니다. 계정을 타인에게 양도하거나 다른 사람의 계정을 사용해서는 안 됩니다."),
                .init("3. 식단·가격 정보", "수량·예산·가격은 사용자가 확인한 값과 앱에 등록된 대표 판매 단위를 바탕으로 계산됩니다. 가격이나 단위가 확인되지 않은 항목은 확정값으로 표시하지 않습니다. 알레르기 정보는 의료 조언을 대신하지 않으며 사용자가 재료 표시를 최종 확인해야 합니다."),
                .init("4. AI 기능", "AI 식단 대화는 메뉴 후보와 설명만 제공합니다. 최종 메뉴 선택과 수량·가격·예산·재고 계산은 사용자와 앱의 결정론적 계산이 담당합니다. AI 결과는 부정확할 수 있으며 사용자는 언제든 직접 구성으로 전환할 수 있습니다."),
                .init("5. 동네 나눔", "사용자는 합법적으로 처분할 수 있고 안전하게 보관된 재료만 게시해야 합니다. 금지 품목, 허위 정보, 위해 가능성이 있는 식품, 금전 사기, 괴롭힘 및 개인정보 공개를 금지합니다. 거래·만남의 최종 판단과 식품 상태 확인은 참여자가 직접 해야 합니다."),
                .init("6. 게시물 조치", "운영정책을 위반한 글·메시지는 신고 접수 후 숨김, 삭제, 이용 제한될 수 있습니다. 긴급한 안전 문제가 있는 경우 관계 기관에 먼저 연락해야 합니다."),
                .init("7. 탈퇴와 종료", "설정에서 회원 탈퇴를 요청하면 계정과 연결된 서버 콘텐츠 및 기기 데이터를 삭제합니다. 법령상 보존 의무 또는 분쟁 처리에 필요한 최소 정보는 별도 고지된 기간 동안 보존될 수 있습니다."),
                .init("8. 변경과 문의", "중대한 변경은 시행 전에 앱에서 알립니다. 서비스 문의와 개인정보 요청은 설정의 ‘문의하기’에서 접수할 수 있습니다.")
            ]
        case .privacy:
            return [
                .init("1. 처리하는 정보", "필수 또는 선택 입력에 따라 닉네임, 생년월일, 요리 숙련도, 선호 조리 시간, 조리도구, 불호·알레르기 재료, 동네 이름을 처리합니다. Google 연결 시 Firebase 인증 식별자·이름·이메일을 처리합니다."),
                .init("2. 위치 정보", "재료 나눔에서 사용자가 ‘현재 위치로 찾기’를 누른 경우에만 위치를 한 번 읽습니다. 서버에는 약 100m 격자로 반올림한 좌표만 저장하며, 이웃과의 ‘도보 약 n분’ 표시 외의 목적으로 사용하거나 지속 추적하지 않습니다. 권한을 거부해도 동네 이름으로 이용할 수 있습니다."),
                .init("3. 이용 콘텐츠", "소분·공동구매 글, 참여 요청, 채팅, 약속 시간·장소 메모는 Firebase에 저장됩니다. 식단 AI 대화를 사용할 때 현재 식단, 선호·알레르기, 보유 재료와 대화 내용이 Firebase Cloud Functions를 거쳐 OpenAI에 전송됩니다."),
                .init("4. 저장 위치와 목적", "기본 식단·재고·장보기 기록은 기기에 저장하고, Google 계정을 연결한 경우 기기 변경 복구를 위해 Firebase에 암호화 전송해 백업합니다. Firebase는 인증·백업·동네 나눔·채팅·약속·푸시 알림·AI 중계에 사용합니다. OpenAI는 요청한 AI 답변 생성에만 사용합니다. 광고 추적이나 데이터 판매에는 사용하지 않습니다."),
                .init("5. 보존 기간", "기기 데이터는 사용자가 삭제하거나 앱을 제거할 때까지 보존됩니다. 동네 글은 모집 종료 또는 만료 후 정리되며, 계정 탈퇴 시 연결된 게시물·메시지·약속을 삭제합니다. 신고 기록은 안전 운영과 분쟁 처리를 위해 필요한 기간 동안 제한적으로 보존할 수 있습니다."),
                .init("6. 이용자 권리", "설정에서 프로필을 수정하고 계정 연결을 해제하거나 회원 탈퇴로 전체 삭제를 요청할 수 있습니다. 신고·차단·개인정보 열람 및 삭제 문의는 설정의 ‘문의하기’에서 접수할 수 있습니다."),
                .init("7. 보호 조치", "좌표 정밀도 제한, Firebase 인증·보안 규칙·App Check, 멤버 전용 채팅 권한, OpenAI 키의 서버 Secret 보관, 통신 암호화를 적용합니다."),
                .init("8. 처리 주체", "서비스 제공 및 개인정보 문의 창구는 한끼로그 운영팀입니다. 앱 설정의 ‘문의·신고 접수’를 통해 요청할 수 있습니다.")
            ]
        case .community:
            return [
                .init("안전한 재료만", "변질됐거나 보관 상태를 확인할 수 없는 식품, 개봉 후 안전을 보장하기 어려운 식품, 법으로 거래가 금지된 품목은 게시하지 마세요."),
                .init("존중과 개인정보", "혐오·위협·성적 콘텐츠·괴롭힘·사칭·외부 연락처 강요·정확한 집 주소 공개를 금지합니다. 약속 장소는 공개된 안전한 장소를 권장합니다."),
                .init("금전과 허위 정보", "표시 금액, 분량, 모집 인원과 식품 상태를 사실대로 적어야 합니다. 선입금 사기, 허위 할인, 반복 스팸을 금지합니다."),
                .init("신고와 차단", "글 또는 채팅에서 신고하거나 사용자를 차단할 수 있습니다. 신고된 콘텐츠는 운영자가 검토하며 위해 우려가 크면 즉시 숨김 또는 계정 제한 조치를 할 수 있습니다."),
                .init("긴급 상황", "범죄·신체 위해·심각한 식품 안전 문제가 의심되면 앱 신고만 기다리지 말고 경찰·소방·식품안전 관련 기관에 연락하세요.")
            ]
        case .openSource:
            return [
                .init("Noto Sans KR", "SIL Open Font License 1.1 · 앱에 포함된 Fonts/OFL.txt에서 전문을 확인할 수 있습니다."),
                .init("Firebase iOS SDK", "Apache License 2.0 · Copyright Google LLC"),
                .init("Google Sign-In for iOS", "Apache License 2.0 · Copyright Google LLC"),
                .init("AppAuth for iOS", "Apache License 2.0 · Copyright OpenID Foundation"),
                .init("gRPC, nanopb, leveldb 및 Google 유틸리티", "각 패키지에 포함된 라이선스와 저작권 고지를 따릅니다. 소스와 전문은 각 패키지의 배포 저장소에서 확인할 수 있습니다."),
                .init("식품안전나라 레시피", "공공데이터포털·식품안전나라 COOKRCP01 자료를 가공해 사용하며, 앱 내 데이터 출처 화면에서 확인할 수 있습니다.")
            ]
        }
    }
}

struct LegalSection: Identifiable {
    let title: String
    let body: String
    var id: String { title }

    init(_ title: String, _ body: String) {
        self.title = title
        self.body = body
    }
}

struct LegalDocumentsView: View {
    let kind: LegalDocumentKind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(kind.title).figmaText(20, .bold).foregroundStyle(Color.oneLogInk)
                HStack {
                    Button { dismiss() } label: {
                        Image("IconBack").resizable().renderingMode(.template).scaledToFit()
                            .frame(width: 18, height: 18).foregroundStyle(Color.oneLogInk)
                            .frame(width: 38, height: 38).background(.white, in: Circle())
                            .overlay { Circle().stroke(Color(hex: 0xE3D9BF), lineWidth: 1) }
                    }
                    .accessibilityLabel("뒤로")
                    Spacer()
                }
            }
            .frame(height: 52)
            .padding(.horizontal, 20)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Text("시행일 · \(kind.effectiveDate)")
                        .figmaText(12, .medium)
                        .foregroundStyle(Color.oneLogFaint)

                    ForEach(kind.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .figmaText(16, .bold, lineHeight: 23)
                                .foregroundStyle(Color.oneLogInk)
                            Text(section.body)
                                .figmaText(13, .medium, lineHeight: 21)
                                .foregroundStyle(Color.oneLogBody)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: 0xFFFEFB))
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("legal.\(kind.rawValue)")
    }
}
