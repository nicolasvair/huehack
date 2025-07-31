//
//  1_overview.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 09/04/2025.
//

// ajouter capture d'un état, d'une scène et tester combinaison avec autres applis


import SwiftUI

struct __overview: View {
    
    @State var globalOn = true
    @State var globalDim = 1.0

    var body: some View {
        Toggle("globalOn", isOn: $globalOn)
            .frame(width:200)
            .padding()
        
        Text("global dim : ")
        Slider(value: $globalDim)
            .frame(width:250)

        LazyVGrid (columns: Array(repeating: GridItem(.fixed(100)), count: 3)){
            
            SceneSquare(colorTemp: 300, name: "cinéma")
            SceneSquare(colorTemp: 200, name: "don't sleep")
            
            Button {
                // function to create a scene
            } label: {
                Image(systemName: "plus")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.gray)
                    .padding()
                    .frame(width: 100, height: 80)
                    .background(.gray .opacity(0.3))
                    .cornerRadius(10)

            }


        }
        .padding()
        
    }
}

#Preview {
    __overview()
}

struct SceneSquare: View {
    
    let colorTemp: Int?
    let name: String?
    
    var body: some View {
        
        ZStack{
            Rectangle()
                .fill(Color(mireds: Double(colorTemp!)))
                .frame(width: 100, height: 80)
                .cornerRadius(10)
            Text(name!)
        }
    }
}
