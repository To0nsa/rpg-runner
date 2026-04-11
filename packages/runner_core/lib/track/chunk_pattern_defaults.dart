/// Default authored pacing windows for procedural chunk selection.
library;

/// Default count of opening chunks that request the `early` tier.
const int defaultEarlyPatternChunks = 3;

/// Default count of chunks after the opening window that request the `easy`
/// tier.
const int defaultEasyPatternChunks = 0;

/// Default count of chunks after the easy window that request the `normal`
/// tier.
const int defaultNormalPatternChunks = 0;

/// Default count of early chunks that suppress enemy spawns.
const int defaultNoEnemyChunks = 3;
