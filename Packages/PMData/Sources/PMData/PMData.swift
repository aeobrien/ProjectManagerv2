// PMData — SQLite persistence via GRDB, repository implementations, CRUD.
// Depends on PMDomain for entity types and protocols.
//
// Populated in Phase 2.

import PMDomain
import PMUtilities
import GRDB

public enum PMDataMarker {
    public static let version = "0.1.0"
}
