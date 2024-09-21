//
//  Player.swift
//  SwiftUIAVPlayer
//
//  Created by Jon Gary on 7/13/20.
//  Copyright © 2020 Jon Gary. All rights reserved.
//

import AVFoundation
import Combine
import MediaPlayer

let timeScale = CMTimeScale(1000)
let time = CMTime(seconds: 0.5, preferredTimescale: timeScale)

enum PlayerScrubState {
    case reset
    case scrubStarted
    case scrubEnded(TimeInterval)
}

/// AVPlayer wrapper to publish the current time and
/// support a slider for scrubbing.
final class Player {
    
    private let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var isOSMediaInfoActivated = false
    private var track: Track
    
    private var streamURL: URL {
        let urlString = self.track.streamURL
        
        let encodedSoundString = urlString?.removingPercentEncoding?.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
        
        let url = URL(string: encodedSoundString!)!
        
        return url
    }
    
    /// Display time that will be bound to the scrub slider.
//    var displayTime: TimeInterval = 0
    var displayTimeSubject: CurrentValueSubject<TimeInterval, Never> = .init(0)
    
    
    /// The observed time, which may not be needed by the UI.
    var observedTime: TimeInterval = 0
    
    var itemDurationSubject: CurrentValueSubject<TimeInterval, Never> = .init(0)
    fileprivate var itemDurationKVOPublisher: AnyCancellable?
    
    /// Publish timeControlStatus
    var timeControlStatus: AVPlayer.TimeControlStatus = .paused
    fileprivate var timeControlStatusKVOPublisher: AnyCancellable?
    
    /// The AVPlayer
    fileprivate var avPlayer: AVPlayer?
    
    var isPlaying: Bool { avPlayer?.isPlaying == true }
    
    var rate: Float { avPlayer?.rate ?? 0}
    
    var currentTime: CMTime {
        avPlayer?.currentTime() ?? .zero
    }
    
    private var playerItemBufferKeepUpObserver: NSKeyValueObservation?
    
    var onStart: (() -> Void) = { }
    var onFinish: (() -> Void) = { }
    
    var onPlay: (() -> Void) = { }
    var onPause: (() -> Void) = { }
    
    func seekToBegin() {
        avPlayer?.seek(to: .zero)
    }
    
    func seekTo(time: CMTime) {
        avPlayer?.seek(to: time)
    }
    
    func playFromBeginning() {
        seekToBegin()
        play()
    }
    
    func backward() {
        var timeBackward = displayTimeSubject.value
        timeBackward -= 15
        avPlayer?.seek(to: CMTime(seconds: timeBackward, preferredTimescale: currentTime.timescale))
    }
    
    var getPercentComplete: Double {
        guard itemDurationSubject.value > 0 else { return 0 } // Handle cases where total duration is 0
        return (displayTimeSubject.value / itemDurationSubject.value) * 100
    }
    
    /// Time observer.
    fileprivate var periodicTimeObserver: Any?
    
    var scrubState: PlayerScrubState = .reset {
        didSet {
            switch scrubState {
            case .reset:
                return
            case .scrubStarted:
                return
            case .scrubEnded(let seekTime):
                avPlayer?.seek(to: CMTime(seconds: seekTime, preferredTimescale: 1000))
            }
        }
    }
    
    init(track: Track) {
        self.track = track
        let playerItem = AVPlayerItem(url: streamURL)
        self.avPlayer = AVPlayer(playerItem: playerItem)
        self.addPeriodicTimeObserver()
        self.addTimeControlStatusObserver()
        self.addItemDurationPublisher()
        startItemObserver()
        finishItemObserver()
    }
    
    func play() {
        self.avPlayer?.play()
    }
    
    func destroy() {
        pause()
        avPlayer = nil
        removePeriodicTimeObserver()
        timeControlStatusKVOPublisher?.cancel()
        timeControlStatusKVOPublisher = nil
        itemDurationKVOPublisher?.cancel()
        itemDurationKVOPublisher = nil
        playerItemBufferKeepUpObserver = nil
        NotificationCenter.default.removeObserver(self)
        commandCenter.playCommand.removeTarget(self)
        commandCenter.pauseCommand.removeTarget(self)
    }
    
    func pause() {
        self.avPlayer?.pause()
    }
    
    private func startItemObserver() {
        playerItemBufferKeepUpObserver = avPlayer?.currentItem?.observe(\AVPlayerItem.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] _,_  in
            guard let self else { return }
            if !isOSMediaInfoActivated {
                setupNowPlaying(track: track)
                isOSMediaInfoActivated = true
            }
            self.onStart()
        }
    }
    
    private func finishItemObserver() {
        NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: avPlayer?.currentItem, queue: .main) { [weak self] _ in
            self?.nowPlayingInfoCenter.nowPlayingInfo = nil
            self?.onFinish()
        }
    }
    
    fileprivate func addPeriodicTimeObserver() {
        self.periodicTimeObserver = avPlayer?.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] (time) in
            guard let self = self else { return }
            
            // Always update observed time.
            self.observedTime = time.seconds
            
            switch self.scrubState {
            case .reset:
                displayTimeSubject.send(time.seconds)
            case .scrubStarted:
                // When scrubbing, the displayTime is bound to the Slider view, so
                // do not update it here.
                break
            case .scrubEnded(let seekTime):
                self.scrubState = .reset
                displayTimeSubject.send(seekTime)
            }
        }
    }
    
    fileprivate func removePeriodicTimeObserver() {
        guard let periodicTimeObserver = self.periodicTimeObserver else {
            return
        }
        avPlayer?.removeTimeObserver(periodicTimeObserver)
        self.periodicTimeObserver = nil
    }
    
    fileprivate func addTimeControlStatusObserver() {
        timeControlStatusKVOPublisher = avPlayer?
            .publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] (newStatus) in
                self?.timeControlStatus = newStatus
            })
    }
    
    fileprivate func addItemDurationPublisher() {
        itemDurationKVOPublisher = avPlayer?
            .publisher(for: \.currentItem?.duration)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] (newStatus) in
                guard let newStatus = newStatus else { return }
                self?.itemDurationSubject.send(newStatus.seconds)
            })
    }
}

extension Player {
    func setupRemoteTransportControls() {
        // Add handler for Play Command
        commandCenter.pauseCommand.addTarget(self, action: #selector(playHandler))
        
        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget(self, action: #selector(pauseHandler))
    }
    
    @objc private func playHandler() {
        pause()
        onPause()
    }
    
    @objc private func pauseHandler() {
        play()
        onPlay()
    }
    
    func setupNowPlaying(track: Track) {
        // Define Now Playing Info
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyAssetURL] = streamURL
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title ?? "Unknown Name"
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            if let imageString = track.thumbnail,
               let imageURL = URL(string: imageString),
               let data = try? Data(contentsOf: imageURL),
               let image = UIImage(data: data) {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { size in
                    return image
                }
            }
            
            nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = itemDurationSubject.value
        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Float(itemDurationSubject.value)
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        
        // Set the metadata
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }
}
