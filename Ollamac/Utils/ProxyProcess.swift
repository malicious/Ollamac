//
//  ProxyProcess.swift
//  Ollamac
//
//  Created by user on 2024-04-30.
//

import Foundation

fileprivate func socketTest() {
    var fds: [Int32] = [ -1, -1 ]
    let success = socketpair(AF_UNIX, SOCK_STREAM, 0, &fds) >= 0
    assert(success)
    let sockIn = fds[0]
    let sockOut = fds[1]
    Thread.detachNewThread {
        var message = [UInt8]("Hello Cruel World!".utf8)
        let writeResult = write(sockOut, &message, message.count)
        print("wrote:", writeResult)
    }
    Thread.detachNewThread {
        var message = [UInt8](repeating: 0, count: 256)
        let readResult = read(sockIn, &message, message.count)
        if readResult > 0 {
            let s = String(bytes: message.prefix(readResult), encoding: .utf8) ?? "?"
            print(s)
        }
        print("read:", readResult)
    }
}

func startOllamaProxy() -> URLSessionStreamTask? {
    // https://github.com/Alamofire/Alamofire/issues/832
    // https://developer.apple.com/documentation/foundation/nsurlsessionstreamtask
    // https://medium.com/@JustRouzbeh/using-unix-sockets-for-communication-between-ios-extensions-and-main-app-27159bfc1144
    return nil
}

func startOrCheckOllama(forceProxy: Bool = true) -> URL {
    do {
        // For now, we manually include this with something like:
        //
        //     cd ~/Library/Developer/Xcode/DerivedData/Ollamac-*/Build/Products/Debug/Ollamac.app/Contents/MacOS
        //     ln -s /path/to/proxy-server proxy-server
        let process = Process()
        let helper = Bundle.main.path(forAuxiliaryExecutable: "proxy-server")!
        process.executableURL = URL(fileURLWithPath: helper)
        
        // TODO: Merge tool code from https://developer.apple.com/forums/thread/690310
        let pipe = Pipe()
        process.standardOutput = pipe
        
        let outHandle = pipe.fileHandleForReading
        outHandle.readabilityHandler = { pipe in
            if let line = String(data: pipe.availableData, encoding: .utf8) {
                if !line.isEmpty {
                    print("[proxy-server] \(line)")
                }
            } else {
                print("Error decoding proxy-server data: \(pipe.availableData)")
            }
        }

        // Try running the embedded Ollama server, first
        try process.run()
        print("[INFO] Starting proxy-server with pid \(process.processIdentifier)")

        return URL(string: "http://localhost:9750/ollama-proxy")!
    }
    catch {
        if forceProxy {
            print("Forcing use of Ollama proxy on port 9750: \(error)")
            return URL(string: "http://localhost:9750/ollama-proxy")!
        }

        print("Failed to run embedded Ollama proxy, falling back to direct Ollama connection: \(error)")
        return URL(string: "http://localhost:11434")!
    }
}
