//
//  Bool_To_Trash.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 31/07/2025.
//

import SwiftUI



struct BoolToImg: View {
    
    var value: Bool
    
    var body: some View {
        
        if value {
          Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.green)

        }
        else {
            Image(systemName: "xmark.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.red)
        }
    }
}



#Preview {
    BoolToImg(value: true)
}
