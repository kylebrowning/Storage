import XCTest

import StorageTests

var tests = [XCTestCaseEntry]()
tests += StorageTests.allTests()
XCTMain(tests)
