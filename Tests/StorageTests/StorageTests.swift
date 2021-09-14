#if !os(macOS)
import XCTest
import UIKit
@testable import Storage

struct Message: Codable {
    let title: String
    let body: String
}

// Conforms to Equatable so we can compare messages (i.e. message1 == message2)
extension Message: Equatable {
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.title == rhs.title && lhs.body == rhs.body
    }
}

struct Resource {
  let name: String
  let type: String
  let url: URL

  init(name: String, type: String, sourceFile: StaticString = #file) throws {
    self.name = name
    self.type = type

    // The following assumes that your test source files are all in the same directory, and the resources are one directory down and over
    // <Some folder>
    //  - Resources
    //      - <resource files>
    //  - <Some test source folder>
    //      - <test case files>
    let testCaseURL = URL(fileURLWithPath: "\(sourceFile)", isDirectory: false)
    let testsFolderURL = testCaseURL.deletingLastPathComponent()
    let resourcesFolderURL = testsFolderURL.deletingLastPathComponent().appendingPathComponent("Resources", isDirectory: true)
    self.url = resourcesFolderURL.appendingPathComponent("\(name).\(type)", isDirectory: false)
  }
}

// UIImage's current Equatable implementation is buggy, this is a simply workaround to compare images' Data

extension UIImage {
    func dataEquals(_ otherImage: UIImage) -> Bool {
        if let selfData = self.pngData(), let otherData = otherImage.pngData() {
            return selfData == otherData
        } else {
            print("Could not convert images to PNG")
            return false
        }
    }
}

class StorageTests: XCTestCase {

    // MARK: Helpers

    // Convert Error -> String of descriptions
    func convertErrorToString(_ error: Error) -> String {
        return """
        Domain: \((error as NSError).domain)
        Code: \((error as NSError).code)
        Description: \(error.localizedDescription)
        Failure Reason: \((error as NSError).localizedFailureReason ?? "nil")
        Suggestions: \((error as NSError).localizedRecoverySuggestion ?? "nil")\n
        """
    }

    override func setUp() {
        let bench = try! Resource(name: "bench", type: "png")
        images.append(UIImage(contentsOfFile: bench.url.path)!)

        let player = try! Resource(name: "player", type: "png")
        images.append(UIImage(contentsOfFile: player.url.path)!)

        let fans = try! Resource(name: "fans", type: "png")
        images.append(UIImage(contentsOfFile: fans.url.path)!)
    }
    // We'll clear out all our directories after each test
    override func tearDown() {
        do {
            try Storage.clear(.documents)
            try Storage.clear(.caches)
            try Storage.clear(.applicationSupport)
            try Storage.clear(.temporary)
        } catch {
            // NOTE: If you get a NSCocoaErrorDomain with code 260, this means one of the above directories could not be found.
            // On some of the newer simulators, not all these default directories are initialized at first, but will be created
            // after you save something within it. To fix this, run each of the test[directory] test functions below to get each
            // respective directory initialized, before running other tests.
            fatalError(convertErrorToString(error))
        }
    }

    // MARK: Dummmy data

    let messages: [Message] = {
        var array = [Message]()
        for i in 1...10 {
            let element = Message(title: "Message \(i)", body: "...")
            array.append(element)
        }
        return array
    }()

    let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    var images: [UIImage] = []

    lazy var data: [Data] = self.images.map { $0.pngData()! }

    // MARK: Tests

    func testSaveStructs() {
        do {
            // 1 struct
            try Storage.save(messages[0], to: .documents, as: "message.json")
            XCTAssert(Storage.exists("message.json", in: .documents))
            let messageUrl = try Storage.url(for: "message.json", in: .documents)
            print("A message was saved as \(messageUrl.absoluteString)")
            let retrievedMessage = try Storage.retrieve("message.json", from: .documents, as: Message.self)
            XCTAssert(messages[0] == retrievedMessage)

            // ... in folder hierarchy
            try Storage.save(messages[0], to: .documents, as: "Messages/Bob/message.json")
            XCTAssert(Storage.exists("Messages/Bob/message.json", in: .documents))
            let messageInFolderUrl = try Storage.url(for: "Messages/Bob/message.json", in: .documents)
            print("A message was saved as \(messageInFolderUrl.absoluteString)")
            let retrievedMessageInFolder = try Storage.retrieve("Messages/Bob/message.json", from: .documents, as: Message.self)
            XCTAssert(messages[0] == retrievedMessageInFolder)

            // Array of structs
            try Storage.save(messages, to: .documents, as: "messages.json")
            XCTAssert(Storage.exists("messages.json", in: .documents))
            let messagesUrl = try Storage.url(for: "messages.json", in: .documents)
            print("Messages were saved as \(messagesUrl.absoluteString)")
            let retrievedMessages = try Storage.retrieve("messages.json", from: .documents, as: [Message].self)
            XCTAssert(messages == retrievedMessages)
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testAppendStructs() {
        do {
            // Append a single struct to an empty location
            try Storage.append(messages[0], to: "single-message.json", in: .documents)
            let retrievedSingleMessage = try Storage.retrieve("single-message.json", from: .documents, as: [Message].self)
            XCTAssert(Storage.exists("single-message.json", in: .documents))
            XCTAssert(retrievedSingleMessage[0] == messages[0])

            // Append an array of structs to an empty location
            try Storage.append(messages, to: "multiple-messages.json", in: .documents)
            let retrievedMultipleMessages = try Storage.retrieve("multiple-messages.json", from: .documents, as: [Message].self)
            XCTAssert(Storage.exists("multiple-messages.json", in: .documents))
            XCTAssert(retrievedMultipleMessages == messages)

            // Append a single struct to a single struct
            try Storage.save(messages[0], to: .documents, as: "messages.json")
            XCTAssert(Storage.exists("messages.json", in: .documents))
            try Storage.append(messages[1], to: "messages.json", in: .documents)
            let retrievedMessages = try Storage.retrieve("messages.json", from: .documents, as: [Message].self)
            XCTAssert(retrievedMessages[0] == messages[0] && retrievedMessages[1] == messages[1])

            // Append an array of structs to a single struct
            try Storage.save(messages[5], to: .caches, as: "one-message.json")
            try Storage.append(messages, to: "one-message.json", in: .caches)
            let retrievedOneMessage = try Storage.retrieve("one-message.json", from: .caches, as: [Message].self)
            XCTAssert(retrievedOneMessage.count == messages.count + 1)
            XCTAssert(retrievedOneMessage[0] == messages[5])
            XCTAssert(retrievedOneMessage.last! == messages.last!)

            // Append a single struct to an array of structs
            try Storage.save(messages, to: .documents, as: "many-messages.json")
            try Storage.append(messages[1], to: "many-messages.json", in: .documents)
            let retrievedManyMessages = try Storage.retrieve("many-messages.json", from: .documents, as: [Message].self)
            XCTAssert(retrievedManyMessages.count == messages.count + 1)
            XCTAssert(retrievedManyMessages[0] == messages[0])
            XCTAssert(retrievedManyMessages.last! == messages[1])

            let array = [messages[0], messages[1], messages[2]]
            try Storage.save(array, to: .documents, as: "a-few-messages.json")
            XCTAssert(Storage.exists("a-few-messages.json", in: .documents))
            try Storage.append(messages[3], to: "a-few-messages.json", in: .documents)
            let retrievedFewMessages = try Storage.retrieve("a-few-messages.json", from: .documents, as: [Message].self)
            XCTAssert(retrievedFewMessages[0] == array[0] && retrievedFewMessages[1] == array[1] && retrievedFewMessages[2] == array[2] && retrievedFewMessages[3] == messages[3])

            // Append an array of structs to an array of structs
            try Storage.save(messages, to: .documents, as: "array-of-structs.json")
            try Storage.append(messages, to: "array-of-structs.json", in: .documents)
            let retrievedArrayOfStructs = try Storage.retrieve("array-of-structs.json", from: .documents, as: [Message].self)
            XCTAssert(retrievedArrayOfStructs.count == (messages.count * 2))
            XCTAssert(retrievedArrayOfStructs[0] == messages[0] && retrievedArrayOfStructs.last! == messages.last!)
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testSaveImages() {
        do {
            // 1 image
            try Storage.save(images[0], to: .documents, as: "image.png")
            XCTAssert(Storage.exists("image.png", in: .documents))
            let imageUrl = try Storage.url(for: "image.png", in: .documents)
            print("An image was saved as \(imageUrl.absoluteString)")
            let retrievedImage = try Storage.retrieve("image.png", from: .documents, as: UIImage.self)
            XCTAssert(images[0].dataEquals(retrievedImage))

            // ... in folder hierarchy
            try Storage.save(images[0], to: .documents, as: "Photos/image.png")
            XCTAssert(Storage.exists("Photos/image.png", in: .documents))
            let imageInFolderUrl = try Storage.url(for: "Photos/image.png", in: .documents)
            print("An image was saved as \(imageInFolderUrl.absoluteString)")
            let retrievedInFolderImage = try Storage.retrieve("Photos/image.png", from: .documents, as: UIImage.self)
            XCTAssert(images[0].dataEquals(retrievedInFolderImage))

            // Array of images
            try Storage.save(images, to: .documents, as: "album/")
            XCTAssert(Storage.exists("album/", in: .documents))
            let imagesFolderUrl = try Storage.url(for: "album/", in: .documents)
            print("Images were saved as \(imagesFolderUrl.absoluteString)")
            let retrievedImages = try Storage.retrieve("album/", from: .documents, as: [UIImage].self)
            for i in 0..<images.count {
                XCTAssert(images[i].dataEquals(retrievedImages[i]))
            }

            // ... in folder hierarchy
            try Storage.save(images, to: .documents, as: "Photos/summer-album/")
            XCTAssert(Storage.exists("Photos/summer-album/", in: .documents))
            let imagesInFolderUrl = try Storage.url(for: "Photos/summer-album/", in: .documents)
            print("Images were saved as \(imagesInFolderUrl.absoluteString)")
            let retrievedInFolderImages = try Storage.retrieve("Photos/summer-album/", from: .documents, as: [UIImage].self)
            for i in 0..<images.count {
                XCTAssert(images[i].dataEquals(retrievedInFolderImages[i]))
            }
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testAppendImages() {
        do {
            // Append a single image to an empty folder
            try Storage.append(images[0], to: "EmptyFolder/", in: .documents)
            XCTAssert(Storage.exists("EmptyFolder/0.png", in: .documents))
            let retrievedImage = try Storage.retrieve("EmptyFolder", from: .documents, as: [UIImage].self)
            XCTAssert(Storage.exists("EmptyFolder/0.png", in: .documents))
            XCTAssert(retrievedImage.count == 1)
            XCTAssert(retrievedImage[0].dataEquals(images[0]))

            // Append an array of images to an empty folder
            try Storage.append(images, to: "EmptyFolder2/", in: .documents)
            XCTAssert(Storage.exists("EmptyFolder2/0.png", in: .documents))
            var retrievedImages = try Storage.retrieve("EmptyFolder2", from: .documents, as: [UIImage].self)
            XCTAssert(retrievedImages.count == images.count)
            for i in 0..<retrievedImages.count {
                let image = retrievedImages[i]
                XCTAssert(image.dataEquals(images[i]))
            }

            // Append a single image to an existing folder with images
            try Storage.save(images, to: .documents, as: "Folder/")
            XCTAssert(Storage.exists("Folder/", in: .documents))
            try Storage.append(images[1], to: "Folder/", in: .documents)
            retrievedImages = try Storage.retrieve("Folder/", from: .documents, as: [UIImage].self)
            XCTAssert(retrievedImages.count == images.count + 1)
            XCTAssert(Storage.exists("Folder/3.png", in: .documents))
            XCTAssert(retrievedImages.last!.dataEquals(images[1]))

            // Append an array of images to an existing folder with images
            try Storage.append(images, to: "Folder/", in: .documents)
            retrievedImages = try Storage.retrieve("Folder/", from: .documents, as: [UIImage].self)
            XCTAssert(retrievedImages.count == images.count * 2 + 1)
            XCTAssert(retrievedImages.last!.dataEquals(images.last!))
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testSaveData() {
        do {
            // 1 data object
            try Storage.save(data[0], to: .documents, as: "file")
            XCTAssert(Storage.exists("file", in: .documents))
            let fileUrl = try Storage.url(for: "file", in: .documents)
            print("A file was saved to \(fileUrl.absoluteString)")
            let retrievedFile = try Storage.retrieve("file", from: .documents, as: Data.self)
            XCTAssert(data[0] == retrievedFile)

            // ... in folder hierarchy
            try Storage.save(data[0], to: .documents, as: "Folder/file")
            XCTAssert(Storage.exists("Folder/file", in: .documents))
            let fileInFolderUrl = try Storage.url(for: "Folder/file", in: .documents)
            print("A file was saved as \(fileInFolderUrl.absoluteString)")
            let retrievedInFolderFile = try Storage.retrieve("Folder/file", from: .documents, as: Data.self)
            XCTAssert(data[0] == retrievedInFolderFile)

            // Array of data
            try Storage.save(data, to: .documents, as: "several-files/")
            XCTAssert(Storage.exists("several-files/", in: .documents))
            let folderUrl = try Storage.url(for: "several-files/", in: .documents)
            print("Files were saved to \(folderUrl.absoluteString)")
            let retrievedFiles = try Storage.retrieve("several-files/", from: .documents, as: [Data].self)
            XCTAssert(data == retrievedFiles)

            // ... in folder hierarchy
            try Storage.save(data, to: .documents, as: "Folder/Files/")
            XCTAssert(Storage.exists("Folder/Files/", in: .documents))
            let filesInFolderUrl = try Storage.url(for: "Folder/Files/", in: .documents)
            print("Files were saved to \(filesInFolderUrl.absoluteString)")
            let retrievedInFolderFiles = try Storage.retrieve("Folder/Files/", from: .documents, as: [Data].self)
            XCTAssert(data == retrievedInFolderFiles)
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testAppendData() {
        do {
            // Append a single data object to an empty folder
            try Storage.append(data[0], to: "EmptyFolder/", in: .documents)
            XCTAssert(Storage.exists("EmptyFolder/0", in: .documents))
            let retrievedObject = try Storage.retrieve("EmptyFolder", from: .documents, as: [Data].self)
            XCTAssert(Storage.exists("EmptyFolder/0", in: .documents))
            XCTAssert(retrievedObject.count == 1)
            XCTAssert(retrievedObject[0] == data[0])

            // Append an array of data objects to an empty folder
            try Storage.append(data, to: "EmptyFolder2/", in: .documents)
            XCTAssert(Storage.exists("EmptyFolder2/0", in: .documents))
            var retrievedObjects = try Storage.retrieve("EmptyFolder2", from: .documents, as: [Data].self)
            XCTAssert(retrievedObjects.count == data.count)
            for i in 0..<retrievedObjects.count {
                let object = retrievedObjects[i]
                XCTAssert(object == data[i])
            }

            // Append a single data object to an existing folder with files
            try Storage.save(data, to: .documents, as: "Folder/")
            XCTAssert(Storage.exists("Folder/", in: .documents))
            try Storage.append(data[1], to: "Folder/", in: .documents)
            retrievedObjects = try Storage.retrieve("Folder/", from: .documents, as: [Data].self)
            XCTAssert(retrievedObjects.count == data.count + 1)
            XCTAssert(retrievedObjects.last! == data[1])

            // Append an array of data objects to an existing folder with files
            try Storage.append(data, to: "Folder/", in: .documents)
            retrievedObjects = try Storage.retrieve("Folder/", from: .documents, as: [Data].self)
            XCTAssert(retrievedObjects.count == data.count * 2 + 1)
            XCTAssert(retrievedObjects.last! == data.last!)
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testSaveAsDataRetrieveAsImage() {
        do {
            // save as data
            let image = images[0]
            let imageData = image.pngData()!
            try Storage.save(imageData, to: .documents, as: "file")
            XCTAssert(Storage.exists("file", in: .documents))
            let fileUrl = try Storage.url(for: "file", in: .documents)
            print("A file was saved to \(fileUrl.absoluteString)")

            // Retrieve as image
            let retrievedFileAsImage = try Storage.retrieve("file", from: .documents, as: UIImage.self)
            XCTAssert(image.dataEquals(retrievedFileAsImage))

            // Array of data
            let arrayOfImagesData = images.map { $0.pngData()! } // -> [Data]
            try Storage.save(arrayOfImagesData, to: .documents, as: "data-folder/")
            XCTAssert(Storage.exists("data-folder/", in: .documents))
            let folderUrl = try Storage.url(for: "data-folder/", in: .documents)
            print("Files were saved to \(folderUrl.absoluteString)")
            // Retrieve the files as [UIImage]
            let retrievedFilesAsImages = try Storage.retrieve("data-folder/", from: .documents, as: [UIImage].self)
            for i in 0..<images.count {
                XCTAssert(images[i].dataEquals(retrievedFilesAsImages[i]))
            }
        } catch {
            fatalError(convertErrorToString(error))
        }

    }

    func testDocuments() {
        do {
            // json
            try Storage.save(messages, to: .documents, as: "messages.json")
            XCTAssert(Storage.exists("messages.json", in: .documents))

            // 1 image
            try Storage.save(images[0], to: .documents, as: "image.png")
            XCTAssert(Storage.exists("image.png", in: .documents))
            let retrievedImage = try Storage.retrieve("image.png", from: .documents, as: UIImage.self)
            XCTAssert(images[0].dataEquals(retrievedImage))

            // ... in folder hierarchy
            try Storage.save(images[0], to: .documents, as: "Folder1/Folder2/Folder3/image.png")
            XCTAssert(Storage.exists("Folder1", in: .documents))
            XCTAssert(Storage.exists("Folder1/Folder2/", in: .documents))
            XCTAssert(Storage.exists("Folder1/Folder2/Folder3/", in: .documents))
            XCTAssert(Storage.exists("Folder1/Folder2/Folder3/image.png", in: .documents))
            let retrievedImageInFolders = try Storage.retrieve("Folder1/Folder2/Folder3/image.png", from: .documents, as: UIImage.self)
            XCTAssert(images[0].dataEquals(retrievedImageInFolders))

            // Array of images
            try Storage.save(images, to: .documents, as: "album")
            XCTAssert(Storage.exists("album", in: .documents))
            let retrievedImages = try Storage.retrieve("album", from: .documents, as: [UIImage].self)
            for i in 0..<images.count {
                XCTAssert(images[i].dataEquals(retrievedImages[i]))
            }
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testCaches() {
        do {
            // json
            try Storage.save(messages, to: .caches, as: "messages.json")
            XCTAssert(Storage.exists("messages.json", in: .caches))

            // 1 image
            try Storage.save(images[0], to: .caches, as: "image.png")
            XCTAssert(Storage.exists("image.png", in: .caches))
            let retrievedImage = try Storage.retrieve("image.png", from: .caches, as: UIImage.self)
            XCTAssert(images[0].dataEquals(retrievedImage))

            // ... in folder hierarchy
            try Storage.save(images[0], to: .caches, as: "Folder1/Folder2/Folder3/image.png")
            XCTAssert(Storage.exists("Folder1", in: .caches))
            XCTAssert(Storage.exists("Folder1/Folder2/", in: .caches))
            XCTAssert(Storage.exists("Folder1/Folder2/Folder3/", in: .caches))
            XCTAssert(Storage.exists("Folder1/Folder2/Folder3/image.png", in: .caches))
            let retrievedImageInFolders = try Storage.retrieve("Folder1/Folder2/Folder3/image.png", from: .caches, as: UIImage.self)
            XCTAssert(images[0].dataEquals(retrievedImageInFolders))

            // Array of images
            try Storage.save(images, to: .caches, as: "album")
            XCTAssert(Storage.exists("album", in: .caches))
            let retrievedImages = try Storage.retrieve("album", from: .caches, as: [UIImage].self)
            for i in 0..<images.count {
                XCTAssert(images[i].dataEquals(retrievedImages[i]))
            }
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testApplicationSupport() {
        do {
            // json
            try Storage.save(messages, to: .applicationSupport, as: "messages.json")
            XCTAssert(Storage.exists("messages.json", in: .applicationSupport))

            // 1 image
            try Storage.save(images[0], to: .applicationSupport, as: "image.png")
            XCTAssert(Storage.exists("image.png", in: .applicationSupport))
            let retrievedImage = try Storage.retrieve("image.png", from: .applicationSupport, as: UIImage.self)
            XCTAssert(images[0].dataEquals(retrievedImage))

            // ... in folder hierarchy
            try Storage.save(images[0], to: .applicationSupport, as: "Folder1/Folder2/Folder3/image.png")
            XCTAssert(Storage.exists("Folder1", in: .applicationSupport))
            XCTAssert(Storage.exists("Folder1/Folder2/", in: .applicationSupport))
            XCTAssert(Storage.exists("Folder1/Folder2/Folder3/", in: .applicationSupport))
            XCTAssert(Storage.exists("Folder1/Folder2/Folder3/image.png", in: .applicationSupport))
            let retrievedImageInFolders = try Storage.retrieve("Folder1/Folder2/Folder3/image.png", from: .applicationSupport, as: UIImage.self)
            XCTAssert(images[0].dataEquals(retrievedImageInFolders))

            // Array of images
            try Storage.save(images, to: .applicationSupport, as: "album")
            XCTAssert(Storage.exists("album", in: .applicationSupport))
            let retrievedImages = try Storage.retrieve("album", from: .applicationSupport, as: [UIImage].self)
            for i in 0..<images.count {
                XCTAssert(images[i].dataEquals(retrievedImages[i]))
            }
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testTemporary() {
        do {
            // json
            try Storage.save(messages, to: .temporary, as: "messages.json")
            XCTAssert(Storage.exists("messages.json", in: .temporary))

            // 1 image
            try Storage.save(images[0], to: .temporary, as: "image.png")
            XCTAssert(Storage.exists("image.png", in: .temporary))
            let retrievedImage = try Storage.retrieve("image.png", from: .temporary, as: UIImage.self)
            XCTAssert(images[0].dataEquals(retrievedImage))

            // ... in folder hierarchy
            try Storage.save(images[0], to: .temporary, as: "Folder1/Folder2/Folder3/image.png")
            XCTAssert(Storage.exists("Folder1", in: .temporary))
            XCTAssert(Storage.exists("Folder1/Folder2/", in: .temporary))
            XCTAssert(Storage.exists("Folder1/Folder2/Folder3/", in: .temporary))
            XCTAssert(Storage.exists("Folder1/Folder2/Folder3/image.png", in: .temporary))
            let retrievedImageInFolders = try Storage.retrieve("Folder1/Folder2/Folder3/image.png", from: .temporary, as: UIImage.self)
            XCTAssert(images[0].dataEquals(retrievedImageInFolders))

            // Array of images
            try Storage.save(images, to: .temporary, as: "album")
            XCTAssert(Storage.exists("album", in: .temporary))
            let retrievedImages = try Storage.retrieve("album", from: .temporary, as: [UIImage].self)
            for i in 0..<images.count {
                XCTAssert(images[i].dataEquals(retrievedImages[i]))
            }
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    // MARK: Test helper methods

    func testGetUrl() {
        do {
            try Storage.clear(.documents)
            // 1 struct
            try Storage.save(messages[0], to: .documents, as: "message.json")
            let messageUrlPath = try Storage.url(for: "message.json", in: .documents).path.replacingOccurrences(of: "file://", with: "")
            XCTAssert(FileManager.default.fileExists(atPath: messageUrlPath))

            // Array of images (folder)
            try Storage.save(images, to: .documents, as: "album")
            XCTAssert(Storage.exists("album", in: .documents))
            let folderUrlPath = try Storage.url(for: "album/", in: .documents).path.replacingOccurrences(of: "file://", with: "")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: folderUrlPath, isDirectory: &isDirectory) {
                XCTAssert(isDirectory.boolValue)
            } else {
                XCTFail()
            }
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testClear() {
        do {
            try Storage.save(messages[0], to: .caches, as: "message.json")
            XCTAssert(Storage.exists("message.json", in: .caches))
            try Storage.clear(.caches)
            XCTAssertFalse(Storage.exists("message.json", in: .caches))
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testRemove() {
        do {
            try Storage.save(messages[0], to: .caches, as: "message.json")
            XCTAssert(Storage.exists("message.json", in: .caches))
            try Storage.remove("message.json", from: .caches)
            XCTAssertFalse(Storage.exists("message.json", in: .caches))

            try Storage.save(messages[0], to: .caches, as: "message2.json")
            XCTAssert(Storage.exists("message2.json", in: .caches))
            let message2Url = try Storage.url(for: "message2.json", in: .caches)
            try Storage.remove(message2Url)
            XCTAssertFalse(Storage.exists("message2.json", in: .caches))
            XCTAssertFalse(Storage.exists(message2Url))
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testExists() {
        do {
            try Storage.save(messages[0], to: .caches, as: "message.json")
            XCTAssert(Storage.exists("message.json", in: .caches))
            let messageUrl = try Storage.url(for: "message.json", in: .caches)
            XCTAssert(Storage.exists(messageUrl))

            // folder
            try Storage.save(images, to: .documents, as: "album/")
            XCTAssert(Storage.exists("album/", in: .documents))
            let albumUrl = try Storage.url(for: "album/", in: .documents)
            XCTAssert(Storage.exists(albumUrl))
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testDoNotBackupAndBackup() {
        do {
            // Do not backup
            try Storage.save(messages[0], to: .documents, as: "Messages/message.json")
            try Storage.doNotBackup("Messages/message.json", in: .documents)
            let messageUrl = try Storage.url(for: "Messages/message.json", in: .documents)
            if let resourceValues = try? messageUrl.resourceValues(forKeys: [.isExcludedFromBackupKey]),
                let isExcludedFromBackup = resourceValues.isExcludedFromBackup {
                XCTAssert(isExcludedFromBackup)
            } else {
                XCTFail()
            }

            // test on entire directory
            try Storage.save(images, to: .documents, as: "photos/")
            try Storage.doNotBackup("photos/", in: .documents)
            let albumUrl = try Storage.url(for: "photos/", in: .documents)
            if let resourceValues = try? albumUrl.resourceValues(forKeys: [.isExcludedFromBackupKey]),
                let isExcludedFromBackup = resourceValues.isExcludedFromBackup {
                XCTAssert(isExcludedFromBackup)
            } else {
                XCTFail()
            }

            // Do not backup (URL)
            try Storage.save(messages[0], to: .documents, as: "Messages/message2.json")
            let message2Url = try Storage.url(for: "Messages/message2.json", in: .documents)
            try Storage.doNotBackup(message2Url)
            if let resourceValues = try? message2Url.resourceValues(forKeys: [.isExcludedFromBackupKey]),
                let isExcludedFromBackup = resourceValues.isExcludedFromBackup {
                XCTAssert(isExcludedFromBackup)
            } else {
                XCTFail()
            }

            // test on entire directory
            try Storage.save(images, to: .documents, as: "photos2/")
            let album2Url = try Storage.url(for: "photos2", in: .documents)
            try Storage.doNotBackup(album2Url)
            if let resourceValues = try? album2Url.resourceValues(forKeys: [.isExcludedFromBackupKey]),
                let isExcludedFromBackup = resourceValues.isExcludedFromBackup {
                XCTAssert(isExcludedFromBackup)
            } else {
                XCTFail()
            }

            // Backup
            try Storage.backup("Messages/message.json", in: .documents)
            let newMessageUrl = try Storage.url(for: "Messages/message.json", in: .documents) // we have to create a new url to access its new resource values
            if let resourceValues = try? newMessageUrl.resourceValues(forKeys: [.isExcludedFromBackupKey]),
                let isExcludedFromBackup = resourceValues.isExcludedFromBackup {
                XCTAssertFalse(isExcludedFromBackup)
            } else {
                XCTFail()
            }

            // test on entire directory
            try Storage.backup("photos/", in: .documents)
            let newAlbumUrl = try Storage.url(for: "photos/", in: .documents)
            if let resourceValues = try? newAlbumUrl.resourceValues(forKeys: [.isExcludedFromBackupKey]),
                let isExcludedFromBackup = resourceValues.isExcludedFromBackup {
                XCTAssertFalse(isExcludedFromBackup)
            } else {
                XCTFail()
            }

            // Backup (URL)
            try Storage.backup(message2Url)
            let newMessage2Url = try Storage.url(for: "Messages/message2.json", in: .documents) // we have to create a new url to access its new resource values
            if let resourceValues = try? newMessage2Url.resourceValues(forKeys: [.isExcludedFromBackupKey]),
                let isExcludedFromBackup = resourceValues.isExcludedFromBackup {
                XCTAssertFalse(isExcludedFromBackup)
            } else {
                XCTFail()
            }

            // test on entire directory
            try Storage.backup(album2Url)
            let newAlbum2Url = try Storage.url(for: "photos2/", in: .documents)
            if let resourceValues = try? newAlbum2Url.resourceValues(forKeys: [.isExcludedFromBackupKey]),
                let isExcludedFromBackup = resourceValues.isExcludedFromBackup {
                XCTAssertFalse(isExcludedFromBackup)
            } else {
                XCTFail()
            }
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testMove() {
        do {
            try Storage.save(messages[0], to: .caches, as: "message.json")
            try Storage.move("message.json", in: .caches, to: .documents)
            XCTAssertFalse(Storage.exists("message.json", in: .caches))
            XCTAssert(Storage.exists("message.json", in: .documents))

            let existingFileUrl = try Storage.url(for: "message.json", in: .documents)
            let newFileUrl = try Storage.url(for: "message.json", in: .caches)
            try Storage.move(existingFileUrl, to: newFileUrl)
            XCTAssertFalse(Storage.exists("message.json", in: .documents))
            XCTAssert(Storage.exists("message.json", in: .caches))

            // Array of images in folder hierarchy
            try Storage.save(images, to: .caches, as: "album/")
            try Storage.move("album/", in: .caches, to: .documents)
            XCTAssertFalse(Storage.exists("album/", in: .caches))
            XCTAssert(Storage.exists("album/", in: .documents))

            let existingFolderUrl = try Storage.url(for: "album/", in: .documents)
            let newFolderUrl = try Storage.url(for: "album/", in: .caches)
            try Storage.move(existingFolderUrl, to: newFolderUrl)
            XCTAssertFalse(Storage.exists("album/", in: .documents))
            XCTAssert(Storage.exists("album/", in: .caches))
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testRename() {
        do {
            try Storage.clear(.caches)
            try Storage.save(messages[0], to: .caches, as: "oldName.json")
            try Storage.rename("oldName.json", in: .caches, to: "newName.json")
            XCTAssertFalse(Storage.exists("oldName.json", in: .caches))
            XCTAssert(Storage.exists("newName.json", in: .caches))

            // Array of images in folder
            try Storage.save(images, to: .caches, as: "oldAlbumName/")
            try Storage.rename("oldAlbumName/", in: .caches, to: "newAlbumName/")
            XCTAssertFalse(Storage.exists("oldAlbumName/", in: .caches))
            XCTAssert(Storage.exists("newAlbumName/", in: .caches))
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testIsFolder() {
        do {
            try Storage.clear(.caches)
            try Storage.save(messages[0], to: .caches, as: "message.json")
            let messageUrl = try Storage.url(for: "message.json", in: .caches)
            XCTAssertFalse(Storage.isFolder(messageUrl))

            // Array of images in folder
            try Storage.clear(.caches)
            try Storage.save(images, to: .caches, as: "album/")
            let albumUrl = try Storage.url(for: "album", in: .caches)
            XCTAssertTrue(Storage.isFolder(albumUrl))
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    // MARK: Edge cases

    func testWorkingWithFolderWithoutBackSlash() {
        do {
            try Storage.save(images, to: .caches, as: "album")
            try Storage.rename("album", in: .caches, to: "newAlbumName")
            XCTAssertFalse(Storage.exists("album", in: .caches))
            XCTAssert(Storage.exists("newAlbumName", in: .caches))

            try Storage.remove("newAlbumName", from: .caches)
            XCTAssertFalse(Storage.exists("newAlbumName", in: .caches))
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testOverwrite() {
        do {
            let one = messages[1]
            let two = messages[2]
            try Storage.save(one, to: .caches, as: "message.json")
            try Storage.save(two, to: .caches, as: "message.json")
            // Array of images in folder
            let albumOne = [images[0], images[1]]
            let albumTwo = [images[1], images[2]]
            try Storage.save(albumOne, to: .caches, as: "album/")
            try Storage.save(albumTwo, to: .caches, as: "album/")
        } catch let error as NSError {
            // We want an NSCocoa error to be thrown when we try writing to the same file location again without first removing it first
            let alreadyExistsErrorCode = 516
            XCTAssert(error.code == alreadyExistsErrorCode)
        }
    }

    func testAutomaticSubFoldersCreation() {
        do {
            try Storage.save(messages, to: .caches, as: "Folder1/Folder2/Folder3/messages.json")
            XCTAssert(Storage.exists("Folder1", in: .caches))
            XCTAssert(Storage.exists("Folder1/Folder2", in: .caches))
            XCTAssert(Storage.exists("Folder1/Folder2/Folder3", in: .caches))
            XCTAssertFalse(Storage.exists("Folder2/Folder3/Folder1", in: .caches))
            XCTAssert(Storage.exists("Folder1/Folder2/Folder3/messages.json", in: .caches))

            // Array of images in folder hierarchy
            try Storage.save(images, to: .documents, as: "Folder1/Folder2/Folder3/album")
            XCTAssert(Storage.exists("Folder1", in: .documents))
            XCTAssert(Storage.exists("Folder1/Folder2", in: .documents))
            XCTAssert(Storage.exists("Folder1/Folder2/Folder3", in: .documents))
            XCTAssertFalse(Storage.exists("Folder2/Folder3/Folder1", in: .documents))
            XCTAssert(Storage.exists("Folder1/Folder2/Folder3/album", in: .documents))
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testInvalidName() {
        do {
            try Storage.save(messages, to: .documents, as: "//////messages.json")
            XCTAssert(Storage.exists("messages.json", in: .documents))
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    func testAddDifferentFileTypes() {
        do {
            try Storage.save(messages, to: .documents, as: "Folder/messages.json")
            XCTAssert(Storage.exists("Folder/messages.json", in: .documents))
            try Storage.save(images[0], to: .documents, as: "Folder/image1.png")
            XCTAssert(Storage.exists("Folder/image1.png", in: .documents))
            try Storage.save(images[1], to: .documents, as: "Folder/image2.jpg")
            XCTAssert(Storage.exists("Folder/image2.jpg", in: .documents))
            try Storage.save(images[2], to: .documents, as: "Folder/image3.jpeg")
            XCTAssert(Storage.exists("Folder/image3.jpeg", in: .documents))

            let files = try Storage.retrieve("Folder", from: .documents, as: [Data].self)
            XCTAssert(files.count == 4)

            let album = try Storage.retrieve("Folder", from: .documents, as: [UIImage].self)
            XCTAssert(album.count == 3)
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    // Test sorting of many files saved to folder as array
    func testFilesRetrievalSorting() {
        do {
            let manyObjects = data + data + data + data + data
            try Storage.save(manyObjects, to: .documents, as: "Folder/")

            let retrievedFiles = try Storage.retrieve("Folder", from: .documents, as: [Data].self)

            for i in 0..<manyObjects.count {
                let object = manyObjects[i]
                let file = retrievedFiles[i]
                XCTAssert(object == file)
            }
        } catch {
            fatalError(convertErrorToString(error))
        }
    }

    // Test saving struct/structs as a folder
    func testExpectedErrorForSavingStructsAsFilesInAFolder() {
        do {
            let oneMessage = messages[0]
            let multipleMessages = messages

            try Storage.save(oneMessage, to: .documents, as: "Folder/")
            try Storage.save(multipleMessages, to: .documents, as: "Folder/")
            try Storage.append(oneMessage, to: "Folder/", in: .documents)
            _ = try Storage.retrieve("Folder/", from: .documents, as: [Message].self)
        } catch let error as NSError {
            XCTAssert(error.code == Storage.ErrorCode.invalidFileName.rawValue)
        }
    }

    // Test iOS 11 Volume storage resource values
    func testiOS11VolumeStorageResourceValues() {
        XCTAssert(Storage.totalCapacity != nil && Storage.totalCapacity != 0)
        XCTAssert(Storage.availableCapacity != nil && Storage.availableCapacity != 0)
        XCTAssert(Storage.availableCapacityForImportantUsage != nil && Storage.availableCapacityForImportantUsage != 0)
        XCTAssert(Storage.availableCapacityForOpportunisticUsage != nil && Storage.availableCapacityForOpportunisticUsage != 0)

        print("\n\n============== Storage iOS 11 Volume Information ==============")
        print("Storage.totalCapacity = \(Storage.totalCapacity!)")
        print("Storage.availableCapacity = \(Storage.availableCapacity!)")
        print("Storage.availableCapacityForImportantUsage = \(Storage.availableCapacityForImportantUsage!)")
        print("Storage.availableCapacityForOpportunisticUsage = \(Storage.availableCapacityForOpportunisticUsage!)")
        print("============================================================\n\n")
    }

    // Test Equitability for Directory enum
    func testDirectoryEquitability() {
        let directories: [Storage.Directory] = [.documents, .caches, .applicationSupport, .temporary]
        for directory in directories {
            XCTAssert(directory == directory)
        }
        for directory in directories {
            let otherDirectories = directories.filter { $0 != directory }
            otherDirectories.forEach {
                XCTAssert($0 != directory)
            }
        }

        let sameAppGroupName = "SameName"
        let sharedDirectory1 = Storage.Directory.sharedContainer(appGroupName: sameAppGroupName)
        let sharedDirectory2 = Storage.Directory.sharedContainer(appGroupName: sameAppGroupName)
        XCTAssert(sharedDirectory1 == sharedDirectory2)

        let sharedDirectory3 = Storage.Directory.sharedContainer(appGroupName: "Another Name")
        let sharedDirectory4 = Storage.Directory.sharedContainer(appGroupName: "Different Name")
        XCTAssert(sharedDirectory3 != sharedDirectory4)
    }

    // Test custom JSONEncoder and JSONDecoder
    func testCustomEncoderDecoder() {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            // 1 struct
            try Storage.save(messages[0], to: .documents, as: "message.json", encoder: encoder)
            XCTAssert(Storage.exists("message.json", in: .documents))
            let messageUrl = try Storage.url(for: "message.json", in: .documents)
            print("A message was saved as \(messageUrl.absoluteString)")

            let retrievedMessage = try Storage.retrieve("message.json", from: .documents, as: Message.self, decoder: decoder)
            XCTAssert(messages[0] == retrievedMessage)

            // Array of structs
            try Storage.save(messages, to: .documents, as: "messages.json", encoder: encoder)
            XCTAssert(Storage.exists("messages.json", in: .documents))
            let messagesUrl = try Storage.url(for: "messages.json", in: .documents)
            print("Messages were saved as \(messagesUrl.absoluteString)")
            let retrievedMessages = try Storage.retrieve("messages.json", from: .documents, as: [Message].self, decoder: decoder)
            XCTAssert(messages == retrievedMessages)

            // Append
            try Storage.append(messages[0], to: "messages.json", in: .documents, decoder: decoder, encoder: encoder)
            let retrievedUpdatedMessages = try Storage.retrieve("messages.json", from: .documents, as: [Message].self, decoder: decoder)
            XCTAssert((messages + [messages[0]]) == retrievedUpdatedMessages)
        } catch {
            fatalError(convertErrorToString(error))
        }
    }
}
#endif
