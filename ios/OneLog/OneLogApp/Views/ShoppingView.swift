import SwiftUI
import UIKit

struct ShoppingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isSharing = false

    private var items: [ShoppingPlanItem] { store.currentShoppingItems }
    private var purchasableItems: [ShoppingPlanItem] {
        items.filter { $0.precision != .manual && resolvedPurchaseCount(for: $0, overrides: store.state.purchaseQuantityOverrides) > 0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "장보기")
                        Text("필요한 만큼만\n장바구니에 담아요.")
                            .font(.system(size: 31, weight: .black, design: .rounded))
                            .foregroundStyle(Color.oneLogInk)
                        Text("필요량과 실제로 살 포장 수를 구분해 보여줘요. 단위가 다르면 자동 환산하지 않고 확인을 요청합니다.")
                            .font(.subheadline)
                            .foregroundStyle(Color.oneLogMuted)
                            .lineSpacing(3)
                    }
                    .oneLogCard(fill: Color.oneLogPaleGreen)

                    if items.isEmpty {
                        EmptyState(symbol: "cart", title: "아직 장보기 목록이 없어요", message: "내 식사에 메뉴를 담으면 필요한 재료만 자동으로 모아 드려요.")
                            .oneLogCard()
                    } else {
                        summary
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeading("이번 식단 재료", subtitle: "보유량은 자동 환산하지 않아요. 다른 단위로 가지고 있다면 직접 확인해 주세요.")
                            ForEach(items) { item in
                                ShoppingItemRow(item: item, isChecked: store.state.purchaseChecks[item.id] == true)
                                    .environmentObject(store)
                            }
                        }
                        .oneLogCard()

                        NavigationLink {
                            FridgeView()
                                .environmentObject(store)
                        } label: {
                            Label("보유 재료 수량 수정하기", systemImage: "refrigerator")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button {
                            store.confirmPurchase(items: purchasableItems)
                        } label: {
                            Label("구매한 양을 냉장고에 반영", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(purchasableItems.isEmpty)

                        if !purchasableItems.isEmpty {
                            HStack(spacing: 10) {
                                Button {
                                    UIPasteboard.general.string = shoppingListText(items: purchasableItems, overrides: store.state.purchaseQuantityOverrides)
                                    store.recordShoppingEvent(.listCopied, itemIDs: purchasableItems.map(\.id))
                                    store.notice = "장보기 목록을 복사했어요."
                                } label: {
                                    Label("목록 복사", systemImage: "doc.on.doc")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(SecondaryButtonStyle())

                                Button {
                                    isSharing = true
                                    store.recordShoppingEvent(.listShared, itemIDs: purchasableItems.map(\.id))
                                } label: {
                                    Label("목록 공유", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.oneLogCream)
            .navigationTitle("장보기")
            .sheet(isPresented: $isSharing) {
                SystemShareSheet(items: [shoppingListText(items: purchasableItems, overrides: store.state.purchaseQuantityOverrides)])
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 10) {
            StatusSummaryTile(title: "추가 구매", value: "\(purchasableItems.count)개", tint: .oneLogOrange)
            StatusSummaryTile(title: "필요 재료", value: "\(items.count)개", tint: .oneLogGreen)
            StatusSummaryTile(title: "구매 확인", value: "\(items.filter { store.state.purchaseChecks[$0.id] == true }.count)개", tint: .oneLogGreen)
        }
    }
}

private struct StatusSummaryTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(Color.oneLogMuted)
            Text(value).font(.headline.weight(.black)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .oneLogCard()
    }
}

private struct ShoppingItemRow: View {
    @EnvironmentObject private var store: AppStore
    let item: ShoppingPlanItem
    let isChecked: Bool
    @State private var purchaseText = ""
    @State private var packageAmountText = ""

    private var purchaseCount: Int {
        purchasePackageCount(Double(purchaseText), fallback: item.purchaseQuantity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Button {
                    store.setPurchaseChecked(itemID: item.id, checked: !isChecked)
                } label: {
                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(isChecked ? Color.oneLogGreen : Color.oneLogMuted)
                }
                .accessibilityLabel(isChecked ? "구매 확인 해제" : "구매 완료 확인")
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.ingredientName).font(.headline.weight(.bold)).foregroundStyle(Color.oneLogInk)
                    Text(item.packageSize.label).font(.caption).foregroundStyle(Color.oneLogMuted)
                }
                Spacer()
                if item.precision == .manual {
                    StatusPill(text: "직접 확인", tint: .oneLogOrange)
                } else if item.quantityStatus == .unknown {
                    StatusPill(text: "보유량 미상", tint: .oneLogOrange)
                }
            }
            HStack(spacing: 7) {
                QuantityChip(label: "필요", value: formatQuantity(item.quantity, unit: item.unit))
                QuantityChip(label: "보유", value: formatQuantity(item.availableQuantity, unit: item.unit))
                QuantityChip(label: "예상 잔여", value: formatQuantity(item.expectedRemaining, unit: item.unit))
            }
            if item.precision == .manual {
                Text(item.note ?? "단위를 확인한 뒤 구매량을 직접 정해 주세요.")
                    .font(.caption)
                    .foregroundStyle(Color.oneLogOrange)
            } else {
                HStack(spacing: 8) {
                    Text("계산된 구매량")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.oneLogMuted)
                    Text("\(item.purchaseQuantity)포장")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.oneLogInk)
                    if purchaseCount != item.purchaseQuantity {
                        StatusPill(text: "수정됨", tint: .oneLogOrange)
                    }
                    Spacer()
                    Text("총 \(formatQuantity(Double(item.purchaseQuantity) * item.packageSize.amount, unit: item.unit))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.oneLogInk)
                }
                HStack(spacing: 8) {
                    Text("실제 구매량")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.oneLogMuted)
                    TextField("\(item.purchaseQuantity)", text: $purchaseText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 58)
                    Text("포장")
                        .font(.caption)
                        .foregroundStyle(Color.oneLogMuted)
                    Button("수량 적용") {
                        store.setPurchaseQuantity(itemID: item.id, value: Double(purchaseCount))
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.oneLogGreen)
                    Spacer()
                    Text("총 \(formatQuantity(Double(purchaseCount) * item.packageSize.amount, unit: item.unit))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.oneLogInk)
                }
                HStack(spacing: 8) {
                    Text("대표 판매 단위")
                        .font(.caption)
                        .foregroundStyle(Color.oneLogMuted)
                    TextField(formatQuantity(item.packageSize.amount), text: $packageAmountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 68)
                    Text(item.unit.rawValue)
                        .font(.caption)
                        .foregroundStyle(Color.oneLogMuted)
                    Button("단위 적용") {
                        guard let amount = Double(packageAmountText), amount > 0 else { return }
                        store.setPackageOverride(ingredientID: item.ingredientID, package: PackageSize(amount: amount, unit: item.unit, label: "\(formatQuantity(amount))\(item.unit.rawValue) 포장"))
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.oneLogGreen)
                    Spacer()
                }
            }
            if let note = item.note, item.precision != .manual {
                Text(note).font(.caption2).foregroundStyle(Color.oneLogMuted)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            purchaseText = String(resolvedPurchaseCount(for: item, overrides: store.state.purchaseQuantityOverrides))
            packageAmountText = formatQuantity(item.packageSize.amount)
        }
    }
}

private func resolvedPurchaseCount(for item: ShoppingPlanItem, overrides: [String: Double]) -> Int {
    purchasePackageCount(overrides[item.id], fallback: item.purchaseQuantity)
}

private func shoppingListText(items: [ShoppingPlanItem], overrides: [String: Double]) -> String {
    let lines = items.map { item in
        let count = resolvedPurchaseCount(for: item, overrides: overrides)
        return "- \(item.ingredientName) \(count)포장 (\(formatQuantity(Double(count) * item.packageSize.amount, unit: item.unit)))"
    }
    return (["한끼로그 장보기 목록"] + lines).joined(separator: "\n")
}

private struct QuantityChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(Color.oneLogMuted)
            Text(value).font(.caption.weight(.bold)).foregroundStyle(Color.oneLogInk)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.oneLogCream, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
