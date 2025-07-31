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


struct _b1_welcome: View {
        
    @StateObject var discovery = HueBridgeDiscovery()
    @StateObject var pairingManager = BridgePairingManager()

    let ip = UserDefaults.standard.string(forKey: "hueBridgeIP")
    @State private var textShownToUser = ""
    
    
    var body: some View {
        
        ZStack{
            
            VStack{

                Spacer()

                Text("First let's find the bridge on your network. Make sure to be on the same wifi network.")
                    .padding()
                
                
                
                HStack{
                                        
                    Button {
                        discovery.startDiscovery()
                        
                    } label: {
                        Text("Find bridge")
                            .foregroundStyle(.white)
                            .padding()
                            .background(.blue)
                            .cornerRadius(15)
                        
                    }
                    
                    if discovery.status == .searching {
                        ProgressView()
                    }
                    else if discovery.status == .found {
                        BoolToImg(value:true)
                    }
                    else if discovery.status == .failed {
                        BoolToImg(value:false)
                    }

                }
                .frame(height: 40)

                
                
                if ip != nil {
                    Text("bridge IP adress : \(ip ?? "not found") ")
                        .padding()
                }
                
                Spacer()
                
                Text("Then, let's pair with the bridge")
                    .padding()

                
                HStack{
                                        
                    Button {
                        guard let ip = ip else { return }
                        pairingManager.pairWithBridge(ip: ip)
                    } label: {
                        Text("Pair")
                            .foregroundStyle(.white)
                            .padding()
                            .background(.blue)
                            .cornerRadius(15)
                        
                    }
                    
                    if pairingManager.status == .inProgress {
                        ProgressView()
                    }
                    else if pairingManager.status == .success {
                        BoolToImg(value:true)
                    }
                    else if pairingManager.status == .error {
                        BoolToImg(value:false)
                    }

                }
                .frame(height: 40)
                
                
                Text(pairingManager.message)
                    .foregroundColor(pairingManager.status == .error ? .red : .green)
                    .padding()

                
                Spacer()
                
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
    _b1_welcome()
}
