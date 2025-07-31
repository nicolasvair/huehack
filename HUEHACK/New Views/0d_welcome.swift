//
//  0_welcome.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 09/04/2025.
//



// choisir une room, toutes les lights de la room sont sélectionnées, on peut les déselectionner
// ou bien choisir les lights directement ? à voir selon format exploration, au + simple




import SwiftUI

struct _d_welcome: View {
    
    @State private var configIsSaved = false
    
    var body: some View {
 
        ZStack{
            VStack{
                Text("Choose which rooms or lighs will be controlled by HUEHACK")
                    .padding()
                
                HStack{
                    
                    let listRooms = ["Living room", "Bedroom", "Kitchen", "Bathroom"]
                    
                    let listLights = ["Living room light", "Bedroom light", "Kitchen light", "Bathroom light"]
                    
                    var isTapped = false
                    
                    HStack{
                        VStack{
                            Text("Rooms")
                                .font(.title3)
                            
                            ScrollView{
                                ForEach(listRooms, id:\.self) { roomName in
                                    Text(roomName)
                                        .padding(5)
                                        .foregroundStyle(isTapped ? .red : .black)
                                }
                            }
                            .background(.gray.opacity(0.3))
                            .cornerRadius(10)
                            //                    .padding()
                            //                    .frame(height:150)
                        }
                        
                        VStack{
                            Text("Lights")
                                .font(.title3)
                            
                            ScrollView{
                                ForEach(listLights, id:\.self) { roomName in
                                    Text(roomName)
                                        .padding(5)
                                        .foregroundStyle(isTapped ? .red : .black)
                                }
                            }
                            .background(.gray.opacity(0.3))
                            .cornerRadius(10)
                            //                    .padding()
                            //                    .frame(height:150)
                        }
                        
                    }
                    
                }
                .frame(height: 200)
                
            }
            
            VStack{
                Spacer()
                HStack{
                    Spacer()
                    Button_With_Icon(text: "Install HUEHACK on bridge", icon: "square.and.arrow.up", color: .fondClair)
                }
            }
            .padding()
        }
        


    }
}

#Preview {
    _d_welcome()
}
