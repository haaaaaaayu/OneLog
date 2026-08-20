import SwiftUI
import UIKit

/// F07·F14 장보기. 피그마 `식단 관리 2 / 장보기 리스트`(467:29) 좌표를 그대로 옮긴다.
/// 실제 구매량·판매 단위 수정은 품목 탭으로, 복사·공유는 완료 버튼의 컨텍스트 메뉴와
/// VoiceOver 사용자 동작으로 제공한다. Figma에 없는 보조 버튼은 본 화면에 만들지 않는다.
struct ShoppingView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var isSharing = false
    @State private var editingItem: ShoppingPlanItem?
    @State private var isFridgePresented = false

    private var items: [ShoppingPlanItem] { store.currentShoppingItems }
    private var checkedCount: Int { items.filter { store.state.purchaseChecks[$0.id] == true }.count }
    private var purchasableItems: [ShoppingPlanItem] {
        // 수량 미상(`.estimated`)은 포장 단위가 있어도 실제 보유량을
        // 확인하기 전까지 재고에 반영할 수 없다.
        items.filter { $0.precision == .exact && resolvedPurchaseCount(for: $0, overrides: store.state.purchaseQuantityOverrides) > 0 }
    }

    private var estimate: BudgetEstimate {
        let drafts = store.plannedMeals.filter { $0.status == .planned }.map {
            PlannedMealDraft(recipeID: $0.recipeID, date: $0.date, mealSlot: $0.mealSlot, reason: "", reusedIngredientIDs: [], newPurchaseCount: 0)
        }
        return store.estimate(for: drafts, targetBudget: store.state.targetBudget)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                CareHeader(title: "장보기 리스트", trailing: items.isEmpty ? nil : "\(checkedCount)/\(items.count)") { dismiss() }

                if items.isEmpty {
                    CareCard(padding: EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("아직 장보기 목록이 없어요")
                                .figmaText(16, .bold)
                                .foregroundStyle(CarePalette.ink)
                            Text("식단을 확정하면 필요한 재료만 자동으로 모아 드려요.")
                                .figmaText(11, .medium)
                                .foregroundStyle(CarePalette.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    itemsCard
                    if items.contains(where: { $0.precision != .exact }) {
                        Text("수량을 정확히 확인한 품목만 장보기 완료로 재고에 반영해요.")
                            .figmaText(11, .medium)
                            .foregroundStyle(Color.oneLogOrange)
                            .padding(.horizontal, 4)
                    }
                    budgetRow
                    completeButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(CarePalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .preference(key: BottomNavigationHiddenPreferenceKey.self, value: true)
        .sheet(item: $editingItem) { item in
            ShoppingItemEditor(item: item).environmentObject(store)
        }
        .sheet(isPresented: $isSharing) {
            SystemShareSheet(items: [shoppingListText(items: purchasableItems, overrides: store.state.purchaseQuantityOverrides)])
        }
        .navigationDestination(isPresented: $isFridgePresented) {
            FridgeView().environmentObject(store)
        }
    }

    // MARK: - 재료 목록 (520:31)

    private var itemsCard: some View {
        CareCard(padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)) {
            VStack(alignment: .leading, spacing: 0) {
                Text("이번 식단에 필요한 재료")
                    .figmaText(16, .bold)
                    .foregroundStyle(CarePalette.ink)
                Text("마트 판매 단위를 기준으로 정리했어요.")
                    .figmaText(11, .medium)
                    .foregroundStyle(CarePalette.muted)

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    itemRow(item)
                    if index < items.count - 1 {
                        Rectangle().fill(CarePalette.divider).frame(height: 1)
                    }
                }
            }
        }
    }

    private func itemRow(_ item: ShoppingPlanItem) -> some View {
        let isChecked = store.state.purchaseChecks[item.id] == true

        return HStack(spacing: 9) {
            Button {
                store.setPurchaseChecked(itemID: item.id, checked: !isChecked)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isChecked ? CarePalette.brand : .white)
                        .frame(width: 20, height: 20)
                        .overlay {
                            if !isChecked {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(CarePalette.line, lineWidth: 1)
                            }
                        }
                    if isChecked {
                        Text("✓")
                            .figmaText(11, .medium)
                            .foregroundStyle(CarePalette.ink)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isChecked ? "\(item.ingredientName) 구매 확인 해제" : "\(item.ingredientName) 구매 완료 확인")

            Button {
                editingItem = item
            } label: {
                HStack(spacing: 9) {
                    Text(itemTitle(item))
                        .figmaText(13, .medium)
                        .foregroundStyle(CarePalette.itemText)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(priceText(item))
                        .figmaText(11, .medium)
                        .foregroundStyle(CarePalette.muted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("구매량과 판매 단위를 수정해요")
        }
        .padding(.vertical, 8)
        .frame(height: 42)
    }

    /// 시안은 `달걀 12구 1팩`처럼 재료 + 판매 단위 + 구매 개수를 한 줄로 적는다.
    /// `packageSize.label`에는 재료명이 들어 있는 경우가 있어(`가츠오부시 100g`) 수치만 다시 조합한다.
    private func itemTitle(_ item: ShoppingPlanItem) -> String {
        let pack = formatQuantity(item.packageSize.amount, unit: item.unit)
        guard item.precision == .exact else {
            // 같은 재료라도 단위가 다르면 다른 줄로 나온다. 필요량을 같이 적어 구분한다.
            let reason = item.precision == .estimated ? "보유량 확인 필요" : "판매 단위 확인 필요"
            return "\(item.ingredientName) \(formatQuantity(item.quantity, unit: item.unit)) · \(reason)"
        }
        let count = resolvedPurchaseCount(for: item, overrides: store.state.purchaseQuantityOverrides)
        guard count > 0 else { return "\(item.ingredientName) · 추가 구매 없음" }
        return count > 1 ? "\(item.ingredientName) \(pack) × \(count)" : "\(item.ingredientName) \(pack)"
    }

    private func priceText(_ item: ShoppingPlanItem) -> String {
        let count = resolvedPurchaseCount(for: item, overrides: store.state.purchaseQuantityOverrides)
        guard item.precision == .exact,
              let price = store.ingredientPrices[item.ingredientID],
              price.unit == item.unit,
              abs(price.packageAmount - item.packageSize.amount) < 0.000001 else {
            return "가격 확인 전"
        }
        return won(count * price.price)
    }

    // MARK: - 예산 요약 (520:72)

    private var budgetRow: some View {
        HStack(spacing: 10) {
            CareCard(padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("예상 구매 금액")
                        .figmaText(11, .medium)
                        .foregroundStyle(CarePalette.muted)
                    Text(estimate.knownPurchaseCost > 0 ? won(estimate.knownPurchaseCost) : "가격 확인 전")
                        .figmaText(16, .bold)
                        .foregroundStyle(CarePalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            CareCard(padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12), fill: CarePalette.thumb) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("남은 예산")
                        .figmaText(11, .medium)
                        .foregroundStyle(CarePalette.muted)
                    Text(remainingBudgetText)
                        .figmaText(16, .bold)
                        .foregroundStyle(CarePalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 74)
    }

    private var remainingBudgetText: String {
        guard store.state.targetBudget > 0 else { return "예산 미설정" }
        guard let remaining = estimate.remainingBudget else { return "확인 전" }
        return won(remaining)
    }

    // MARK: - 장보기 완료 (520:79)

    private var completeButton: some View {
        Button {
            store.confirmPurchase(items: purchasableItems)
        } label: {
            Text("장보기 완료")
                .figmaText(16, .bold)
                .foregroundStyle(CarePalette.onDark)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(CarePalette.dark.opacity(purchasableItems.isEmpty ? 0.4 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(purchasableItems.isEmpty)
        .accessibilityIdentifier("shopping.complete")
        .contextMenu {
            Button("목록 복사", systemImage: "doc.on.doc", action: copyList)
            Button("목록 공유", systemImage: "square.and.arrow.up", action: shareList)
            Button("보유 재료 수량 수정", systemImage: "refrigerator") { isFridgePresented = true }
        }
        .accessibilityAction(named: "목록 복사", copyList)
        .accessibilityAction(named: "목록 공유", shareList)
        .accessibilityAction(named: "보유 재료 수량 수정") { isFridgePresented = true }
    }

    private func copyList() {
        UIPasteboard.general.string = shoppingListText(items: purchasableItems, overrides: store.state.purchaseQuantityOverrides)
        store.recordShoppingEvent(.listCopied, itemIDs: purchasableItems.map(\.id))
        store.notice = "장보기 목록을 복사했어요."
    }

    private func shareList() {
        isSharing = true
        store.recordShoppingEvent(.listShared, itemIDs: purchasableItems.map(\.id))
    }
}

// MARK: - 항목 시트: 실제 구매량과 판매 단위 (F14)

private struct ShoppingItemEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let item: ShoppingPlanItem
    @State private var purchaseText = ""
    @State private var packageAmountText = ""

    private var purchaseCount: Int {
        purchasePackageCount(Double(purchaseText), fallback: item.purchaseQuantity)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    CareCard(padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.ingredientName)
                                .figmaText(16, .bold)
                                .foregroundStyle(CarePalette.ink)
                            HStack(spacing: 7) {
                                quantityChip("필요", formatQuantity(item.quantity, unit: item.unit))
                                quantityChip("보유", formatQuantity(item.availableQuantity, unit: item.unit))
                                quantityChip("예상 잔여", formatQuantity(item.expectedRemaining, unit: item.unit))
                            }
                            if let note = item.note {
                                Text(note)
                                    .figmaText(11, .medium)
                                    .foregroundStyle(item.precision == .manual ? Color.oneLogOrange : CarePalette.muted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    CareCard(padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("판매 단위")
                                .figmaText(13, .bold)
                                .foregroundStyle(CarePalette.ink)
                            HStack(spacing: 8) {
                                TextField(formatQuantity(item.packageSize.amount), text: $packageAmountText)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 84)
                                Text(item.unit.rawValue)
                                    .figmaText(12, .medium)
                                    .foregroundStyle(CarePalette.muted)
                                Spacer()
                                Button("적용") {
                                    guard let amount = Double(packageAmountText), amount > 0 else { return }
                                    store.setPackageOverride(ingredientID: item.ingredientID, package: PackageSize(amount: amount, unit: item.unit, label: "\(formatQuantity(amount))\(item.unit.rawValue) 포장"))
                                    dismiss()
                                }
                                .figmaText(12, .bold)
                                .foregroundStyle(Color.oneLogSuccess)
                            }

                            if item.precision == .exact {
                                Divider().overlay(CarePalette.divider)
                                Text("실제 구매량")
                                    .figmaText(13, .bold)
                                    .foregroundStyle(CarePalette.ink)
                                HStack(spacing: 8) {
                                    TextField("\(item.purchaseQuantity)", text: $purchaseText)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 84)
                                    Text("포장")
                                        .figmaText(12, .medium)
                                        .foregroundStyle(CarePalette.muted)
                                    Spacer()
                                    Text("총 \(formatQuantity(Double(purchaseCount) * item.packageSize.amount, unit: item.unit))")
                                        .figmaText(12, .bold)
                                        .foregroundStyle(CarePalette.ink)
                                }
                                Button {
                                    store.setPurchaseQuantity(itemID: item.id, value: Double(purchaseCount))
                                    dismiss()
                                } label: {
                                    Text("구매량 저장")
                                        .figmaText(14, .bold)
                                        .foregroundStyle(CarePalette.onDark)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(CarePalette.dark, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(CarePalette.canvas)
            .navigationTitle("구매량 확인")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
            .onAppear {
                purchaseText = String(resolvedPurchaseCount(for: item, overrides: store.state.purchaseQuantityOverrides))
                packageAmountText = formatQuantity(item.packageSize.amount)
            }
        }
    }

    private func quantityChip(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).figmaText(10, .medium).foregroundStyle(CarePalette.muted)
            Text(value).figmaText(12, .bold).foregroundStyle(CarePalette.ink)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(CarePalette.canvas, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

private struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
