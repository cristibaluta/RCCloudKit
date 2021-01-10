//
//  CKRecordIDTransformer.swift
//  cmdc
//
//  Created by Cristian Baluta on 19.12.2020.
//  Copyright © 2020 Imagin soft. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

@available(OSX 10.14, *)
@objc(CKRecordIDTransformer)
final class CKRecordIDTransformer: NSSecureUnarchiveFromDataTransformer {

    static let name = NSValueTransformerName(rawValue: String(describing: CKRecordIDTransformer.self))

    override static var allowedTopLevelClasses: [AnyClass] {
        return [CKRecord.ID.self]
    }

    /// Registers the transformer.
    public static func register() {
        let transformer = CKRecordIDTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
}
