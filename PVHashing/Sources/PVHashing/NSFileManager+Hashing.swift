import Checksum
import Foundation
import PVLogging

@objc
public extension FileManager {
    #if LEGACY_MD5
    func md5ForFile(atPath path: String, fromOffset offset: FileSize = 0) -> String? {
        guard let url = URL(string: path) else {
            ELOG("File path URL invalid")
            return nil
        }
        return url.checksum(algorithm: .md5, fromOffset: offset)
    }
    #else
    func md5ForFile(atPath path: String, fromOffset offset: UInt64 = 0) -> String? {
        guard let url = URL(string: path) else {
            print("Error: File path URL invalid")
            return nil
        }

        do {
            let md5Hash = try calculateMD5Synchronously(of: url, startingAt: offset)
            VLOG("MD5 Hash: \(md5Hash)")
            return md5Hash
        } catch {
            ELOG("An error occurred: \(error)")
            return nil
        }
    }
    #endif
}

import CryptoKit
import Combine

/// Asynchronously reads a local file and calculates the MD5 checksum.
/// - Parameters:
///   - fileURL: The URL of the file.
///   - offset: An optional byte offset to start reading the file. Default is 0.
/// - Returns: A publisher emitting a single String of the computed MD5 hash.
func calculateMD5(of fileURL: URL, startingAt offset: UInt64 = 0) -> AnyPublisher<String, Error> {
    Deferred {
        Future<String, Error> { promise in
            do {
                let fileHandle = try FileHandle(forReadingFrom: fileURL)
                if offset > 0, #available(iOS 13.4, *) {
                    try fileHandle.seek(toOffset: offset)
                } else if offset > 0 {
                    fileHandle.seek(toFileOffset: offset)
                }

                var hasher = Insecure.MD5()
                let bufferSize: Int = 1024 * 1024 // 1 MB
                while autoreleasepool(invoking: {
                    let data = fileHandle.readData(ofLength: bufferSize)
                    if data.count > 0 {
                        hasher.update(data: data)
                        return true // Continue
                    }
                    return false // End of file reached
                }) {}

                fileHandle.closeFile()

                let result = hasher.finalize()
                let hashString = result.map { String(format: "%02x", $0) }.joined()

                promise(.success(hashString))
            } catch {
                promise(.failure(error))
            }
        }
    }.eraseToAnyPublisher()
}

func calculateMD5Synchronously(of fileURL: URL, startingAt offset: UInt64 = 0) throws -> String {
    let semaphore = DispatchSemaphore(value: 0)
    var md5Hash: String = ""
    var returnedError: Error?

    let subscription = calculateMD5(of: fileURL, startingAt: offset)
        .sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
                semaphore.signal()
            case .failure(let error):
                returnedError = error
                semaphore.signal()
            }
        }, receiveValue: { hash in
            md5Hash = hash
        })

    semaphore.wait()
    subscription.cancel()

    if let error = returnedError {
        // Handle the error appropriately in your application context.
        ELOG("Error occurred: \(error)")
        throw error
    }

    return md5Hash
}

public extension URL {
    func calculateMD5(startingAt offset: UInt64 = 0) -> AnyPublisher<String, Error> {
        return PVHashing.calculateMD5(of: self, startingAt: offset)
    }
}

//// Example usage:
//let fileURL = URL(fileURLWithPath: "/path/to/your/file")
//calculateMD5(of: fileURL, startingAt: 1024)
//    .sink(receiveCompletion: { completion in
//        if case .failure(let error) = completion {
//            print("Failed with error: \(error)")
//        }
//    }, receiveValue: { md5Hash in
//        print("MD5 Hash: \(md5Hash)")
//    })
//    .cancel() // Be sure to store the Cancellable in a property if you want the operation to complete.