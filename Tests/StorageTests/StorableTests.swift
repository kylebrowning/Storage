//
//  StorableTests.swift
//  
//
//  Created by Eric Yang on 2/4/20.
//

import XCTest
@testable import Storage

class StorableTests: XCTestCase {
    override func tearDown() {
        try! Storage.remove(StorageMetadata.basePath, from: .applicationSupport)
    }

    struct Test: Codable {
        let value: String
    }

    func testStorage() {
        struct Storage {
            @Storable(keyName: "storage1")
            var cached: Test?
        }
        let test = Test(value: "testShouldRemoveOnSetNil")
        var storage = Storage()

        XCTAssertNil(storage.cached?.value)
        
        storage.cached = test
        XCTAssertNotNil(storage.cached)

        storage.cached = nil
        XCTAssertNil(storage.cached)
    }
    
    func testStorageArrays() {
        struct StorageArray {
            @Storable(keyName: "storage2", defaultValue: [])
            var cached: [Test]
        }
        let test = Test(value: "testShouldRemoveOnSetNil")
        var storage = StorageArray()

        XCTAssertEqual(storage.cached.count, 0)
        
        storage.cached = [test]
        XCTAssertEqual(storage.cached.count, 1)

        storage.cached = []
        XCTAssertEqual(storage.cached.count, 0)
    }

    func testLifeTime() {
        struct LifetimeStorage {
            @Storable(keyName: "lifetimeStorage", lifetime: 0.01)
            var cached: Test?
        }

        let test = Test(value: "testLifetime")
        var storage = LifetimeStorage()

        XCTAssertNil(storage.cached?.value)

        storage.cached = test
        XCTAssertNotNil(storage.cached)

        let exp = expectation(description: "Test after a second")
        let result = XCTWaiter.wait(for: [exp], timeout: 0.1)
        if result == XCTWaiter.Result.timedOut {
            XCTAssertNil(storage.cached)
        } else {
            XCTFail("Delay interrupted")
        }
    }

    func testNeverEndingLifeTime() {
        struct NeverEndingLifetimeStorage {
            // Default lifetime is -1
            @Storable(keyName: "neverEndingLifetimeStorage")
            var cached: Test?
        }
        let test = Test(value: "testNeverEndingLifeTime")
        var storage = NeverEndingLifetimeStorage()

        XCTAssertNil(storage.cached?.value)

        storage.cached = test
        XCTAssertNotNil(storage.cached)

        let exp = expectation(description: "Test after 1 seconds")
        let result = XCTWaiter.wait(for: [exp], timeout: 1.01)
        if result == XCTWaiter.Result.timedOut {
            XCTAssertNotNil(storage.cached)
        } else {
            XCTFail("Delay interrupted")
        }
    }

    func testInvalidate() {
        struct EndingLifetimeStorage {
            // set abritary long time in the future liftetime to test that it can be invalidated
            @Storable(keyName: "storage", lifetime: 100)
            var cached: Test?
        }
        let test = Test(value: "storage")
        var storage = EndingLifetimeStorage()

        XCTAssertNil(storage.cached?.value)

        storage.cached = test
        XCTAssertNotNil(storage.cached)

        try! Storage.invalidateStore(for: "storage")

        XCTAssertNil(storage.cached)
    }
}
