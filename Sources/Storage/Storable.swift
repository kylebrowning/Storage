//
//  Storable.swift
//
//  Created by Kyle Browning on 3/17/20.
//  Copyright © 2020 The Athletic. All rights reserved.
//

import Foundation

public protocol StorageMetadataProtocol {
    var lifetime: TimeInterval { get set }
    var dateCreated: TimeInterval { get }
    var dateUpdated: TimeInterval { get set }
}

public struct StorageMetadata: StorageMetadataProtocol, Codable {
    public static var basePath: String = "athletic/"
    public static let metadataExtension: String = ".metadata"
    public static let fileExtension: String = ".json"

    public static func getMetadataFilepath(for keyName: String) -> String {
        StorageMetadata.basePath + keyName + StorageMetadata.metadataExtension + StorageMetadata.fileExtension
    }

    public static func getStorageFilepath(for keyName: String) -> String {
        StorageMetadata.basePath + keyName + StorageMetadata.fileExtension
    }

    public var lifetime: TimeInterval
    public var dateCreated: TimeInterval
    public var dateUpdated: TimeInterval
    public init(lifetime: TimeInterval = -1,
         dateCreated: TimeInterval = Date().timeIntervalSince1970,
         dateUpdated: TimeInterval = Date().timeIntervalSince1970) {
        self.lifetime = lifetime
        self.dateCreated = dateCreated
        self.dateUpdated = dateUpdated
    }
}

@propertyWrapper
public struct Storable <Value: Codable> {
    public var keyName: String
    public var defaultValue: Value
    public var lifetime: TimeInterval = -1

    private var wrappedValueFileName: String {
        StorageMetadata.getStorageFilepath(for: keyName)
    }

    private var metaDataFileName: String {
        StorageMetadata.getMetadataFilepath(for: keyName)
    }

    public var wrappedValue: Value {
        get {
            let now = Date().timeIntervalSince1970
            let dateUpdated = self.metaData.dateUpdated
            let comparison =  now - dateUpdated
            let lifetime = self.metaData.lifetime
            if  comparison > lifetime && lifetime != -1 {
                return defaultValue
            }
            if let value = try? Storage.retrieve(wrappedValueFileName, from: .applicationSupport, as: Value.self) {
                return value
            } else {
                try? Storage.save(defaultValue, to: .applicationSupport, as: wrappedValueFileName)
                return defaultValue
            }
        }
        set {
            do {
                try Storage.save(newValue, to: .applicationSupport, as: wrappedValueFileName)
                var metaData = self.metaData
                metaData.dateUpdated = Date().timeIntervalSince1970
                self.metaData = metaData
            } catch {

            }
        }
    }

    public var metaData: StorageMetadata {
        get {
            guard let metaData = try? Storage.retrieve(metaDataFileName, from: .applicationSupport, as: StorageMetadata.self) else {
                return StorageMetadata()
            }

            return metaData
        }
        set {
            try? Storage.save(newValue, to: .applicationSupport, as: metaDataFileName)
        }
    }
    
    public init(keyName: String, defaultValue: Value, lifetime: TimeInterval = -1) {
        self.keyName = keyName
        self.lifetime = lifetime
        self.defaultValue = defaultValue
        var previousMetaData = self.metaData
        if previousMetaData.lifetime != lifetime {
            previousMetaData.lifetime = lifetime
            self.metaData = previousMetaData
        }
    }
}

extension Storable where Value: ExpressibleByNilLiteral {
    public init(keyName: String, lifetime: TimeInterval = -1) {
        self.init(keyName: keyName, defaultValue: nil, lifetime: lifetime)
        self.defaultValue = self.wrappedValue
    }
}
