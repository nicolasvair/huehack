//
//  PairingView.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 04/01/2025.
//

import Foundation
import SwiftUI


struct PairingView: View {
        
    @State private var textShownToUser = ""
    
    
    
    var body: some View {


        Button {
            sendPairRequest(ip: ip) { response in
                textShownToUser = response
            }
        } label: {
            Text("Pairing request")
                .padding()
        }

    
        ScrollView {
            Text(textShownToUser)
                .font(.body)
                .padding()
        }
        .frame(width: 300, height: 400)
        .border(Color.gray, width: 1)
        .padding(.horizontal)



    }
    
}




#Preview {
    PairingView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
