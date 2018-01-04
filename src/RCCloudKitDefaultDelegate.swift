//
//  RCCloudKitDefaultDelegate.swift
//  Utilitati
//
//  Created by Cristian Baluta on 04/01/2018.
//  Copyright © 2018 Baluta Cristian. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

@objc class RCCloudKitDefaultDelegate: NSObject {
    
    var moc: NSManagedObjectContext!
    
    convenience init(moc: NSManagedObjectContext) {
        self.init()
        self.moc = moc
    }
}

extension RCCloudKitDefaultDelegate: RCCloudKitDelegate {
    
    func delete(with recordId: CKRecordID) {
        
        let entities = moc.persistentStoreCoordinator!.managedObjectModel.entities
        for entity in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name!)
            request.predicate = NSPredicate(format: "recordName == %@", recordId.recordName as CVarArg)
            if let fetchedObj = try? self.moc.fetch(request) as? [NSManagedObject], let obj = fetchedObj?.first {
                self.moc.delete(obj)
            }
        }
    }
    
    func save(record: CKRecord, in managedObject: NSManagedObject) -> NSManagedObject {
        
        managedObject.setValue(record.recordID, forKey: "recordId")
        managedObject.setValue(record.recordID.recordName, forKey: "recordName")
        
        return managedObject
    }
}
