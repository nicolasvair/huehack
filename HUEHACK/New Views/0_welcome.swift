//
//  0_welcome.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 09/04/2025.
//

import SwiftUI

struct __welcome: View {
    
    @State private var configIsSaved = false
    
    var body: some View {
        Text("Welcome to huehack !")
            .font(.title)
            .padding()

        
        
        Text("1 - First, let's save your current configuration so you can revert back if needed")
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

        
        
        Text("2 - Do you want to keep your current configuration (and install HUEHACK alongside ) or start from scratch (delete current config) ?")
            .padding()
        
        HStack{
            
            Button {
                
                // add function to save rules / sensors etc, evrything on the hub
                
            } label: {
                ZStack{
                    Text("install above")
                        .foregroundStyle(.white)
                        .padding()
                        .background(.blue)
                        .cornerRadius(15)
                    
//                    Image(systemName:"checkmark.circle.fill")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(height:40)
//                        .background(.white)
//                        .cornerRadius(20)
//                        .foregroundStyle(.green)
//                        .position(x:160, y:50)
                }
            }

            
            Button {
                
                // add function to save rules / sensors etc, evrything on the hub
                configIsSaved.toggle()
                
            } label: {
                Text("delete current config")
                    .foregroundStyle(.white)
                    .padding()
                    .background(.red)
                    .cornerRadius(15)
            }
                        
        }
        .frame(height: 40)

        
        Text("3 - Install HUEHACK on bridge")
            .padding()
        
        HStack{
            
            Button {
                // add function to create sensors for general ON / OFF  and scheduler
            } label: {
                ZStack{
                    Text("install on bridge")
                        .foregroundStyle(.white)
                        .padding()
                        .background(.blue)
                        .cornerRadius(15)
                }
            }

        }
        .frame(height: 40)
        
        
        
        Text("4 - choose which rooms or lighs will be controlled by HUEHACK")
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
}

#Preview {
    __welcome()
}


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
