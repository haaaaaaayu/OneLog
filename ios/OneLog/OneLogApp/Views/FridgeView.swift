import SwiftUI

struct FridgeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingEditor = false
    @State private var editingItem: InventoryItem?

    private var recommendations: [LeftoverRecommendation] {
        leftoverRecommendations(inventory: store.state.inventory, preferences: store.state.preferences)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "내 냉장고 · 남은 재료")
                        Text("남은 재료를\n다음 한 끼로 이어요.")
                            .font(.system(size: 31, weight: .black, design: .rounded))
                            .foregroundStyle(Color.oneLogInk)
                        Text("수량을 정확히 모르겠다면 수량 미상으로 기록할 수 있어요. 미상 재료를 충분히 있다고 가정하지 않고 확인이 필요한 상태로 보여줘요.")
                            .font(.subheadline)
                            .foregroundStyle(Color.oneLogMuted)
                            .lineSpacing(3)
                    }
                    .oneLogCard(fill: Color.oneLogPaleGreen)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            SectionHeading("기록한 재료", subtitle: "이번 식단에 필요한 재료만 먼저 입력해도 충분해요.")
                            Spacer()
                            Button {
                                editingItem = nil
                                showingEditor = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.oneLogGreen)
                            }
                            .accessibilityLabel("재료 추가")
                        }
                        if store.state.inventory.isEmpty {
                            EmptyState(symbol: "refrigerator", title: "아직 기록한 재료가 없어요", message: "식단에 필요한 재료의 보유 여부와 수량을 먼저 알려 주세요.")
                        } else {
                            ForEach(store.state.inventory) { item in
                                InventoryRow(item: item, onEdit: {
                                    editingItem = item
                                    showingEditor = true
                                }, onDelete: {
                                    store.removeInventory(item)
                                })
                            }
                        }
                    }
                    .oneLogCard()

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeading("다음 메뉴 제안", subtitle: "보유 재료를 많이 쓰고, 부족한 재료는 실제 추가 구매량으로 보여줘요.")
                        if recommendations.isEmpty {
                            EmptyState(symbol: "wand.and.stars", title: "아직 추천할 메뉴가 없어요", message: "불호 재료나 조리도구 설정을 확인하거나 냉장고에 재료를 기록해 보세요.")
                        } else {
                            ForEach(recommendations.prefix(5)) { recommendation in
                                LeftoverRow(recommendation: recommendation) {
                                    let nextDate = dateByAddingDays(isoDateString(), 1)
                                    store.addPlannedMeal(recipeID: recommendation.recipe.id, date: nextDate, slot: recommendation.recipe.mealSlots.first ?? .dinner)
                                }
                            }
                        }
                    }
                    .oneLogCard()
                }
                .padding(16)
            }
            .background(Color.oneLogCream)
            .navigationTitle("냉장고")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingItem = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("재료 추가")
                }
            }
            .sheet(isPresented: $showingEditor) {
                InventoryEditorView(item: editingItem)
                    .environmentObject(store)
            }
        }
    }
}

private struct InventoryRow: View {
    let item: InventoryItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.quantityStatus == .unknown ? "questionmark.circle" : "checkmark.circle")
                .foregroundStyle(item.quantityStatus == .unknown ? Color.oneLogOrange : Color.oneLogGreen)
            VStack(alignment: .leading, spacing: 3) {
                Text(ingredient(for: item.ingredientID)?.name ?? "재료")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.oneLogInk)
                Text(item.quantityStatus == .unknown ? "수량 미상 · 확인 필요" : formatQuantity(item.quantity, unit: item.unit))
                    .font(.caption)
                    .foregroundStyle(item.quantityStatus == .unknown ? Color.oneLogOrange : Color.oneLogMuted)
            }
            Spacer()
            Menu {
                Button("수량 수정", action: onEdit)
                Button("삭제", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(Color.oneLogMuted)
                    .font(.title3)
            }
            .accessibilityLabel("재료 관리")
        }
        .padding(.vertical, 8)
    }
}

private struct LeftoverRow: View {
    let recommendation: LeftoverRecommendation
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Text(recommendation.recipe.symbolName).font(.title2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(recommendation.recipe.title).font(.subheadline.weight(.black)).foregroundStyle(Color.oneLogInk)
                    Text(recommendation.reason).font(.caption).foregroundStyle(Color.oneLogMuted).lineLimit(2)
                }
                Spacer()
            }
            if !recommendation.usedIngredientIDs.isEmpty {
                Text("활용 재료 · \(recommendation.usedIngredientIDs.compactMap { ingredient(for: $0)?.name }.joined(separator: ", "))")
                    .font(.caption.weight(.bold)).foregroundStyle(Color.oneLogGreen)
            }
            if !recommendation.additionalPurchaseItems.isEmpty {
                Text("추가 확인 · \(recommendation.additionalPurchaseItems.map(\.ingredientName).joined(separator: ", "))")
                    .font(.caption).foregroundStyle(Color.oneLogOrange)
            }
            Button("다음 식사로 담기", action: onAdd)
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.vertical, 8)
    }
}

private struct InventoryEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let item: InventoryItem?
    @State private var ingredientID: String
    @State private var quantityText: String
    @State private var isUnknown: Bool

    init(item: InventoryItem?) {
        self.item = item
        _ingredientID = State(initialValue: item?.ingredientID ?? ingredients.first?.id ?? "egg")
        _quantityText = State(initialValue: item?.quantity.map { formatQuantity($0) } ?? "")
        _isUnknown = State(initialValue: item?.quantityStatus == .unknown)
    }

    private var selectedIngredient: CanonicalIngredient? { ingredient(for: ingredientID) }

    var body: some View {
        NavigationStack {
            Form {
                Section("재료") {
                    Picker("재료", selection: $ingredientID) {
                        ForEach(ingredients) { item in Text(item.name).tag(item.id) }
                    }
                    .disabled(item != nil)
                }
                Section("보유량") {
                    Toggle("수량 미상으로 기록", isOn: $isUnknown)
                        .tint(.oneLogGreen)
                    if !isUnknown {
                        HStack {
                            TextField("수량", text: $quantityText)
                                .keyboardType(.decimalPad)
                            Text(selectedIngredient?.defaultUnit.rawValue ?? "")
                                .foregroundStyle(Color.oneLogMuted)
                        }
                    } else {
                        Text("수량을 모르면 충분히 있다고 가정하지 않고, 장보기 계산에서 확인 필요로 남겨요.")
                            .font(.footnote)
                            .foregroundStyle(Color.oneLogMuted)
                    }
                }
                Section {
                    Button("냉장고에 저장") {
                        let quantity = Double(quantityText) ?? 0
                        store.setInventory(ingredientID: ingredientID, quantity: isUnknown ? nil : quantity, unit: selectedIngredient?.defaultUnit ?? .count, status: isUnknown ? .unknown : .exact)
                        dismiss()
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.oneLogGreen)
                }
            }
            .navigationTitle(item == nil ? "재료 추가" : "수량 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
        }
    }
}
