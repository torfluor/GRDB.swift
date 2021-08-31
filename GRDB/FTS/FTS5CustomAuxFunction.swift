//
//  FTS5CustomAuxFunction.swift
//  GRDBCustom
//
//  Created by Tor Øyvind Fluør on 25/08/2021.
//

import Foundation

extension Database {
 
    private class FTS5AuxFunctionConstructor {
        let db: Database
        let constructor: (Database, [String], UnsafeMutablePointer<OpaquePointer?>?) -> Int32
        
        init(
            db: Database,
            constructor: @escaping (Database, [String], UnsafeMutablePointer<OpaquePointer?>?) -> Int32)
        {
            self.db = db
            self.constructor = constructor
        }
    }
    
    public func addMatchIndexAuxFunction() {
        
        let api = FTS5.api(self)
        
        let constructor = FTS5AuxFunctionConstructor(
            db: self,
            constructor: { (db, arguments, tokenizerHandle) in
                return SQLITE_OK
            })
        
        
        // Constructor must remain alive until deleteConstructor() is
        // called, as the last argument of the xCreateTokenizer() function.
        let constructorPointer = Unmanaged.passRetained(constructor).toOpaque()
        
        
        func deleteConstructor(constructorPointer: UnsafeMutableRawPointer?) {
            guard let constructorPointer = constructorPointer else { return }
            Unmanaged<AnyObject>.fromOpaque(constructorPointer).release()
        }
        
        _ = api.pointee.xCreateFunction(
                UnsafeMutablePointer(mutating: api),
                "matchindex",
                constructorPointer,
            { pApi, pFts, pCtx, nVal, apVal in
                
                guard let pApi = pApi,
                      let pCtx = pCtx
                else {
                    sqlite3_result_error_code(pCtx, SQLITE_ERROR)
                    return
                }
                
                var rc: Int32 = 0
                var results = [String]()
                
                var instCount: Int32 = 0
                rc = withUnsafeMutablePointer(to: &instCount) { instCountPointer in
                    pApi.pointee.xInstCount(pFts, instCountPointer)
                }

                var phrase: Int32 = 0
                var column: Int32 = 0
                var offset: Int32 = 0
                
                for i in 0..<instCount {
                    withUnsafeMutablePointer(to: &phrase) { piPhrasePointer in
                        withUnsafeMutablePointer(to: &column) { piColPointer in
                            withUnsafeMutablePointer(to: &offset) { piOffPointer in
                                rc = pApi.pointee.xInst(pFts, i, piPhrasePointer, piColPointer, piOffPointer)
                            }
                        }
                    }
                    
                    guard rc == SQLITE_OK else {
                        sqlite3_result_error_code(pCtx, rc)
                        return
                    }
                    
                    results.append("\(offset)")
                }
                
                let resultsStr = results.joined(separator: ",")
                sqlite3_result_text(pCtx, resultsStr, -1, SQLITE_TRANSIENT)
            },
                deleteConstructor)
    }
    
}
