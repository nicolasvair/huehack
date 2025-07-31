//
//  Button_With_Icon.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 31/07/2025.
//

import SwiftUI

struct Button_With_Icon: View {
    
    var text: String
    var icon: String
    var color: Color?
    
    var body: some View {
        
        HStack{
            Image(systemName: icon)
            Text(text)
        }
        .padding(20)
        .background(color ?? Color.white .opacity(0.8))
        .cornerRadius(15)
//        .rounded
    }
}

#Preview {
    Button_With_Icon(text: "send to bridge", icon: "square.and.arrow.up")
}
