
//
//  ImportStatusView.swift
//  PVUI
//
//  Created by David Proskin on 10/31/24.
//

import SwiftUI
import PVLibrary

public protocol ImportStatusDelegate : AnyObject {
    func dismissAction()
    func addImportsAction()
    func forceImportsAction()
}

func iconNameForFileType(_ type: FileType) -> String {
    
    switch type {
        case .bios:
            return "bios_filled"
        case .artwork:
            return "prov_snes_icon"
        case .game:
            return "prov_snes_icon"
        case .cdRom:
            return "prov_ps1_icon"
        case .unknown:
            return "questionMark"
    }
}

func iconNameForStatus(_ status: ImportStatus) -> String {
    switch status {
        
    case .queued:
        return "xmark.circle.fill"
    case .processing:
        return "progress.indicator"
    case .success:
        return "checkmark.circle.fill"
    case .failure:
        return "exclamationmark.triangle.fill"
    case .conflict:
        return "exclamationmark.triangle.fill"
    }
}

// Individual Import Task Row View
struct ImportTaskRowView: View {
    let item: ImportQueueItem
    @State private var isNavigatingToSystemSelection = false
    
    var body: some View {
        HStack {
            //TODO: add icon for fileType
            VStack(alignment: .leading) {
                Text(item.url.lastPathComponent)
                    .font(.headline)
                if item.fileType == .bios {
                    Text("BIOS")
                        .font(.subheadline)
                        .foregroundColor(item.status.color)
                }
                else if let targetSystem = item.targetSystem() {
                    Text(targetSystem.name)
                        .font(.subheadline)
                        .foregroundColor(item.status.color)
                } else if !item.systems.isEmpty {
                    Text("\(item.systems.count) systems")
                        .font(.subheadline)
                        .foregroundColor(item.status.color)
                }
                
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                if item.status == .processing {
                    ProgressView().progressViewStyle(.circular).frame(width: 40, height: 40, alignment: .center)
                } else {
                    Image(systemName: iconNameForStatus(item.status))
                        .foregroundColor(item.status.color)
                }
                
                if (item.childQueueItems.count > 0) {
                    Text("+\(item.childQueueItems.count) files")
                        .font(.subheadline)
                        .foregroundColor(item.status.color)
                }
            }
            
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
        .onTapGesture {
                    if item.status == .conflict {
                        isNavigatingToSystemSelection = true
                    }
                }
                .background(
                    NavigationLink(destination: SystemSelectionView(item: item), isActive: $isNavigatingToSystemSelection) {
                        EmptyView()
                    }
                    .hidden()
                )
    }
}

struct ImportStatusView: View {
    @ObservedObject var updatesController: PVGameLibraryUpdatesController
    var gameImporter:GameImporter
    weak var delegate:ImportStatusDelegate!
    
    var body: some View {
            NavigationView {
                ScrollView {
                    if gameImporter.importQueue.isEmpty {
                        Text("No items in the import queue")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(gameImporter.importQueue) { item in
                                ImportTaskRowView(item: item).id(item.id)
                            }
                        }
                        .padding()
                    }
                }
                .navigationTitle("Import Status")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading,
                                     content: {
                        Button("Done") { delegate.dismissAction()
                        }
                    })
                    ToolbarItemGroup(placement: .topBarTrailing,
                                     content:  {
                        Button("Add Files") {
                            delegate?.addImportsAction()
                        }
                        Button("Force") {
                            delegate?.forceImportsAction()
                        }
                    })
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
}

#Preview {

}