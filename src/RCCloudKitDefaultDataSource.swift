//
//  Created by Cristian Baluta on 03/01/2018.
//  Copyright © 2018 Baluta Cristian. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

@objc class RCCloudKitDefaultDataSource: NSObject {
    
    var moc: NSManagedObjectContext!
    
    @objc convenience init (moc: NSManagedObjectContext) {
        self.init()
        self.moc = moc
    }
}

extension RCCloudKitDefaultDataSource: RCCloudKitDataSource {
    
    func managedObject (from record: CKRecord) -> NSManagedObject? {
        
        let entityName = record.recordType
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        request.predicate = NSPredicate(format: "recordName == %@", record.recordID.recordName as CVarArg)
        if let fetchedObj = try? moc.fetch(request) as? [NSManagedObject] {
            return fetchedObj.first
        }
        return nil
    }
    
    func recordID (from managedObject: NSManagedObject) -> CKRecord.ID? {
        return managedObject.value(forKey: "recordID") as? CKRecord.ID
    }
    
    func managedObjectsToUpload() -> [NSManagedObject] {
        
        var objs = [NSManagedObject]()
        let entities = moc.persistentStoreCoordinator!.managedObjectModel.entities
        for entity in entities {
            guard !RCCloudKit.ignoredEntities.contains(entity.name!) else {
                continue
            }
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name!)
            request.predicate = NSPredicate(format: "isUploaded == false")
            
            if let fetchedObjs = try? moc.fetch(request) as? [NSManagedObject] {
                objs += fetchedObjs
            }
        }
        return objs
    }
    
    func managedObjectsToDelete() -> [NSManagedObject] {
        
        var objs = [NSManagedObject]()
        let entities = moc.persistentStoreCoordinator!.managedObjectModel.entities
        for entity in entities {
            guard !RCCloudKit.ignoredEntities.contains(entity.name!) else {
                continue
            }
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name!)
            request.predicate = NSPredicate(format: "markedForDeletion == true")
            
            if let fetchedObjs = try? moc.fetch(request) as? [NSManagedObject] {
                objs += fetchedObjs
            }
        }
        return objs
    }
}
