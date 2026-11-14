///| Public MockProvider for testing agent loops

///|
pub struct MockProvider {
  responses : Array[Array[StreamEvent]]
  mut call_count : Int
}

///|
pub fn MockProvider::new(responses : Array[Array[StreamEvent]]) -> MockProvider {
  { responses, call_count: 0 }
}

///|
impl Provider for MockProvider with fn stream(self, _messages, _tools, handler) {
  if self.call_count < self.responses.length() {
    let events = self.responses[self.call_count]
    self.call_count += 1
    for event in events {
      (handler.on_event)(event)
    }
  }
}

///|
impl Provider for MockProvider with fn name(_self) -> String {
  "mock"
}

///|
pub fn MockProvider::boxed(self : MockProvider) -> BoxedProvider {
  BoxedProvider::new(self)
}
