import Foundation

enum Shell {
    struct Output {
        let code: Int32
        let stdout: String
        let stderr: String
    }

    /// 安全执行外部命令，并发读取输出避免管道死锁
    static func run(_ executable: String, _ arguments: [String]) -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return Output(code: -1, stdout: "", stderr: "无法执行 \(executable): \(error.localizedDescription)")
        }

        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        let readQueue = DispatchQueue.global()
        group.enter()
        readQueue.async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        readQueue.async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.wait()
        process.waitUntilExit()

        return Output(
            code: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
