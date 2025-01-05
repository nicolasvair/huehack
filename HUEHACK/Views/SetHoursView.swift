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

var indexGlobalTimer = 171
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
    
    @State private var nbOfSegments = 5
    @State var listOfSegments = [Segment]()
    @State var firstAppear = true
    @State var globalOnOff = true
    @State var groupsIndices = ["A", "B", "C"]
    @State var groups = [String : RoomResponse]()
    @State var selectedGroupIndex = "select a group"
    
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
                List(listOfSegments.indices, id: \.self) { index in
                    NavigationLink {
                        EditSegment(index: index, listOfSegments: $listOfSegments)
                    } label: {
                        HStack{
                            let segment = listOfSegments[index]
                            Text("\(String(segment.hourStart.hour!))h\(String(format: "%02d", segment.hourStart.minute!)) - \(segment.temp.miredsToKelvin) °K")
                                .italic(segment.synced == .synced ? false : true)
                                .fontWeight(segment.synced == .synced ? .regular : .light)
                            Spacer()
                            Rectangle()
                                .frame(width: 50)
                                .foregroundStyle(Color.init(mireds: Double(segment.temp)))
                                .padding()
                        }
                    }
                }
                .refreshable {
                    await sendGETGroups(ip: ip, which: nil) { response in
                        groupsIndices = response.map { $0.key }
                        groups = response
                        getSegmentFromRulesForGroup(selectedGroupIndex: Int(selectedGroupIndex)!){ response in
                            listOfSegments = response
                            nbOfSegments = listOfSegments.count
                        }
                    }
                }
            } else {
                Text("select a group")
            }
            
            
        }
        
        
        Spacer()
        
        HStack{
            
            Stepper(value: $nbOfSegments, in: 1...10) {
                HStack {
                    Text(String(nbOfSegments))
                    Text("Segments")
                }
            }
            .frame(width:210)
            .padding(.horizontal)
            .onChange(of: nbOfSegments) { oldValue, newValue in
                switch newValue {
                case 1:
                    listOfSegments = list1
                case 2:
                    listOfSegments = list2
                case 3:
                    listOfSegments = list3
                case 4:
                    listOfSegments = list4
                case 5:
                    listOfSegments = list5
                case 6:
                    listOfSegments = list6
                case 7:
                    listOfSegments = list7
                case 8:
                    listOfSegments = list8
                case 9:
                    listOfSegments = list9
                case 10:
                    listOfSegments = list10
                default:
                    listOfSegments = defaultListOfSegments // Une liste vide si `nbOfSegments` est en dehors des valeurs attendues
                }
            }
            Button {
                listOfSegments = defaultListOfSegments
                nbOfSegments = 5
            } label: {
                Text("Default")
            }
            
            Button {
                sendPUTGroupRequest(ip: ip, groupIndex: 81, ct: 400) { response in
                    print(response)
                }
            } label: {
                Text("test")
            }


        }
        HStack{
            Toggle(isOn: $globalOnOff) {
                Text("HUEHACK")
            }
            .frame(width:140)
            
            Button {
                createRulesFromlistOfSegments(listOfSegments: listOfSegments, indexGroup: Int(selectedGroupIndex)!)
                
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
            sendGlobalOnOff(ip: ip, indexGlobalOnOff: indexGlobalTimer, indexTimer: indexTimer, state: state) { response in
                print(response)
            }
        }

        
    }
    
}






#Preview {
    NavigationStack{
        SetHoursView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
