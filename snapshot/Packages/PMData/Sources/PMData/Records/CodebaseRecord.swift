import Foundation
import GRDB
import PMDomain

extension Codebase: @retroactive FetchableRecord, @retroactive PersistableRecord {
    public static let databaseTableName = "codebase"

    // Codebase.SourceType is a String-backed Codable enum, so GRDB's automatic
    // Codable column mapping handles it natively. bookmarkData maps to .blob.
    // No custom encode/init needed.
}
