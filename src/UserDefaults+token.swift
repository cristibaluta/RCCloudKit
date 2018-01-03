//
//  Created by Cristian Baluta on 09/04/2017.
//  Copyright © 2017 Imagin soft. All rights reserved.
//

import Foundation
import CloudKit

public extension UserDefaults {
    
    var serverChangeToken: CKServerChangeToken? {
        get {
            guard let data = self.value(forKey: "ChangeToken") as? Data else {
                return nil
            }
            guard let token = NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken else {
                return nil
            }
            
            return token
        }
        set {
            if let token = newValue {
                let data = NSKeyedArchiver.archivedData(withRootObject: token)
                self.set(data, forKey: "ChangeToken")
                self.synchronize()
            } else {
                self.removeObject(forKey: "ChangeToken")
            }
        }
    }
    
    var lastSyncDate: Date? {
        get {
            if let date = self.value(forKey: "LastSyncDate") as? Date {
                return date
            } else {
                return Date(timeIntervalSince1970: 0)
            }
        }
        set {
            self.set(newValue, forKey: "LastSyncDate")
            self.synchronize()
        }
    }
}
