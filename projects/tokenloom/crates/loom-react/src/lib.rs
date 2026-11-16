//! Reactors, the warning lifecycle, and the constraints they evaluate.

pub mod constraint;
pub mod pool;
pub mod reactors;
pub mod warning;

pub use constraint::{Constraint, ConstraintIndex, ConstraintKind};
pub use pool::{Pool, PoolConfig, PoolEvent};
pub use reactors::{builtin_reactors, BatchView, Reaction, Reactor};
pub use warning::{
    key_of, EngineEvent, Key, Warning, WarningEngine, WarningKind, FLAP_WINDOW_MS, MAX_WARNINGS,
    QUIET_PERIOD_MS,
};
