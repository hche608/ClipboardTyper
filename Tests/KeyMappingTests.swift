import XCTest
@testable import ClipboardTyper

// MARK: - Key Mapping Tests

final class KeyMappingTests: XCTestCase {
    // MARK: - charToKeyCode: Lowercase Letters

    func testLowercaseLetters() {
        let expectations: [(Character, CGKeyCode)] = [
            ("a", 0), ("s", 1), ("d", 2), ("f", 3), ("h", 4), ("g", 5),
            ("z", 6), ("x", 7), ("c", 8), ("v", 9), ("b", 11),
            ("q", 12), ("w", 13), ("e", 14), ("r", 15), ("y", 16), ("t", 17),
            ("o", 31), ("u", 32), ("i", 34), ("p", 35),
            ("l", 37), ("j", 38), ("k", 40), ("n", 45), ("m", 46),
        ]

        for (char, expectedCode) in expectations {
            let result = charToKeyCode(char)
            XCTAssertNotNil(result, "charToKeyCode should return a value for '\(char)'")
            XCTAssertEqual(result?.0, expectedCode, "keyCode for '\(char)' should be \(expectedCode)")
            XCTAssertEqual(result?.1, false, "'\(char)' should not require shift")
        }
    }

    // MARK: - charToKeyCode: Uppercase Letters

    func testUppercaseLetters() {
        let expectations: [(Character, CGKeyCode)] = [
            ("A", 0), ("S", 1), ("D", 2), ("Z", 6), ("Q", 12), ("M", 46),
        ]

        for (char, expectedCode) in expectations {
            let result = charToKeyCode(char)
            XCTAssertNotNil(result, "charToKeyCode should return a value for '\(char)'")
            XCTAssertEqual(result?.0, expectedCode, "keyCode for '\(char)' should be \(expectedCode)")
            XCTAssertEqual(result?.1, true, "'\(char)' should require shift")
        }
    }

    // MARK: - charToKeyCode: Digits

    func testDigits() {
        let expectations: [(Character, CGKeyCode)] = [
            ("1", 18), ("2", 19), ("3", 20), ("4", 21), ("5", 23),
            ("6", 22), ("7", 26), ("8", 28), ("9", 25), ("0", 29),
        ]

        for (char, expectedCode) in expectations {
            let result = charToKeyCode(char)
            XCTAssertNotNil(result, "charToKeyCode should return a value for '\(char)'")
            XCTAssertEqual(result?.0, expectedCode, "keyCode for '\(char)' should be \(expectedCode)")
            XCTAssertEqual(result?.1, false, "'\(char)' should not require shift")
        }
    }

    // MARK: - charToKeyCode: Shifted Symbols

    func testShiftedSymbols() {
        let expectations: [(Character, CGKeyCode)] = [
            ("!", 18), ("@", 19), ("#", 20), ("$", 21), ("%", 23),
            ("^", 22), ("&", 26), ("*", 28), ("(", 25), (")", 29),
            ("{", 33), ("}", 30), ("|", 42), (":", 41), ("\"", 39),
            ("<", 43), (">", 47), ("?", 44), ("~", 50), ("_", 27), ("+", 24),
        ]

        for (char, expectedCode) in expectations {
            let result = charToKeyCode(char)
            XCTAssertNotNil(result, "charToKeyCode should return a value for '\(char)'")
            XCTAssertEqual(result?.0, expectedCode, "keyCode for '\(char)' should be \(expectedCode)")
            XCTAssertEqual(result?.1, true, "'\(char)' should require shift")
        }
    }

    // MARK: - charToKeyCode: Unshifted Symbols

    func testUnshiftedSymbols() {
        let expectations: [(Character, CGKeyCode)] = [
            ("[", 33), ("]", 30), ("\\", 42), (";", 41), ("'", 39),
            (",", 43), (".", 47), ("/", 44), ("`", 50), ("-", 27), ("=", 24),
        ]

        for (char, expectedCode) in expectations {
            let result = charToKeyCode(char)
            XCTAssertNotNil(result, "charToKeyCode should return a value for '\(char)'")
            XCTAssertEqual(result?.0, expectedCode, "keyCode for '\(char)' should be \(expectedCode)")
            XCTAssertEqual(result?.1, false, "'\(char)' should not require shift")
        }
    }

    // MARK: - charToKeyCode: Space

    func testSpaceKey() {
        let result = charToKeyCode(" ")
        XCTAssertEqual(result?.0, 49)
        XCTAssertEqual(result?.1, false)
    }

    // MARK: - charToKeyCode: Non-ASCII returns nil

    func testNonASCIIReturnsNil() {
        let nonASCII: [Character] = ["中", "🎉", "ñ", "ü", "é"]
        for char in nonASCII {
            XCTAssertNil(charToKeyCode(char), "Non-ASCII character '\(char)' should return nil")
        }
    }

    // MARK: - keyCodeToDisplay

    func testDisplayLowercaseLetter() {
        // keyCode 9 = 'v' on US QWERTY
        let result = keyCodeToDisplay(9, shift: false)
        XCTAssertEqual(result, "v")
    }

    func testDisplayUppercaseLetter() {
        let result = keyCodeToDisplay(9, shift: true)
        XCTAssertEqual(result, "V")
    }
}
