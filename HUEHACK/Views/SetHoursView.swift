//
//  SetHoursView.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 04/01/2025.
//


import Foundation
import SwiftUI

var ip = "192.168.1.121"
var username = "MN07hphqoytdZ5mWmnEuXKknn8tfc27IXW5wVbkH"

var indexGlobalOnOff = 171
var indexTimer = 172




struct Segment: Identifiable {
    var id = UUID()
    
    var name: String
    var hourStart: DateComponents // Représente uniquement l'heure et les minutes
    var temp: Int
    var synced: Synced
}

enum Synced {
    case synced, notSynced
}


struct SetHoursView: View {
    
    @State var listOfSegments = [Segment]()
    @State var firstAppear = true
    @State var globalOnOff = true
    @State var groupsIndices = ["A", "B", "C"]
    @State var groups = [String : RoomResponse]()
    @State var selectedGroupIndex = "select a group"
    
    @State private var showAlert = false
    @State private var alertMessage = "Something went wrong!"
    
    var body: some View {
        
        VStack{
            
            Picker("Test", selection: $selectedGroupIndex) {
                ForEach(groupsIndices.sorted(), id:\.self) { groupIndice in
                    if let nameOfGroup = groups[groupIndice]?.name {
                        Text("\(nameOfGroup)")
                    }
                }
            }
            .onChange(of: selectedGroupIndex) { oldValue, newValue in
                getSegmentFromRulesForGroup(selectedGroupIndex: Int(selectedGroupIndex)!){ response in
                    listOfSegments = response
                }
            }
            .pickerStyle(.palette)
            
            if let selectedGroup = groups[selectedGroupIndex] {
                Text("lights : \(selectedGroup.lights.joined(separator: ", "))")
            }
            
            
            if let selectedGroup = groups[selectedGroupIndex] {
                List {
                    ForEach(listOfSegments.indices, id: \.self) { index in
                        NavigationLink {
                            EditSegment(index: index, listOfSegments: $listOfSegments)
                        } label: {
                            HStack {
                                let segment = listOfSegments[index]
                                Text("\(String(segment.hourStart.hour!))h\(String(format: "%02d", segment.hourStart.minute!)) - \(segment.temp.miredsToKelvin) °K")
                                    .italic(segment.synced == .synced ? false : true)
                                    .fontWeight(segment.synced == .synced ? .regular : .light)
                                Spacer()
                                Rectangle()
                                    .frame(width: 50)
                                    .foregroundStyle(Color(mireds: Double(segment.temp)))
                                    .padding()
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            listOfSegments.remove(at: index)
                        }
                    }
                }
                .refreshable {
                    await sendGETGroups(ip: ip, which: nil) { response in
                        groupsIndices = response.map { $0.key }
                        groups = response
                        getSegmentFromRulesForGroup(selectedGroupIndex: Int(selectedGroupIndex)!){ response in
                            listOfSegments = response
                        }
                    }
                }
            } else {
                Text("select a group")
            }
            
            
        }
        
        
        Spacer()
        
        HStack{
            Button {
                createSegmentForNow(listOfSegments: &listOfSegments)
            } label: {
                Text("Create Segment for Now")
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button {
                Task {
                    await sendGETGroups(ip: ip, which: nil) { response in
                        groupsIndices = response.map { $0.key }
                        groups = response
                        getSegmentFromRulesForGroup(selectedGroupIndex: Int(selectedGroupIndex)!) { response in
                            listOfSegments = response
                        }
                    }
                }
            } label: {
                Text("Cancel")
            }
            .padding(.horizontal)
            
        }


        HStack{
            Toggle(isOn: $globalOnOff) {
                Text("HUEHACK")
            }
            .frame(width:140)
            
            Button {                
                createRulesFromlistOfSegments(listOfSegments: listOfSegments, indexGroup: Int(selectedGroupIndex)!) { responses in
//                    print(responses)
                    alertMessage = responses
                    showAlert = true
                }
                
            } label: {
                HStack{
                    Text("Send rules to bridge")
                    Image(systemName: "square.and.arrow.up.fill")
                }
                .padding()

            }
            
        }

        .onAppear {
            if firstAppear {
//                listOfSegments = defaultListOfSegments
                firstAppear = false
            }
            
            sendGETGroups(ip: ip, which: nil) { response in
                groupsIndices = response.map { $0.key }
                groups = response
                //                print(groups)
            }
            
            
        }
        .onChange(of: globalOnOff) { oldValue, newValue in
            let state = globalOnOff ? 0 : 1
            sendGlobalOnOff(ip: ip, indexGlobalOnOff: indexGlobalOnOff, indexTimer: indexTimer, state: state) { response in
                print(response)
            }
        }
        .alert("Response from bridge", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }

        
    }
    
}






#Preview {
    NavigationStack{
        SetHoursView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
