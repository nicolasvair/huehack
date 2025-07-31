//
//  0_welcome.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 09/04/2025.
//



// ajouter un warning "en cas de install alonside, peut causer des conflits avec d'autres règles". En cas de conflits revenez à votre sauvegarde.




import SwiftUI

struct _c_welcome: View {
    
    @State private var configIsSaved = false
    
    var body: some View {
        
        ZStack{
            
            VStack{
                Text("Do you want to keep your current configuration (and install HUEHACK alongside ) or start from scratch (delete current config) ?")
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
                            
                            Image(systemName:"checkmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(height:40)
                                .background(.white)
                                .cornerRadius(20)
                                .foregroundStyle(.green)
                                .position(x:160, y:50)
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
    _c_welcome()
}
