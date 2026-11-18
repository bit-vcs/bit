///|
#derive(@debug.Debug)
pub(all) enum Signal {
  SIGINT
  SIGTERM
  SIGHUP
  SIGBREAK
}

///|
pub extend Signal with @debug.Debug::{to_repr}
