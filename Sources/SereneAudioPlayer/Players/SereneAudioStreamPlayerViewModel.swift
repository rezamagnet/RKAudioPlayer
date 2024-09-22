//
//  SereneAudioStreamPlayerViewModel.swift
//  SereneAudioPlayer
//
//  Created by Fatemeh Najafi Moghadam on 9/21/24.
//

import Foundation
import AVFoundation
import Combine

public final class SereneAudioStreamPlayerViewModel: ObservableObject {
    
    var cancellables: Set<AnyCancellable> = []
    @Published var isPlaying = false
    @Published var isFinished = false
    @Published var showingAlert = false
    @Published var isDownloading = false
    @Published var isSeen = false
    @Published var trackFavorited: Bool = false
    /// Display time that will be bound to the scrub slider.
    @Published var displayTime: TimeInterval = 0
    /// Amount time player is available
    @Published var itemDuration: TimeInterval = 0
    
    @Published var backgroundPlayer: AVPlayer?
    @Published var noisePlayer: AVPlayer?
    
    var displayTimeFormattedText: String {
        durationFormatter.string(from: displayTime)!
    }
    
    var displayItemDurationFormattedText: String {
        durationFormatter.string(from: itemDuration)!
    }
    
    private var likeAction: () -> Bool
    private var shareAction: () -> Void
    private var onDismiss: (Bool) -> Void
    private var onFinish: () -> Void
    
    private(set) var track: Track
    private var player: Player?
    var backgroundPlayerManager: BackgroundPlayerManager?
    private(set) var type: LayoutType
    private var folderName: String
    
    let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    public init(
        track: Track,
        folderName: String,
        type: LayoutType,
        likeAction: @escaping () -> Bool,
        shareAction: @escaping () -> Void,
        onDismiss: @escaping (Bool) -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.player = Player(track: track)
        self.type = type
        self.folderName = folderName
        self.track = track
        self.likeAction = likeAction
        self.shareAction = shareAction
        self.onDismiss = onDismiss
        self.onFinish = onFinish
        self.backgroundPlayerManager = BackgroundPlayerManager(track: track) { [weak self] backgroundVideo, noiseVideo in
            self?.backgroundPlayer = backgroundVideo
            self?.noisePlayer = noiseVideo
        }
        
        
        self.player?.displayTimeSubject
            .sink(receiveValue: { [weak self] time in
                self?.displayTime = time
            })
            .store(in: &cancellables)
        
        self.player?.itemDurationSubject
            .sink(receiveValue: { [weak self] time in
                self?.itemDuration = time
            })
            .store(in: &cancellables)
    }
    
    func updateScrub(_ scrub: PlayerScrubState) {
        player?.scrubState = scrub
    }
    
    func destroyAll() {
        player?.destroy()
        backgroundPlayerManager?.destroy()
    }
    
    func dismissAction() {
        onDismiss(isSeen)
    }
    
    func shareButtonAction() {
        shareAction()
    }
    
    func trackFavoritedAction() {
        trackFavorited = likeAction()
    }
    
    func checkIfNetworkAvailable() {
        showingAlert = !InternetConnectionManager.isConnectedToNetwork()
    }
    
    func appearAction() {
        checkIfNetworkAvailable()
        
        // MARK: - sound player handle
        player?.onStart = { [weak self] in
            self?.player?.play()
            self?.isPlaying = true
        }
        
        player?.onFinish = { [weak self] in
            if self?.type == .music {
                self?.player?.playFromBeginning()
            } else {
                self?.backgroundPlayerManager?.pause()
                self?.backgroundPlayerManager?.destroy()
                self?.player?.pause()
                self?.isFinished = true
                self?.onFinish()
            }
        }
        
        player?.onStart = { [weak self] in
            self?.backgroundPlayerManager?.play()
            self?.isPlaying = true
        }
        
        player?.onPause = { [weak self] in
            self?.backgroundPlayerManager?.pause()
            self?.isPlaying = false
        }
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if isPlaying {
                if player?.getPercentComplete ?? 0 > 75 {
                    isSeen = true
                }
            }
        }
        
        player?.play()
    }
}

extension SereneAudioStreamPlayerViewModel {
    private var playerIsPlaying: Bool { player?.isPlaying ?? false }
    var isPlayerDurationMoreThanZero: Bool { player?.itemDurationSubject.value ?? 0 > 0 }
    
    func playAction() {
        player?.play()
        
        if InternetConnectionManager.isConnectedToNetwork() {
            
            if isPlaying {
                backgroundPlayerManager?.pause()
                player?.pause()
                isPlaying = false
            } else {
                backgroundPlayerManager?.play()
                player?.play()
                isPlaying = true
            }
        } else {
            checkIfNetworkAvailable()
        }
    }
    
    func rewindAction() {
        player?.backward()
    }
}

// MARK: - Download
extension SereneAudioStreamPlayerViewModel {
    func downloadAndSaveAudioFile(_ audioFile: String, completion: @escaping (String) -> Void) {
        
        self.isDownloading.toggle()
        
        //Create directory if not present
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.libraryDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let documentDirectory = paths.first! as NSString
        let soundDirPathString = documentDirectory.appendingPathComponent(folderName)
        
        do {
            try FileManager.default.createDirectory(atPath: soundDirPathString, withIntermediateDirectories: true, attributes:nil)
            print("directory created at \(soundDirPathString)")
        } catch let error as NSError {
            print("error while creating dir : \(error.localizedDescription)");
        }
        
        if let audioUrl = URL(string: audioFile) {
            // create your document folder url
            let documentsUrl =  FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first! as URL
            let documentsFolderUrl = documentsUrl.appendingPathComponent(folderName)
            // your destination file url
            let destinationUrl = documentsFolderUrl.appendingPathComponent(audioUrl.lastPathComponent)
            
            print(destinationUrl)
            // check if it exists before downloading it
            if FileManager().fileExists(atPath: destinationUrl.path) {
                print("The file already exists at path")
                self.isDownloading.toggle()
            } else {
                //  if the file doesn't exist
                //  just download the data from your url
                DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async(execute: {
                    if let myAudioDataFromUrl = try? Data(contentsOf: audioUrl){
                        // after downloading your data you need to save it to your destination url
                        if (try? myAudioDataFromUrl.write(to: destinationUrl, options: [.atomic])) != nil {
                            print("file saved")
                            completion(destinationUrl.absoluteString)
                            self.isDownloading.toggle()
                        } else {
                            print("error saving file")
                            completion("")
                        }
                    }
                })
            }
        }
    }
}
