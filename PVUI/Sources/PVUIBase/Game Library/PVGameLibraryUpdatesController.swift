//
//  PVGameLibraryUpdatesController.swift
//  Provenance
//
//  Created by Dan Berglund on 2020-06-11.
//  Copyright © 2020 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVLibrary
import PVPrimitives
import RxSwift
import RxCocoa
import CoreSpotlight
import PVRealm
import RealmSwift
import PVLogging
import PVFileSystem
import DirectoryWatcher

// Responsible for handling updates to game library, finding conflicts and resolving them
public struct PVGameLibraryUpdatesController {
    public let hudState: Observable<HudState>
    public let hudStateWatcher: Observable<HudState>
    public let conflicts: Observable<[Conflict]>
    
    private let gameImporter: GameImporter
    private let gameImporterEvents: Observable<GameImporter.Event>
    private let updateConflicts = PublishSubject<Void>()
    
    public enum HudState {
        case hidden
        case title(String)
        case titleAndProgress(title: String, progress: Float)
    }
    
    // TODO: Would be nice to inject the DirectoryWatcher as well
    public init(gameImporter: GameImporter, importPath: URL? = nil, scheduler: SchedulerType = MainScheduler.asyncInstance) async {
        var importPath = importPath
        if importPath == nil {
            importPath = Paths.romsImportPath
        }
        guard let importPath = importPath else {
            ELOG("No import path?")
            fatalError("No import path?")
        }
        self.gameImporter = gameImporter
        self.gameImporterEvents = Reactive(gameImporter).events.share()
        
        let directoryWatcher = RxDirectoryWatcher(directory: importPath)
        let directoryWatcherExtractedFiles = directoryWatcher.events.finishedExtracting(at: importPath)
        
        let initialScan: Observable<[URL]> = gameImporterEvents
            .filter { $0 == .initialized }
            .map { _ in try FileManager.default.contentsOfDirectory(at: importPath, includingPropertiesForKeys: nil, options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants])}
            .filter { !$0.isEmpty }
        
        let filesToImport = Observable.merge(initialScan, directoryWatcherExtractedFiles)
        
        // We use a hacky combineLatest here since we need to do the bind to `gameImporter.startImport` somewhere, so we hack it into the hudState definition
        // bind hudState to hudState, separate from startImport
        let o1 = Self.hudStateInit(from: directoryWatcher, gameImporterEvents: gameImporterEvents, scheduler: scheduler)
        let o2 = filesToImport.do(onNext: gameImporter.startImport)
        self.hudState = Observable.combineLatest(o1, o2) { _hudState, _ in return _hudState }
        self.hudStateWatcher = o1
        let gameImporterConflicts = gameImporterEvents
            .compactMap({ event -> Void? in
                if case .completed = event {
                    return ()
                }
                return nil
            })
        #warning("TODO: Finish this, using combine instead of Rx")
        #if false
        Task.detached {
            let _systemDirsConflicts = Observable
                .just(PVSystem.all.map { $0 })
                .map({ systems -> [(System, [URL])] in
                    Task {
                        await systems
                            .asyncMap { await $0.asDomain() }
                            .compactMap { system in
                                guard let candidates = FileManager.default.candidateROMs(for: system) else { return nil }
                                return (system, candidates)
                            }
                    }.value
                })
                .flatMap({ systems -> Observable<Void> in
                    Observable.concat(systems.map { system, paths in
                        Observable.create { observer in
                            gameImporter.getRomInfoForFiles(atPaths: paths, userChosenSystem: system)
                            observer.onCompleted()
                            return Disposables.create()
                        }
                    })
                })
        }
        
        let potentialConflicts = Observable.merge( gameImporterConflicts, updateConflicts ).startWith(())
        conflicts = potentialConflicts
            .map { gameImporter.conflictedFiles ?? [] }
            .map({ filesInConflictsFolder -> [Conflict] in
                PVEmulatorConfiguration.sortImportURLs(urls: filesInConflictsFolder)
                    .map { file in (
                        path: file,
                        candidates: RomDatabase.sharedInstance.getSystemCache().values
                            .filter{ $0.supportedExtensions.contains(file.pathExtension.lowercased() )}
                            .map{ $0.asDomain() }
                        //PVSystem.all.filter { $0.supportedExtensions.contains(file.pathExtension.lowercased() )}.map { $0.asDomain() }
                    )
                    }
            })
            .map { conflicts in conflicts.filter { !$0.candidates.isEmpty }}
            .share(replay: 1, scope: .forever)
        #else
        conflicts = .just([])
        #endif
    }
    
    public func importROMDirectories() async {
        ILOG("PVGameLibrary: Starting Import")
        RomDatabase.sharedInstance.reloadCache()
        RomDatabase.sharedInstance.reloadFileSystemROMCache()
        let dbGames: [AnyHashable: PVGame] = RomDatabase.sharedInstance.getGamesCache()
        let dbSystems: [AnyHashable: PVSystem] = RomDatabase.sharedInstance.getSystemCache()
        let disposeBag = DisposeBag()
        await dbSystems.values.asyncForEach({ system in
            ILOG("PVGameLibrary: Importing \(system.identifier)")
            let files = await RomDatabase.sharedInstance.getFileSystemROMCache(for: system)
            let newGames = files.keys.filter({
                return dbGames.index(forKey:
                                        (system.identifier as NSString)
                    .appendingPathComponent($0.lastPathComponent)) == nil
            })
            if newGames.count > 0 {
                ILOG("PVGameLibraryUpdatesController: Importing \(newGames)")
                await GameImporter.shared.getRomInfoForFiles(atPaths: newGames, userChosenSystem: system.asDomain())
#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
                addImportedGames(to: CSSearchableIndex.default(), database: RomDatabase.sharedInstance).disposed(by: disposeBag)
#endif
            }
            ILOG("PVGameLibrary: Imported OK \(system.identifier)")
            
        })
        ILOG("PVGameLibrary: Import Complete")
    }
    
#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
    public func addImportedGames(to spotlightIndex: CSSearchableIndex, database: RomDatabase) -> Disposable {
        gameImporterEvents
            .compactMap({ event -> String? in
                if case .finished(let md5, _) = event {
                    return md5
                }
                return nil
            })
            .compactMap {
                let realm = try! Realm()
                return realm.object(ofType: PVGame.self, forPrimaryKey: $0)
//                return database.realm.object(ofType: PVGame.self, forPrimaryKey: $0)
            }
            .map { game in CSSearchableItem(uniqueIdentifier: game.spotlightUniqueIdentifier, domainIdentifier: "org.provenance-emu.game", attributeSet: game.spotlightContentSet) }
            .observe(on: SerialDispatchQueueScheduler(qos: .background))
            .subscribe(onNext: { item in
                spotlightIndex.indexSearchableItems([item]) { error in
                    if let error = error {
                        ELOG("indexing error: \(error)")
                    }
                }
            })
    }
#endif
    
    private static func hudStateInit(from directoryWatcher: RxDirectoryWatcher, gameImporterEvents: Observable<GameImporter.Event>, scheduler: SchedulerType) -> Observable<HudState> {
        let stateFromGameImporter = gameImporterEvents
            .compactMap({ event -> HudState? in
                switch event {
                case .initialized, .finishedArtwork, .completed:
                    return nil
                case .started(let path):
                    return .title("Checking Import: \(path.lastPathComponent)")
                case .finished:
                    return .title("Import Successful")
                }
            })
        
        func labelMaker(_ path: URL) -> String {
#if os(tvOS)
            return "Extracting Archive: \(path.lastPathComponent)"
#else
            return "Extracting Archive\n\(path.lastPathComponent)"
#endif
        }
        
        let stateFromDirectoryWatcher = directoryWatcher.events
            .flatMap({ event -> Observable<HudState> in
                switch event {
                case .started(let path):
                    return .just(.titleAndProgress(title: labelMaker(path), progress: 0))
                case .updated(let path, let progress):
                    return .just(.titleAndProgress(title: labelMaker(path), progress: progress))
                case .completed(let paths):
                    return Observable.merge(
                        .just(.titleAndProgress(title: paths != nil ? "Extraction Complete!" : "Extraction Failed.", progress: 1)),
                        Observable.just(.hidden).delay(.milliseconds(500), scheduler: scheduler)
                    )
                }
            })
        
        return Observable.merge(stateFromGameImporter, stateFromDirectoryWatcher)
    }
}

extension PVGameLibraryUpdatesController: ConflictsController {
    public func resolveConflicts(withSolutions solutions: [URL : System]) {
        Task {
            await gameImporter.resolveConflicts(withSolutions: solutions)
            updateConflicts.onNext(())
        }
    }
    public func deleteConflict(path: URL) {
        do {
            try FileManager.default.removeItem(at: path)
        } catch {
            ELOG("\(error.localizedDescription)")
        }
        updateConflicts.onNext(())
    }
}

extension Observable where Element == RxDirectoryWatcher.Event {
    // Emits the url:s once all archives has been extracted
    public func finishedExtracting(at path: URL) -> Observable<[URL]> {
        return compactMap({ event -> [URL]? in
            if case .completed(let paths) = event {
                return paths
            }
            return nil
        })
        .scan((extracted: [], extractionComplete: false), accumulator: { acc, extracted -> (extracted: [URL], extractionComplete: Bool) in
            let allExtracted = acc.extracted + extracted
            do {
                let remainingFiles = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                return (
                    extracted: allExtracted,
                    extractionComplete: remainingFiles.filter { $0.isArchive }.isEmpty
                )
            } catch {
                ELOG("\(error.localizedDescription)")
                return (
                    extracted: allExtracted,
                    extractionComplete: false
                )
            }
        })
        .filter { $0.extractionComplete }
        .map { $0.extracted }
    }
}

private extension FileManager {
    /// Returns a list of all the files in a systems directory that are potential ROMs (AKA has the correct extension)
    func candidateROMs(for system: System) -> [URL]? {
        let systemDir = system.romsDirectory
        
        // Check if a folder actually exists, nothing to do if it doesn't
        guard fileExists(atPath: systemDir.path) else {
            VLOG("Nothing found at \(systemDir.path)")
            return nil
        }
        guard let contents = try? contentsOfDirectory(at: systemDir, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]),
              !contents.isEmpty else {
            return nil
        }
        
        return contents.filter { system.extensions.contains($0.pathExtension) }
    }
}

package extension GameImporter {
    enum Event: Equatable {
        case initialized
        case started(path: URL)
        case finished(md5: String, modified: Bool)
        case finishedArtwork(url: URL?)
        case completed(encounteredConflicts: Bool)
    }
}

package extension Reactive where Base: GameImporter {
    var events: Observable<GameImporter.Event> {
        return Observable.create { observer in
            self.base.initialized.notify(queue: DispatchQueue.global(qos: .background)) {
                observer.onNext(.initialized)
            }
            
            self.base.importStartedHandler = { observer.onNext(.started(path: URL(fileURLWithPath: $0))) }
            self.base.finishedImportHandler = { observer.onNext(.finished(md5: $0, modified: $1)) }
            self.base.finishedArtworkHandler = { observer.onNext(.finishedArtwork(url: URL(fileURLWithPath: $0 ?? ""))) }
            self.base.completionHandler = { observer.onNext(.completed(encounteredConflicts: $0)) }
            
            return Disposables.create {
                self.base.importStartedHandler = nil
                self.base.finishedImportHandler = nil
                self.base.finishedArtworkHandler = nil
                self.base.completionHandler = nil
            }
        }
    }
}

public  struct RxDirectoryWatcher {
    public enum Event {
        case started(path: URL)
        case updated(path: URL, progress: Float)
        case completed(paths: [URL]?)
    }
    public let events: Observable<Event>
    public init(directory: URL) {
        events = Observable.create { observer in
            let internalWatcher = DirectoryWatcher(directory: directory,
                                                   extractionStartedHandler: { observer.onNext(.started(path: $0)) },
                                                   extractionUpdatedHandler: { observer.onNext(.updated(path: $0, progress: $3)) },
                                                   extractionCompleteHandler: { observer.onNext(.completed(paths: $0)) })
            internalWatcher.startMonitoring()
            return Disposables.create {
                internalWatcher.stopMonitoring()
            }
        }.share()
    }
}