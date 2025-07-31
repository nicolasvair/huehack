//
//  0_welcome.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 09/04/2025.
//


// ajouter le pairing

// besoin de la fonction pour tout save (rules / autom / tout tout tout sur le bridge)
// donner un nom à la sauvegarde
// garder ce truc de sauvegarde dans un onglet ou dans les settings



import SwiftUI

struct _b2_welcome: View {
    
    @State private var configIsSaved = false
    
    var body: some View {
        
        ZStack{
            
            VStack{
                Text("Then, let's save your current configuration so you can revert back if needed")
                    .padding()
                
                HStack{
                    Button {
                        
                        // add function to save rules / sensors etc, evrything on the hub
                        configIsSaved.toggle()
                        
                    } label: {
                        Text("save current configuration")
                            .foregroundStyle(.white)
                            .padding()
                            .background(.blue)
                            .cornerRadius(15)
                    }
                    
                    BoolToImg(value:configIsSaved)
                    
                }
                .frame(height: 40)
            }
            
            VStack{
                Spacer()
                HStack{
                    Spacer()
                    Button_With_Icon(text: "next", icon: "arrowshape.right.circle", color: .fondClair)
                }
            }
            .padding()
        }
        

    }
}

#Preview {
    _b2_welcome()
}
