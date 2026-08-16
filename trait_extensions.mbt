///|
pub extend JsonEdit with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend JsonEdit with Eq::{not_equal, equal}

///|
pub extend JsonEdit with ToJson::{to_json}

///|
pub extend JsonArrayEdit with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend JsonArrayEdit with Eq::{not_equal, equal}
