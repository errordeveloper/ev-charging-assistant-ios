import Foundation
import Testing
@testable import EVCore

@Test func responsesSurviveEveryPossibleTwoChunkSplit() throws {
    let bytes = Array("0100\r41 00 BE 3E B8 13\r>NO DATA\r>".utf8)
    let expected = [Data("0100\r41 00 BE 3E B8 13\r".utf8), Data("NO DATA\r".utf8)]
    // Hex text containing "3E" is not the literal '>' prompt byte.
    for split in 0...bytes.count {
        var framer = PromptFramer()
        let first = try framer.append(Data(bytes[..<split]))
        let second = try framer.append(Data(bytes[split...]))
        #expect(first + second == expected)
    }
}

@Test func oversizeResponseFailsAndBufferCanRecover() throws {
    var framer = PromptFramer(maxResponseBytes: 4)
    #expect(throws: FramingError.responseTooLarge) {
        try framer.append(Data("12345".utf8))
    }
    #expect(try framer.append(Data("OK>".utf8)) == [Data("OK".utf8)])
    _ = try framer.append(Data("par".utf8))
    framer.reset()
    #expect(try framer.append(Data(">".utf8)) == [Data()])
}
