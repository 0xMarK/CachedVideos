//
//  VideoResourceLoaderDelegate.swift
//  CachedVideos
//
//  Created by Anton Kaliuzhnyi on 15.08.2023.
//

import Foundation
import AVFoundation

class VideoResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    
    let url: URL
    
    private(set) lazy var streamingAssetURL: URL? = {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = cachingPlayerItemScheme
        return components?.url
    }()
    
    private let completion: ((Data?, Error?) -> Void)?
    
    var playingFromData = false
    var mimeType: String? // Is required when playing from Data
    var mediaData: Data?
    var response: URLResponse?
    var pendingRequests = Set<AVAssetResourceLoadingRequest>()
    private let session: URLSession
    private var task: URLSessionDataTask?
    
    private let cachingPlayerItemScheme = "cachingPlayerItemScheme"
    
    init(url: URL, session: URLSession, completion: ((Data?, Error?) -> Void)?) {
        self.url = url
        self.session = session
        self.completion = completion
        super.init()
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if playingFromData {
            // Nothing to load.
        } else if task == nil {
            // If we're playing from a url, we need to download the file.
            // We start loading the file on first request only.
            startDataRequest(with: url)
        }
        pendingRequests.insert(loadingRequest)
        processPendingRequests()
        return true
    }
    
    func startDataRequest(with url: URL) {
        task = session.dataTask(with: url)
        task?.delegate = self
        task?.resume()
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        pendingRequests.remove(loadingRequest)
    }
    
    // MARK: -
    
    func processPendingRequests() {
        // Get all fullfilled requests
        let requestsFulfilled = Set<AVAssetResourceLoadingRequest>(pendingRequests.compactMap {
            fillInContentInformationRequest($0.contentInformationRequest)
            if haveEnoughDataToFulfillRequest($0.dataRequest!) {
                $0.finishLoading()
                return $0
            }
            return nil
        })
        // Remove fulfilled requests from pending requests
        requestsFulfilled.forEach { pendingRequests.remove($0) }
    }
    
    func fillInContentInformationRequest(_ contentInformationRequest: AVAssetResourceLoadingContentInformationRequest?) {
        // If we play from Data we make no url requests, therefore we have no responses, so we need to fill in contentInformationRequest manually
        if playingFromData {
            contentInformationRequest?.contentType = self.mimeType
            contentInformationRequest?.contentLength = Int64(mediaData!.count)
            contentInformationRequest?.isByteRangeAccessSupported = true
            return
        }
        
        guard let responseUnwrapped = response else {
            // Have no response from the server yet
            return
        }
        
        contentInformationRequest?.contentType = responseUnwrapped.mimeType
        contentInformationRequest?.contentLength = responseUnwrapped.expectedContentLength
        contentInformationRequest?.isByteRangeAccessSupported = true
    }
    
    func haveEnoughDataToFulfillRequest(_ dataRequest: AVAssetResourceLoadingDataRequest) -> Bool {
        let requestedOffset = Int(dataRequest.requestedOffset)
        let requestedLength = dataRequest.requestedLength
        let currentOffset = Int(dataRequest.currentOffset)
        
        guard let dataUnwrapped = mediaData,
              dataUnwrapped.count > currentOffset else {
            // Don't have any data at all for this request.
            return false
        }
        
        let bytesToRespond = min(dataUnwrapped.count - currentOffset, requestedLength)
        let dataToRespond = dataUnwrapped.subdata(in: Range(uncheckedBounds: (currentOffset, currentOffset + bytesToRespond)))
        dataRequest.respond(with: dataToRespond)
        
        return dataUnwrapped.count >= requestedLength + requestedOffset
    }
    
}

extension VideoResourceLoaderDelegate: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        mediaData?.append(data)
        processPendingRequests()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(Foundation.URLSession.ResponseDisposition.allow)
        mediaData = Data()
        self.response = response
        processPendingRequests()
    }
    
}

extension VideoResourceLoaderDelegate: URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            completion?(nil, error)
        } else {
            processPendingRequests()
            completion?(mediaData, mediaData != nil ? nil : NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No media data"]))
        }
    }
    
}
