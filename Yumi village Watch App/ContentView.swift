//
//  ContentView.swift
//  Yumi village Watch App
//

import SwiftUI

struct ContentView: View {
    // Сколько домов и сколько дерева на складе
    @State private var houses = 3
    @State private var wood = 12

    // Деревня — это просто ряд домиков, по одному на каждый дом
    private var village: String {
        String(repeating: "🏡", count: min(houses, 6))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("юмии")
                    .font(.system(.headline, design: .rounded))

                Text(village)
                    .font(.system(size: 30))

                Divider()

                HStack {
                    Label("\(houses)", systemImage: "house.fill")
                    Spacer()
                    Label("\(wood)", systemImage: "leaf.fill")
                }
                .font(.footnote)

                Button {
                    if wood >= 4 {
                        wood -= 4
                        houses += 1
                    }
                } label: {
                    Text("Построить дом")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(wood < 4)
            }
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    ContentView()
}
