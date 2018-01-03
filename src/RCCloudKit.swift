//
//  Created by Cristian Baluta on 09/06/16.
//  Copyright © 2016 Cristian Baluta. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

@objc protocol RCCloudKitDataSource {
    func managedObject(from record: CKRecord) -> NSManagedObject?
}

@objc class RCCloudKit: NSObject {
    
    internal var container: CKContainer?
    internal var privateDB: CKDatabase?
    internal var customZone: CKRecordZone?
    var moc: NSManagedObjectContext!
    var didCreateZone: (() -> Void)?
    var dataSource: RCCloudKitDataSource?
    
    convenience init(moc: NSManagedObjectContext, identifier: String, zoneName: String) {
        self.init()
        self.moc = moc
        container = CKContainer(identifier: identifier)
        privateDB = container?.privateCloudDatabase
        privateDB!.save( CKRecordZone(zoneName: zoneName) ) { (recordZone, err) in
            print("Zone created \(String(describing: recordZone))")
            if err == nil {
                self.customZone = recordZone
                self.didCreateZone?()
            }
        }
    }
    
    func fetchChangedRecords (token: CKServerChangeToken?,
                              completion: @escaping ((_ changedRecords: [CKRecord], _ deletedRecordsIds: [CKRecordID]) -> Void)) {
        
        var changedRecords = [CKRecord]()
        var deletedRecordsIds = [CKRecordID]()

        guard let customZone = self.customZone, let privateDB = self.privateDB else {
            print("Not logged in or zone not created")
            completion(changedRecords, deletedRecordsIds)
            return
        }
        
        let options = CKFetchRecordZoneChangesOptions()
//        options.previousServerChangeToken = token
        let op = CKFetchRecordZoneChangesOperation(recordZoneIDs: [customZone.zoneID], 
                                                   optionsByRecordZoneID: [customZone.zoneID: options])
        op.fetchAllChanges = true
        op.recordChangedBlock = { record in
//            print(record)
            changedRecords.append(record)
        }
        op.recordWithIDWasDeletedBlock = { (recordName, id) in
//            print(recordName)
            deletedRecordsIds.append(recordName)
        }
        op.recordZoneFetchCompletionBlock = { (zoneId, serverChangeToken, clientChangeTokenData, more, error) in
//            print(serverChangeToken)
//            print(clientChangeTokenData)
            if !more {
                UserDefaults.standard.serverChangeToken = serverChangeToken
                completion(changedRecords, deletedRecordsIds)
            }
        }
//        op.recordZoneChangeTokensUpdatedBlock = { (zoneId, serverChangeToken, clientChangeTokenData) in
//            print(serverChangeToken)
//            print(clientChangeTokenData)
//            UserDefaults.standard.serverChangeToken = serverChangeToken
//        }
//        op.fetchRecordZoneChangesCompletionBlock = { error in
//            print(error)
//            completion(changedRecords, deletedRecordsIds)
//        }
        
        privateDB.add(op)
    }
    
    func fetchRecords (ofType type: String, predicate: NSPredicate, completion: @escaping ((_ ckRecord: [CKRecord]?) -> Void)) {
        
        guard let customZone = self.customZone, let privateDB = self.privateDB else {
            print("Not logged in")
            return
        }
        
        let query = CKQuery(recordType: type, predicate: predicate)
        privateDB.perform(query, inZoneWith: customZone.zoneID) { (results: [CKRecord]?, error) in
            
            if let results = results {
                completion(results)
            } else {
                completion(nil)
            }
        }
    }
}

