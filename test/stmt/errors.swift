// RUN: %target-typecheck-verify-swift
enum MSV : Error {
  case Foo, Bar, Baz

  var _domain: String { return "" }
  var _code: Int { return 0 }
}

func a() {}
func b() {}
func c() {}
func d() {}
func e() {}
func thrower() throws {}

func opaque_error() -> Error { return MSV.Foo }

func one() {
  throw MSV.Foo // expected-error {{error is not handled because the enclosing function is not declared 'throws'}}
}

func two() {
  throw opaque_error() // expected-error {{error is not handled because the enclosing function is not declared 'throws'}}
}

func three() {
  do {
    throw opaque_error() // expected-error {{error is not handled because the enclosing catch is not exhaustive}}
  } catch let e as MSV {
    _ = e
  }
}

func four() {
  do {
    throw opaque_error()
  } catch let e {
    _ = e
  }
}

func five() {
  do {
    throw opaque_error()
  } catch let e as MSV {
    _ = e
  } catch _ {
  }
}

func six() {
  do {
    do {
      throw opaque_error()
    } catch let e as MSV {
      _ = e
    }
  } catch _ {
  }
}

func seven_helper() throws -> Int { throw MSV.Baz }

struct seven {
  var x: Int {
    do {
      return try seven_helper()
    } catch {
      return 0
    }
  }

  var y: Int {
    return try! seven_helper()
  }

  var z: Int {
    return (try? seven_helper()) ?? 0
  }
}

class eight {
  lazy var x: Int = {
    do {
      return try seven_helper()
    } catch {
      return 0
    }
  }()

  lazy var y: Int = {
    return try! seven_helper()
  }()

  lazy var z: Int = {
    return (try? seven_helper()) ?? 0
  }()
}

protocol ThrowingProto {
  func foo() throws
  static func bar() throws
}

func testExistential(_ p : ThrowingProto) throws {
  try p.foo()
  try type(of: p).bar()
}
func testGeneric<P : ThrowingProto>(p : P) throws {
  try p.foo()
  try P.bar()
}

// Don't warn about the "useless" try in these cases.
func nine_helper(_ x: Int, y: Int) throws {} // expected-note {{'nine_helper(_:y:)' declared here}}
func nine() throws {
  try nine_helper(y: 0) // expected-error {{missing argument for parameter #1 in call}}
}
func ten_helper(_ x: Int) {}
func ten_helper(_ x: Int, y: Int) throws {}
func ten() throws {
  try ten_helper(y: 0) // expected-error {{extraneous argument label 'y:' in call}} {{18-21=}}
}

// rdar://21074857
func eleven_helper(_ fn: () -> ()) {}
func eleven_one() {
  eleven_helper {
    do {
      try thrower()
    // FIXME: suppress the double-emission of the 'always true' warning
    } catch let e as Error { // expected-warning {{immutable value 'e' was never used}} {{17-18=_}} expected-warning 2 {{'as' test is always true}}
    }
  }
}
func eleven_two() {
  eleven_helper { // expected-error {{invalid conversion from throwing function of type '() throws -> ()' to non-throwing function type '() -> ()'}}
    do {
      try thrower()
    } catch let e as MSV {
    }
  }
}

enum Twelve { case Payload(Int) }
func twelve_helper(_ fn: (Int, Int) -> ()) {}
func twelve() {
  twelve_helper { (a, b) in // expected-error {{invalid conversion from throwing function of type '(Int, Int) throws -> ()' to non-throwing function type '(Int, Int) -> ()'}}
    do {
      try thrower()
    } catch Twelve.Payload(a...b) {
    }
  }
}

struct Thirteen : Error, Equatable {}
func ==(a: Thirteen, b: Thirteen) -> Bool { return true }

func thirteen_helper(_ fn: (Thirteen) -> ()) {}
func thirteen() {
  thirteen_helper { (a) in // expected-error {{invalid conversion from throwing function of type '(Thirteen) throws -> ()' to non-throwing function type '(Thirteen) -> ()'}}
    do {
      try thrower()
    } catch a {
    }
  }
}

// SR 6400

enum SR_6400_E: Error {
  case castError
}

struct SR_6400_S_1 {}
struct SR_6400_S_2: Error {}

protocol SR_6400_FakeApplicationDelegate: AnyObject {}
class SR_6400_FakeViewController {}

func sr_6400() throws {
  do {
    throw SR_6400_E.castError
  } catch is SR_6400_S_1 { // expected-warning {{cast from 'Error' to unrelated type 'SR_6400_S_1' always fails}}
    print("Caught error")
  }
  
  do {
    throw SR_6400_E.castError
  } catch is SR_6400_S_2 {
    print("Caught error") // Ok
  }
}

func sr_6400_1<T>(error: Error, as type: T.Type) -> Bool {
  return (error as? T) != nil // Ok
}

func sr_6400_2(error: Error) {
  _ = error as? (SR_6400_FakeViewController & Error) // Ok
}
func sr_6400_3(error: Error) {
  _ = error as? (Error & SR_6400_FakeApplicationDelegate) // Ok
}

class SR_6400_A {}
class SR_6400_B: SR_6400_FakeApplicationDelegate & Error {}

func sr_6400_4() {
  do {
    throw SR_6400_E.castError
  } catch let error as SR_6400_A { // expected-warning {{cast from 'Error' to unrelated type 'SR_6400_A' always fails}} // expected-warning {{immutable value 'error' was never used; consider replacing with '_' or removing it}}
    print("Foo")
  } catch {
    print("Bar")
  }
  
  do {
    throw SR_6400_E.castError
  } catch let error as SR_6400_B { // expected-warning {{immutable value 'error' was never used; consider replacing with '_' or removing it}}
    print("Foo")
  } catch {
    print("Bar")
  }
}
