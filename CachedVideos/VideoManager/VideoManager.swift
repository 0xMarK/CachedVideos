//
//  VideoManager.swift
//  CachedVideos
//
//  Created by Anton Kaliuzhnyi on 15.08.2023.
//

import Foundation
import AVFoundation

class VideoManager: NSObject {
    
    static let shared = VideoManager()
    
    private var loaders: Set<VideoResourceLoaderDelegate> = []
    
    private let videosDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("Videos")
    
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.underlyingQueue = DispatchQueue.global()
        return URLSession(configuration: configuration, delegate: nil, delegateQueue: operationQueue)
    }()
    
    override init() {
        super.init()
        if !FileManager.default.fileExists(atPath: videosDirectory.path) {
            do {
                try FileManager.default.createDirectory(atPath: videosDirectory.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func cleanUpCache() {
        guard let minimumDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return }
        let keys = Set<URLResourceKey>([.isDirectoryKey, .creationDateKey, .pathKey])
        let options: FileManager.DirectoryEnumerationOptions = []
        if let videosDirectoryEnumerator = FileManager.default.enumerator(at: videosDirectory, includingPropertiesForKeys: Array(keys), options: options, errorHandler: nil) {
            for case let url as URL in videosDirectoryEnumerator {
                guard let resourceValues = try? url.resourceValues(forKeys: keys),
                      let isDirectory = resourceValues.isDirectory,
                      let creationDate = resourceValues.creationDate,
                      let path = resourceValues.path else { continue }
                if isDirectory {
                    let contentsOfDirectory = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
                    if contentsOfDirectory.isEmpty {
                        try? FileManager.default.removeItem(atPath: path)
                    }
                } else {
                    if creationDate < minimumDate {
                        try? FileManager.default.removeItem(atPath: path)
                    }
                }
            }
        }
    }
    
    func asset(for url: URL) -> AVAsset {
        let localFileURL = localFileURL(from: url)
        if FileManager.default.fileExists(atPath: localFileURL.path) {
            return AVAsset(url: localFileURL)
        } else {
            let videoResourceLoaderDelegate: VideoResourceLoaderDelegate
            if let loaderDelegate = loaders.first(where: { $0.url == url }) {
                videoResourceLoaderDelegate = loaderDelegate
            } else {
                let loaderDelegate = VideoResourceLoaderDelegate(url: url, session: session) { [weak self] mediaData, error in
                    if let error {
                        print("VideoResourceLoaderDelegate error: \(error)")
                    } else if let mediaData {
                        if FileManager.default.fileExists(atPath: localFileURL.path) {
                            do {
                                try FileManager.default.removeItem(at: localFileURL)
                            } catch let error {
                                print("Failed to delete file with error: \(error)")
                            }
                        }
                        do {
                            try mediaData.write(to: localFileURL, options: .atomic)
                        } catch let error {
                            print("Failed to save data with error: \(error)")
                        }
                    } else {
                        print("Error: No media data")
                    }
                    if let thisLoader = self?.loaders.first(where: { $0.url == url }) {
                        self?.loaders.remove(thisLoader)
                    }
                }
                loaders.insert(loaderDelegate)
                videoResourceLoaderDelegate = loaderDelegate
            }
            if let assetUrl = videoResourceLoaderDelegate.streamingAssetURL {
                let videoAsset = AVURLAsset(url: assetUrl)
                videoAsset.resourceLoader.setDelegate(videoResourceLoaderDelegate, queue: DispatchQueue.global())
                videoAsset.videoResourceLoaderDelegate = videoResourceLoaderDelegate
                return videoAsset
            } else {
                return AVURLAsset(url: url)
            }
        }
    }
    
    private func localFileURL(from url: URL) -> URL {
        let fullFileName = url.path.replacingOccurrences(of: "/", with: "")
        return videosDirectory.appendingPathComponent(fullFileName)
    }
    
}

private extension AVURLAsset {
    
    private struct AssociatedKeys {
        static var videoResourceLoaderDelegate: VideoResourceLoaderDelegate?
    }
    
    /// Adding a retained property to AVURLAsset so that asset itself holds a reference to resource loader delegate.
    var videoResourceLoaderDelegate: VideoResourceLoaderDelegate? {
        get {
            guard let value = objc_getAssociatedObject(self, &AssociatedKeys.videoResourceLoaderDelegate) as? VideoResourceLoaderDelegate else { return nil }
            return value
        }
        set(newValue) {
            objc_setAssociatedObject(self, &AssociatedKeys.videoResourceLoaderDelegate, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
}
