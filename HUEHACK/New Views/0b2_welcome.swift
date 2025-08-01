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
    
    @StateObject var apiManager = HueAPIManager()
            
    var body: some View {
        
        ZStack{
            
            VStack{
                Text("Then, let's save your current configuration so you can revert back if needed")
                    .padding()
                
                HStack{
                    Button {
                        apiManager.sendGET(what: .sensors, which: nil)
                    } label: {
                        Text("save sensors")
                            .foregroundStyle(.white)
                            .padding()
                            .background(.blue)
                            .cornerRadius(15)
                    }
                    
                    Button {
                        apiManager.sendGET(what: .rules, which: nil)
                    } label: {
                        Text("save rules")
                            .foregroundStyle(.white)
                            .padding()
                            .background(.blue)
                            .cornerRadius(15)
                    }

                    Button {
                        apiManager.sendGET(what: .lights, which: nil)
                    } label: {
                        Text("save lights")
                            .foregroundStyle(.white)
                            .padding()
                            .background(.blue)
                            .cornerRadius(15)
                    }
                }
                .frame(height: 40)

                
                HStack{
                    Button {
                        apiManager.sendGET(what: .groups, which: nil)
                    } label: {
                        Text("save groups")
                            .foregroundStyle(.white)
                            .padding()
                            .background(.blue)
                            .cornerRadius(15)
                    }

                    Button {
                        apiManager.sendGET(what: .config, which: nil)
                    } label: {
                        Text("save config")
                            .foregroundStyle(.white)
                            .padding()
                            .background(.blue)
                            .cornerRadius(15)
                    }

                    Button {
                        apiManager.sendGET(what: .schedules, which: nil)
                    } label: {
                        Text("save schedules")
                            .foregroundStyle(.white)
                            .padding()
                            .background(.blue)
                            .cornerRadius(15)
                    }

                    
//                    BoolToImg(value:configIsSaved)
                    
                }
                .frame(height: 40)
                
                
                HStack{
                    Button {
                        apiManager.sendGET(what: .scenes, which: nil)
                    } label: {
                        Text("save scenes")
                            .foregroundStyle(.white)
                            .padding()
                            .background(.blue)
                            .cornerRadius(15)
                    }

                    Button {
                        apiManager.sendGET(what: .resourcelinks, which: nil)
                    } label: {
                        Text("save resourcelinks")
                            .foregroundStyle(.white)
                            .padding()
                            .background(.blue)
                            .cornerRadius(15)
                    }
                    
                    Button {
                        apiManager.sendGETall()
                    } label: {
                        Text("save all")
                            .foregroundStyle(.white)
                            .padding()
                            .background(.blue)
                            .cornerRadius(15)
                    }

                    
//                    BoolToImg(value:configIsSaved)
                    
                }
                .frame(height: 40)

                
                ScrollView{
                    Text("response :  \(apiManager.data)")
                }
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
