/// A packet's sender, not the endpoint running the monitor.

///|
pub(all) enum Side {
  Client
  Server
} derive(Eq)

///|
pub extend Side with Eq::{equal, not_equal}

/// The monitor stops at the first invalid event to avoid cascading diagnoses.
/// Event indices are one-based, including transport-close and clock events.

///|
pub(all) struct Diagnostic {
  event : Int32
  rule : String
  detail : String
} derive(ToJson)

///|
pub extend Diagnostic with ToJson::{to_json}

/// `valid_prefix` means only that observed events satisfy implemented rules.
/// `complete` also requires no outstanding handshake or acknowledgement.
/// Neither is a statement about unobserved application delivery or certification.

///|
pub(all) struct Report {
  valid_prefix : Bool
  complete : Bool
  events : Int32
  connections : Int32
  completed_publications : Int32
  retransmissions : Int32
  pending : Int32
  abandoned : Int32
  diagnostics : Array[Diagnostic]
} derive(ToJson)

///|
pub extend Report with ToJson::{to_json}

///|
priv enum Phase {
  Offline
  AwaitConnack
  Active
  Closing
} derive(Eq)

///|
priv enum Stage {
  AwaitPuback
  AwaitPubrec
  AwaitPubrel
  AwaitPubcomp
  AwaitSuback(Array[@codec.QoS])
  AwaitUnsuback
}

/// The sender owns the identifier until the terminal acknowledgement.
/// Client and server identifier spaces are independent.

///|
priv struct Flight {
  stage : Stage
  publication : @codec.Publish?
}

/// A bounded, deterministic observer of one client and its server across TCP
/// connections. Feed both directions in capture order with monotonic ms time.
/// Persistent resumption requires the same client ID and Session Present=true;
/// missing broker state is reported as an unsupported observation boundary.

///|
pub struct Monitor {
  priv mut phase : Phase
  priv mut client_id : String?
  priv mut clean : Bool
  priv mut session_known : Bool
  priv mut resuming : Bool
  priv mut keep_alive_ms : Int64
  priv mut last_client_ms : Int64
  priv mut now_ms : Int64
  priv mut ping : Bool
  priv mut events : Int32
  priv mut connections : Int32
  priv mut completed : Int32
  priv mut abandoned : Int32
  priv mut retransmissions : Int32
  priv client_flights : Map[Int32, Flight]
  priv server_flights : Map[Int32, Flight]
  priv diagnostics : Array[Diagnostic]
  priv max_inflight : Int32
}

///|
pub fn Monitor::new(max_inflight~ : Int32 = 1024) -> Monitor {
  {
    phase: Offline,
    client_id: None,
    clean: true,
    session_known: false,
    resuming: false,
    keep_alive_ms: 0L,
    last_client_ms: 0L,
    now_ms: 0L,
    ping: false,
    events: 0,
    connections: 0,
    completed: 0,
    abandoned: 0,
    retransmissions: 0,
    client_flights: {},
    server_flights: {},
    diagnostics: [],
    max_inflight: if max_inflight > 0 {
      max_inflight
    } else {
      1
    },
  }
}

/// Return a detached report: later observation cannot mutate its diagnostics.

///|
pub fn Monitor::report(self : Monitor) -> Report {
  let pending = self.client_flights.length() + self.server_flights.length()
  let valid_prefix = self.diagnostics.is_empty()
  {
    valid_prefix,
    complete: valid_prefix &&
    self.connections > 0 &&
    pending == 0 &&
    self.abandoned == 0 &&
    !self.ping &&
    self.phase != AwaitConnack,
    events: self.events,
    connections: self.connections,
    completed_publications: self.completed,
    retransmissions: self.retransmissions,
    pending,
    abandoned: self.abandoned,
    diagnostics: self.diagnostics.copy(),
  }
}

///|
fn Monitor::reject(self : Monitor, rule : String, detail : String) -> Bool {
  if self.diagnostics.is_empty() {
    self.diagnostics.push({ event: self.events, rule, detail, })
  }
  false
}

///|
fn Monitor::flights(self : Monitor, sender : Side) -> Map[Int32, Flight] {
  match sender {
    Client => self.client_flights
    Server => self.server_flights
  }
}

///|
fn other(side : Side) -> Side {
  match side {
    Client => Server
    Server => Client
  }
}

///|
fn qos_number(qos : @codec.QoS) -> Int32 {
  match qos {
    @codec.QoS0 => 0
    @codec.QoS1 => 1
    @codec.QoS2 => 2
  }
}
