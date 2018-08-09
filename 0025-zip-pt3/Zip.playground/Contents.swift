import Foundation

func zip2<A, B>(_ xs: [A], _ ys: [B]) -> [(A, B)] {
  var result: [(A, B)] = []
  (0..<min(xs.count, ys.count)).forEach { idx in
    result.append((xs[idx], ys[idx]))
  }
  return result
}

func zip3<A, B, C>(_ xs: [A], _ ys: [B], _ zs: [C]) -> [(A, B, C)] {
  return zip2(xs, zip2(ys, zs)) // [(A, (B, C))]
    .map { a, bc in (a, bc.0, bc.1) }
}

func zip2<A, B, C>(
  with f: @escaping (A, B) -> C
  ) -> ([A], [B]) -> [C] {

  return { zip2($0, $1).map(f) }
}

func zip3<A, B, C, D>(
  with f: @escaping (A, B, C) -> D
  ) -> ([A], [B], [C]) -> [D] {

  return { zip3($0, $1, $2).map(f) }
}

func zip2<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
  guard let a = a, let b = b else { return nil }
  return (a, b)
}

func zip3<A, B, C>(_ a: A?, _ b: B?, _ c: C?) -> (A, B, C)? {
  return zip2(a, zip2(b, c))
    .map { a, bc in (a, bc.0, bc.1) }
}

func zip2<A, B, C>(
  with f: @escaping (A, B) -> C
  ) -> (A?, B?) -> C? {

  return { zip2($0, $1).map(f) }
}

func zip3<A, B, C, D>(
  with f: @escaping (A, B, C) -> D
  ) -> (A?, B?, C?) -> D? {

  return { zip3($0, $1, $2).map(f) }
}


enum Result<A, E> {
  case success(A)
  case failure(E)
}

func map<A, B, E>(_ f: @escaping (A) -> B) -> (Result<A, E>) -> Result<B, E> {
  return { result in
    switch result {
    case let .success(a):
      return .success(f(a))
    case let .failure(e):
      return .failure(e)
    }
  }
}

func zip2<A, B, E>(_ a: Result<A, E>, _ b: Result<B, E>) -> Result<(A, B), E> {

  switch (a, b) {
  case let (.success(a), .success(b)):
    return .success((a, b))
  case let (.success, .failure(e)):
    return .failure(e)
  case let (.failure(e), .success):
    return .failure(e)
  case let (.failure(e1), .failure(e2)):
//    return .failure(e1)
    return .failure(e2)
  }
}

import NonEmpty

enum Validated<A, E> {
  case valid(A)
  case invalid(NonEmptyArray<E>)
}

func map<A, B, E>(_ f: @escaping (A) -> B) -> (Validated<A, E>) -> Validated<B, E> {
  return { result in
    switch result {
    case let .valid(a):
      return .valid(f(a))
    case let .invalid(e):
      return .invalid(e)
    }
  }
}

func zip2<A, B, E>(_ a: Validated<A, E>, _ b: Validated<B, E>) -> Validated<(A, B), E> {

  switch (a, b) {
  case let (.valid(a), .valid(b)):
    return .valid((a, b))
  case let (.valid, .invalid(e)):
    return .invalid(e)
  case let (.invalid(e), .valid):
    return .invalid(e)
  case let (.invalid(e1), .invalid(e2)):
    return .invalid(e1 + e2)
  }
}

func zip2<A, B, C, E>(
  with f: @escaping (A, B) -> C
  ) -> (Validated<A, E>, Validated<B, E>) -> Validated<C, E> {

  return { zip2($0, $1) |> map(f) }
}

func zip3<A, B, C, E>(_ a: Validated<A, E>, _ b: Validated<B, E>, _ c: Validated<C, E>) -> Validated<(A, B, C), E> {
  return zip2(a, zip2(b, c))
    |> map { a, bc in (a, bc.0, bc.1) }
}

func zip3<A, B, C, D, E>(
  with f: @escaping (A, B, C) -> D
  ) -> (Validated<A, E>, Validated<B, E>, Validated<C, E>) -> Validated<D, E> {

  return { zip3($0, $1, $2) |> map(f) }
}

struct Func<R, A> {
  let apply: (R) -> A
}

func map<A, B, R>(_ f: @escaping (A) -> B) -> (Func<R, A>) -> Func<R, B> {
  return { r2a in
    return Func { r in
      f(r2a.apply(r))
    }
  }
}

func zip2<A, B, R>(_ r2a: Func<R, A>, _ r2b: Func<R, B>) -> Func<R, (A, B)> {
  return Func<R, (A, B)> { r in
    (r2a.apply(r), r2b.apply(r))
  }
}

func zip3<A, B, C, R>(
  _ r2a: Func<R, A>,
  _ r2b: Func<R, B>,
  _ r2c: Func<R, C>
  ) -> Func<R, (A, B, C)> {

  return zip2(r2a, zip2(r2b, r2c)) |> map { ($0, $1.0, $1.1) }
}

func zip2<A, B, C, R>(
  with f: @escaping (A, B) -> C
  ) -> (Func<R, A>, Func<R, B>) -> Func<R, C> {

  return { zip2($0, $1) |> map(f) }
}

func zip3<A, B, C, D, R>(
  with f: @escaping (A, B, C) -> D
  ) -> (Func<R, A>, Func<R, B>, Func<R, C>) -> Func<R, D> {

  return { zip3($0, $1, $2) |> map(f) }
}

struct Parallel<A> {
  let run: (@escaping (A) -> Void) -> Void
}

func map<A, B>(_ f: @escaping (A) -> B) -> (Parallel<A>) -> Parallel<B> {
  return { f3 in
    return Parallel { callback in
      f3.run { callback(f($0)) }
    }
  }
}

func zip2<A, B>(_ fa: Parallel<A>, _ fb: Parallel<B>) -> Parallel<(A, B)> {
  return Parallel<(A, B)> { callback in
    var a: A?
    var b: B?
    fa.run {
      a = $0
      if let b = b { callback(($0, b)) }
    }
    fb.run {
      b = $0
      if let a = a { callback((a, $0)) }
    }
  }
}

func zip2<A, B, C>(
  with f: @escaping (A, B) -> C
  ) -> (Parallel<A>, Parallel<B>) -> Parallel<C> {

  return { zip2($0, $1) |> map(f) }
}

func zip3<A, B, C>(_ fa: Parallel<A>, _ fb: Parallel<B>, _ fc: Parallel<C>) -> Parallel<(A, B, C)> {
  return zip2(fa, zip2(fb, fc)) |> map { ($0, $1.0, $1.1) }
}

func zip3<A, B, C, D>(
  with f: @escaping (A, B, C) -> D
  ) -> (Parallel<A>, Parallel<B>, Parallel<C>) -> Parallel<D> {

  return { zip3($0, $1, $2) |> map(f) }
}


struct User {
  let email: String
  let id: Int
  let name: String
}

let emails = ["blob@pointfree.co", "blob.jr@pointfree.co", "blob.sr@pointfree.co"]
let ids = [1, 2]
let names = ["Blob", "Blob Junior", "Blob Senior"]


let optionalEmail: String? = "blob@pointfree.co"
let optionalId: Int? = 42
let optionalName: String? = "Blob"

func validate(email: String) -> Validated<String, String> {
  return email.index(of: "@") == nil
    ? .invalid(NonEmptyArray("email is invalid"))
    : .valid(email)
}

func validate(id: Int) -> Validated<Int, String> {
  return id <= 0
    ? .invalid(NonEmptyArray("id must be positive"))
    : .valid(id)
}

func validate(name: String) -> Validated<String, String> {
  return name.isEmpty
    ? .invalid(NonEmptyArray("name can't be blank"))
    : .valid(name)
}


let emailProvider = Func<Void, String> { "blob@pointfree.co" }
let idProvider = Func<Void, Int> { 42 }
let nameProvider = Func<Void, String> {
  (try? String(contentsOf: URL(string: "https://www.pointfree.co")!))
    .map { $0.split(separator: " ")[1566] }
    .map(String.init)
    ?? "PointFree"
}


func delay(by duration: TimeInterval, line: UInt = #line, execute: @escaping () -> Void) {
  print("delaying line \(line) by \(duration)")
  DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
    execute()
    print("executed line \(line)")
  }
}

let delayedEmail = Parallel<String> { callback in
  delay(by: 3) { callback("blob@pointfree.co") }
}
let delayedId = Parallel<Int> { callback in
  delay(by: 0.5) { callback(42) }
}
let delayedName = Parallel<String> { callback in
  delay(by: 1) { callback("Blob") }
}

func id<A>(_ a: A) -> A {
  return a
}

extension Optional {
  static func zip<A, B>(with f: @escaping (Wrapped, A) -> B, _ w: Optional, _ a: A?) -> B? {
    guard let w = w, let a = a else { return nil }
    return f(w, a)
  }

  static func zip<A>(_ w: Optional, _ a: A?) -> (Wrapped, A)? {
    return zip(with: id, w, a)
  }

  static func zip<A, B, C>(with f: @escaping (Wrapped, A, B) -> C, _ w: Optional, _ a: A?, _ b: B?) -> C? {
    guard let w = w, let a = a, let b = b else { return nil }
    return f(w, a, b)
  }

  static func zip<A, B>(_ w: Optional, _ a: A?, _ b: B?) -> (Wrapped, A, B)? {
    return zip(with: id, w, a, b)
  }
}

1


zip3(with: User.init)(
  emails,
  ids,
  names
)
Optional.zip(
  with: User.init,
  optionalEmail,
  optionalId,
  optionalName
)
zip3(with: User.init)(
  optionalEmail,
  optionalId,
  optionalName
)
zip3(with: User.init)(
  validate(email: "blobpointfree.co"),
  validate(id: 0),
  validate(name: "")
)
zip3(with: User.init)(
  emailProvider,
  idProvider,
  nameProvider
)
zip3(with: User.init)(
  delayedEmail,
  delayedId,
  delayedName
)







@_fixed_layout // FIXME(sil-serialize-all)
public struct Zip3Sequence<Sequence1 : Sequence, Sequence2 : Sequence, Sequence3 : Sequence> {
//  @usableFromInline // FIXME(sil-serialize-all)
  internal let _sequence1: Sequence1
//  @usableFromInline // FIXME(sil-serialize-all)
  internal let _sequence2: Sequence2
//  @usableFromInline // FIXME(sil-serialize-all)
  internal let _sequence3: Sequence3

  /// Creates an instance that makes pairs of elements from `sequence1` and
  /// `sequence2`.
//  @inlinable // FIXME(sil-serialize-all)
  public // @testable
  init(_sequence1 sequence1: Sequence1, _sequence2 sequence2: Sequence2, _sequence3 sequence3: Sequence3) {
    (_sequence1, _sequence2, _sequence3) = (sequence1, sequence2, sequence3)
  }
}

extension Zip3Sequence {
  /// An iterator for `Zip3Sequence`.
  @_fixed_layout // FIXME(sil-serialize-all)
  public struct Iterator {
//    @usableFromInline // FIXME(sil-serialize-all)
    internal var _baseStream1: Sequence1.Iterator
//    @usableFromInline // FIXME(sil-serialize-all)
    internal var _baseStream2: Sequence2.Iterator
    internal var _baseStream3: Sequence3.Iterator
//    @usableFromInline // FIXME(sil-serialize-all)
    internal var _reachedEnd: Bool = false

    /// Creates an instance around a pair of underlying iterators.
//    @inlinable // FIXME(sil-serialize-all)
    internal init(
      _ iterator1: Sequence1.Iterator,
      _ iterator2: Sequence2.Iterator,
      _ iterator3: Sequence3.Iterator
      ) {
      (_baseStream1, _baseStream2, _baseStream3) = (iterator1, iterator2, iterator3)
    }
  }
}

extension Zip3Sequence.Iterator: IteratorProtocol {
  /// The type of element returned by `next()`.
  public typealias Element = (Sequence1.Element, Sequence2.Element, Sequence3.Element)

  /// Advances to the next element and returns it, or `nil` if no next element
  /// exists.
  ///
  /// Once `nil` has been returned, all subsequent calls return `nil`.
//  @inlinable // FIXME(sil-serialize-all)
  public mutating func next() -> Element? {
    // The next() function needs to track if it has reached the end.  If we
    // didn't, and the first sequence is longer than the second, then when we
    // have already exhausted the second sequence, on every subsequent call to
    // next() we would consume and discard one additional element from the
    // first sequence, even though next() had already returned nil.
    if _reachedEnd {
      return nil
    }

    guard let element1 = _baseStream1.next(),
      let element2 = _baseStream2.next(),
      let element3 = _baseStream3.next() else {
        _reachedEnd = true
        return nil
    }

    return (element1, element2, element3)
  }
}

extension Zip3Sequence: Sequence {
  public typealias Element = (Sequence1.Element, Sequence2.Element, Sequence3.Element)

  /// Returns an iterator over the elements of this sequence.
//  @inlinable // FIXME(sil-serialize-all)
  public func makeIterator() -> Iterator {
    return Iterator(
      _sequence1.makeIterator(),
      _sequence2.makeIterator(),
    _sequence3.makeIterator())
  }
}

//@inlinable // FIXME(sil-serialize-all)
public func zip<Sequence1, Sequence2, Sequence3>(
  _ sequence1: Sequence1, _ sequence2: Sequence2, _ sequence3: Sequence3
  ) -> Zip3Sequence<Sequence1, Sequence2, Sequence3> {
  return Zip3Sequence(_sequence1: sequence1, _sequence2: sequence2, _sequence3: sequence3)
}

Array(zip(1..., 2..., [1, 2, 3]))

Array(zip(1..., 2...).lazy
  .map { $0 }
  .prefix(10)
)


func zip<K, V, W>(_ lhs: [K: V], _ rhs: [K: W]) -> [K: (V, W)] {
  var result: [K: (V, W)] = [:]
  for (key, v) in lhs {
    if let w = rhs[key] {
      result[key] = (v, w)
    }
  }
  return result
}

zip(
  [1: "one", 2: "two"],
  [1: "uno", 2: "dos", 3: "tres"]
)


2










