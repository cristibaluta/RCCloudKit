//
//  Created by Cristian Baluta on 02/04/2017.
//  Copyright © 2017 Imagin soft. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

extension RCCloudKit {
    
    func queryUpdates (_ completion: @escaping ([NSManagedObject], [String], NSError?) -> Void) {
        
        let changeToken = UserDefaults.standard.serverChangeToken
        
        fetchChangedRecords(token: changeToken, completion: { (changedRecords, deletedRecordsIds) in
            
            // Save CKRecord to CoreData
            let objects = self.objsFromRecords(changedRecords)
            // Delete CoreData objects
            let deletedRecordNames: [String] = deletedRecordsIds.map { $0.recordName }
            let entities = self.moc.persistentStoreCoordinator!.managedObjectModel.entities
            for recordName in deletedRecordNames {
                for entity in entities {
                    let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name!)
                    request.predicate = NSPredicate(format: "recordName == %@", recordName as CVarArg)
                    if let fetchedObj = try? self.moc.fetch(request) as? [NSManagedObject], let obj = fetchedObj?.first {
                        self.moc.delete(obj)
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(objects, deletedRecordNames, nil)
            }
        })
    }
    
    func save (_ obj: NSManagedObject, completion: @escaping ((_ obj: NSManagedObject) -> Void)) {
        print(">>>>> 1. Save to cloudkit \(obj)")
        
        guard let zone = self.customZone, let privateDB = self.privateDB, let entityName = obj.entity.name else {
            print("Can't save, not logged in to iCloud or zone not ready")
            completion(obj)
            return
        }
        
        // Query from server if exists
        fetchCKRecord(of: obj) { (record) in
            
            var record: CKRecord? = record
            if record == nil {
                print("Record not found on server, create it now:")
                record = CKRecord(recordType: entityName, zoneID: zone.zoneID)
            }
            record = self.updateRecord(record!, with: obj)
            print(record)
            
            privateDB.save(record!, completionHandler: { savedRecord, error in
                
                // 
                obj.setValue(savedRecord?.recordID, forKey: "recordId")
                obj.setValue(savedRecord?.recordID.recordName, forKey: "recordName")
                
                print(">>>>> 2. Record after saving to CloudKit:")
                print(savedRecord)
//                print(obj)
//                print(error)
                
                completion(obj)
            })
        }
    }
    
    func delete (_ obj: NSManagedObject, completion: @escaping ((_ success: Bool) -> Void)) {
        
        guard let _ = self.customZone, let privateDB = self.privateDB else {
            print("Not logged in or zone not created")
            completion(false)
            return
        }
        guard let recordId = obj.value(forKey: "recordId") as? CKRecordID else {
            completion(true)// The object is not yet uploaded to CK, means we can consider it was deleted with success
            return
        }
        privateDB.delete(withRecordID: recordId, completionHandler: { (recordName, error) in
            completion(error != nil)
        })
    }
}

extension RCCloudKit {
    
    func fetchCKRecord (of obj: NSManagedObject, completion: @escaping ((_ cobj: CKRecord?) -> Void)) {
        
        guard let privateDB = self.privateDB else {
            completion(nil)
            print("Not logged in")
            return
        }
        guard let recordId = obj.value(forKey: "recordId") as? CKRecordID else {
            completion(nil)
            return
        }
        
        privateDB.fetch(withRecordID: recordId) { (record, error) in
            
            print(error)
            
            if let record = record {
                completion(record)
            } else {
                completion(nil)
            }
        }
    }
    
    fileprivate func objsFromRecords (_ records: [CKRecord]) -> [NSManagedObject] {
        return records.map { self.obj(from: $0) }
    }
    
    fileprivate func obj (from record: CKRecord) -> NSManagedObject {
        
        let entityName = record.recordType
        var obj: NSManagedObject? = nil
        if let o = dataSource?.managedObject(from: record) {
            obj = o
        }
        if obj == nil {
            print("fetching entity \(entityName) with recordName \(record.recordID.recordName)")
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            request.predicate = NSPredicate(format: "recordName == %@", record.recordID.recordName as CVarArg)
            request.returnsObjectsAsFaults = false
            if let fetchedObj = try? moc.fetch(request) as? [NSManagedObject] {
                obj = fetchedObj?.first
            }
        }
        if obj == nil {
            print(">>>>>> obj for record not found, creating one now")
            obj = NSEntityDescription.insertNewObject(forEntityName: entityName, into: moc)
        }
        obj = updateObj(obj!, with: record)
        print(obj)
        
        return obj!
    }
    
    fileprivate func updateObj (_ obj: NSManagedObject, with record: CKRecord) -> NSManagedObject {
        
        for key in record.allKeys() {
            obj.setValue(record[key], forKey: key)
        }
        obj.setValue(record.recordID, forKey: "recordId") 
        obj.setValue(record.recordID.recordName, forKey: "recordName") 
        
        return obj
    }
    
    fileprivate func updateRecord (_ record: CKRecord, with obj: NSManagedObject) -> CKRecord {
        
        let changedAttributes = Array(obj.changedValues().keys)
        for key in changedAttributes {
            record[key] = obj.value(forKey: key) as? CKRecordValue
        }
        
        return record
    }
}
