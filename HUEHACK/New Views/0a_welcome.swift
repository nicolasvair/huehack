//
//  0_welcome.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 09/04/2025.
//


import SwiftUI

struct _a_welcome: View {
    
    @State private var configIsSaved = false
    
    var body: some View {
        
        Text("Welcome to huehack !")
            .font(.title)
            .padding()

        
        
        Text("This app let you sync your hue lights with the sun (circadian lighting) using nothing more than your hue bridge ! No need to buy additionnal \"intelligent\" switch, no need to connect with home assistant or any other device.")
            .padding()
        
        Text("Because the lights are not powered when they are switched off, they can't update their color continuously. But you can set the light state by polling the bridge periodically. I use 5s without issues.")
            .padding()
        
        Text("I designed this app around ths \"hack\" because it's long to setup manually and even longer to adapt to the sun each season.")
            .padding()
        
        Text("With HueHack, everything is done in less than 5mn and you can update it easily when the seasons change (it won't adapt automatically though).")
            .padding()
        
        VStack{
            Spacer()
            HStack{
                Spacer()
                NavigationLink {
                    _b_welcome()
                        .navigationTitle("Connexion au bridge")
                } label: {
                    Button_With_Icon(text: "next", icon: "arrowshape.right.circle", color: .fondClair)
                }
            }
        }
        .padding()


    }
}

#Preview {
    _a_welcome()
}
