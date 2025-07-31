//
//  0e_welcome.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 31/07/2025.
//

import SwiftUI

struct _e_welcome: View {
    var body: some View {
        
        ZStack{
            
            VStack{

                Text("Install HUEHACK on bridge")
                    .padding()

                
                HStack{
                    
                    Button {
                        // add function to create sensors for general ON / OFF  and scheduler
                    } label: {
                        Button_With_Icon(text: "Install HUEHACK on bridge", icon: "square.and.arrow.up", color: .fondClair)
                    }
                    
                }
                .frame(height: 40)
            }
            
            VStack{
                Spacer()
                HStack{
                    Spacer()
                    Button_With_Icon(text: "next", icon: "arrowshape.right", color: .fondClair)
                }
            }
            .padding()
        }
    }
}

#Preview {
    _e_welcome()
}

