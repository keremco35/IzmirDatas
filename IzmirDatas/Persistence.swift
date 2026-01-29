import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    private let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "IzmirDatasModel", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError(error.localizedDescription)
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func loadDatasetPayload(datasetKey: String) throws -> (payload: Data, lastUpdated: Date)? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CachedDataset")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "datasetKey == %@", datasetKey)

        let result = try viewContext.fetch(request).first
        guard
            let result,
            let payload = result.value(forKey: "payload") as? Data,
            let lastUpdated = result.value(forKey: "lastUpdated") as? Date
        else {
            return nil
        }

        return (payload, lastUpdated)
    }

    func saveDatasetPayload(datasetKey: String, payload: Data, lastUpdated: Date = Date()) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CachedDataset")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "datasetKey == %@", datasetKey)

        let existing = try viewContext.fetch(request).first
        let object: NSManagedObject
        if let existing {
            object = existing
        } else {
            let entity = container.managedObjectModel.entitiesByName["CachedDataset"]!
            object = NSManagedObject(entity: entity, insertInto: viewContext)
            object.setValue(datasetKey, forKey: "datasetKey")
        }

        object.setValue(payload, forKey: "payload")
        object.setValue(lastUpdated, forKey: "lastUpdated")

        if viewContext.hasChanges {
            try viewContext.save()
        }
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let cachedDataset = NSEntityDescription()
        cachedDataset.name = "CachedDataset"
        cachedDataset.managedObjectClassName = "NSManagedObject"

        let datasetKey = NSAttributeDescription()
        datasetKey.name = "datasetKey"
        datasetKey.attributeType = .stringAttributeType
        datasetKey.isOptional = false

        let payload = NSAttributeDescription()
        payload.name = "payload"
        payload.attributeType = .binaryDataAttributeType
        payload.isOptional = false

        let lastUpdated = NSAttributeDescription()
        lastUpdated.name = "lastUpdated"
        lastUpdated.attributeType = .dateAttributeType
        lastUpdated.isOptional = false

        cachedDataset.properties = [datasetKey, payload, lastUpdated]

        let datasetKeyIndex = NSFetchIndexDescription(name: "datasetKeyIndex", elements: [
            NSFetchIndexElementDescription(property: datasetKey, collationType: .binary)
        ])
        cachedDataset.indexes = [datasetKeyIndex]

        model.entities = [cachedDataset]
        return model
    }
}
