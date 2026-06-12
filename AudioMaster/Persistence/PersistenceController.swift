import CoreData
import Foundation

final class PersistenceController {
    static let shared = PersistenceController()
    static let preview = PersistenceController(inMemory: true)

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "AudioMaster")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var viewContext: NSManagedObjectContext { container.viewContext }

    func save() throws {
        let context = viewContext
        guard context.hasChanges else { return }
        try context.save()
    }

    // MARK: - AudioDeviceEntity

    func upsertDevice(_ device: AudioDevice) throws {
        let context = viewContext
        let request = AudioDeviceEntity.fetchRequest()
        if let uid = device.deviceUID {
            request.predicate = NSPredicate(format: "deviceUID == %@", uid)
        } else {
            request.predicate = NSPredicate(format: "id == %@", device.id as CVarArg)
        }

        let entity: AudioDeviceEntity
        if let existing = try context.fetch(request).first {
            entity = existing
        } else {
            entity = AudioDeviceEntity(context: context)
            entity.id = device.id
            entity.createdAt = Date()
        }

        entity.name = device.name
        entity.type = device.type.rawValue
        entity.isInput = device.isInput
        entity.isOutput = device.isOutput
        entity.channels = Int16(device.channels)
        entity.sampleRate = device.sampleRate
        entity.manufacturer = device.manufacturer
        entity.deviceUID = device.deviceUID
        entity.isSystemDefault = device.isSystemDefault
        entity.lastUsed = Date()

        try save()
    }

    func fetchDevices() throws -> [AudioDevice] {
        let request = AudioDeviceEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "lastUsed", ascending: false)]
        let entities = try viewContext.fetch(request)
        return entities.compactMap { $0.toAudioDevice() }
    }

    func markDeviceLastUsed(_ device: AudioDevice) throws {
        let request = AudioDeviceEntity.fetchRequest()
        if let uid = device.deviceUID {
            request.predicate = NSPredicate(format: "deviceUID == %@", uid)
        } else {
            request.predicate = NSPredicate(format: "id == %@", device.id as CVarArg)
        }

        guard let entity = try viewContext.fetch(request).first else { return }
        entity.lastUsed = Date()
        entity.isSystemDefault = true
        try save()
    }
}

private extension AudioDeviceEntity {
    func toAudioDevice() -> AudioDevice? {
        guard let id, let name, let typeRaw = type, let deviceType = DeviceType(rawValue: typeRaw) else {
            return nil
        }
        return AudioDevice(
            id: id,
            coreAudioID: 0,
            name: name,
            type: deviceType,
            isInput: isInput,
            isOutput: isOutput,
            channels: Int(channels),
            sampleRate: sampleRate,
            manufacturer: manufacturer,
            isSystemDefault: isSystemDefault,
            isConnected: false,
            deviceUID: deviceUID
        )
    }
}
