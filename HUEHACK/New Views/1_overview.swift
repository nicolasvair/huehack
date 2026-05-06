//
//  1_overview.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 09/04/2025.
//

import SwiftUI

struct __overview: View {

    @State private var globalOn = true
    @State private var isLoadingState = true

    var body: some View {
        VStack {
            HStack {
                Toggle("HUEHACK actif", isOn: $globalOn)
                    .frame(width: 220)
                    .disabled(isLoadingState)
                    .padding()
                if isLoadingState { ProgressView() }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(100)), count: 3)) {
                SceneSquare(colorTemp: 300, name: "cinéma")
                SceneSquare(colorTemp: 200, name: "don't sleep")

                Button {
                } label: {
                    Image(systemName: "plus")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.gray)
                        .padding()
                        .frame(width: 100, height: 80)
                        .background(.gray.opacity(0.3))
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .onAppear {
            sendGETSensors(ip: ip, which: String(indexGlobalOnOff)) { response in
                if let sensor = response.values.first, let status = sensor.state.status {
                    globalOn = status == 0
                }
                isLoadingState = false
            }
        }
        .onChange(of: globalOn) { _, newValue in
            let state = newValue ? 0 : 1
            sendGlobalOnOff(ip: ip, indexGlobalOnOff: indexGlobalOnOff, indexTimer: indexTimer, state: state) { _ in }
        }
    }
}

#Preview {
    __overview()
}

struct SceneSquare: View {

    let colorTemp: Int?
    let name: String?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(mireds: Double(colorTemp!)))
                .frame(width: 100, height: 80)
                .cornerRadius(10)
            Text(name!)
        }
    }
}
