//
//  Created by Cristian Baluta on 03/01/2018.
//  Copyright © 2018 Baluta Cristian. All rights reserved.
//

import Foundation
import CoreData

extension RCCloudKitSyncer {
    
    func objsToSave() -> [NSManagedObject] {
        
        var objs = [NSManagedObject]()
        let entities = moc.persistentStoreCoordinator!.managedObjectModel.entities
        for entity in entities {
            
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name!)
            request.predicate = NSPredicate(format: "recordName == nil || date > %@", UserDefaults.standard.lastSyncDate! as CVarArg)
            
            if let fetchedObjs = try? moc.fetch(request) as? [NSManagedObject], let o = fetchedObjs {
                objs += o
            }
        }
        return objs
    }
    
    func objsToDelete() -> [NSManagedObject] {
        
        var objs = [NSManagedObject]()
        let entities = moc.persistentStoreCoordinator!.managedObjectModel.entities
        for entity in entities {
            
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name!)
            request.predicate = NSPredicate(format: "markedForDeletion == true")
            
            if let fetchedObjs = try? moc.fetch(request) as? [NSManagedObject], let o = fetchedObjs {
                objs += o
            }
        }
        return objs
    }
}
