// build/dev/javascript/prelude.mjs
var CustomType = class {
  withFields(fields) {
    let properties = Object.keys(this).map(
      (label) => label in fields ? fields[label] : this[label]
    );
    return new this.constructor(...properties);
  }
};
var List = class {
  static fromArray(array3, tail) {
    let t = tail || new Empty();
    for (let i = array3.length - 1; i >= 0; --i) {
      t = new NonEmpty(array3[i], t);
    }
    return t;
  }
  [Symbol.iterator]() {
    return new ListIterator(this);
  }
  toArray() {
    return [...this];
  }
  // @internal
  atLeastLength(desired) {
    for (let _ of this) {
      if (desired <= 0)
        return true;
      desired--;
    }
    return desired <= 0;
  }
  // @internal
  hasLength(desired) {
    for (let _ of this) {
      if (desired <= 0)
        return false;
      desired--;
    }
    return desired === 0;
  }
  // @internal
  countLength() {
    let length5 = 0;
    for (let _ of this)
      length5++;
    return length5;
  }
};
function prepend(element3, tail) {
  return new NonEmpty(element3, tail);
}
function toList(elements2, tail) {
  return List.fromArray(elements2, tail);
}
var ListIterator = class {
  #current;
  constructor(current) {
    this.#current = current;
  }
  next() {
    if (this.#current instanceof Empty) {
      return { done: true };
    } else {
      let { head, tail } = this.#current;
      this.#current = tail;
      return { value: head, done: false };
    }
  }
};
var Empty = class extends List {
};
var NonEmpty = class extends List {
  constructor(head, tail) {
    super();
    this.head = head;
    this.tail = tail;
  }
};
var BitArray = class _BitArray {
  constructor(buffer) {
    if (!(buffer instanceof Uint8Array)) {
      throw "BitArray can only be constructed from a Uint8Array";
    }
    this.buffer = buffer;
  }
  // @internal
  get length() {
    return this.buffer.length;
  }
  // @internal
  byteAt(index3) {
    return this.buffer[index3];
  }
  // @internal
  floatFromSlice(start3, end, isBigEndian) {
    return byteArrayToFloat(this.buffer, start3, end, isBigEndian);
  }
  // @internal
  intFromSlice(start3, end, isBigEndian, isSigned) {
    return byteArrayToInt(this.buffer, start3, end, isBigEndian, isSigned);
  }
  // @internal
  binaryFromSlice(start3, end) {
    return new _BitArray(this.buffer.slice(start3, end));
  }
  // @internal
  sliceAfter(index3) {
    return new _BitArray(this.buffer.slice(index3));
  }
};
var UtfCodepoint = class {
  constructor(value2) {
    this.value = value2;
  }
};
function byteArrayToInt(byteArray, start3, end, isBigEndian, isSigned) {
  const byteSize = end - start3;
  if (byteSize <= 6) {
    let value2 = 0;
    if (isBigEndian) {
      for (let i = start3; i < end; i++) {
        value2 = value2 * 256 + byteArray[i];
      }
    } else {
      for (let i = end - 1; i >= start3; i--) {
        value2 = value2 * 256 + byteArray[i];
      }
    }
    if (isSigned) {
      const highBit = 2 ** (byteSize * 8 - 1);
      if (value2 >= highBit) {
        value2 -= highBit * 2;
      }
    }
    return value2;
  } else {
    let value2 = 0n;
    if (isBigEndian) {
      for (let i = start3; i < end; i++) {
        value2 = (value2 << 8n) + BigInt(byteArray[i]);
      }
    } else {
      for (let i = end - 1; i >= start3; i--) {
        value2 = (value2 << 8n) + BigInt(byteArray[i]);
      }
    }
    if (isSigned) {
      const highBit = 1n << BigInt(byteSize * 8 - 1);
      if (value2 >= highBit) {
        value2 -= highBit * 2n;
      }
    }
    return Number(value2);
  }
}
function byteArrayToFloat(byteArray, start3, end, isBigEndian) {
  const view2 = new DataView(byteArray.buffer);
  const byteSize = end - start3;
  if (byteSize === 8) {
    return view2.getFloat64(start3, !isBigEndian);
  } else if (byteSize === 4) {
    return view2.getFloat32(start3, !isBigEndian);
  } else {
    const msg = `Sized floats must be 32-bit or 64-bit on JavaScript, got size of ${byteSize * 8} bits`;
    throw new globalThis.Error(msg);
  }
}
var Result = class _Result extends CustomType {
  // @internal
  static isResult(data) {
    return data instanceof _Result;
  }
};
var Ok = class extends Result {
  constructor(value2) {
    super();
    this[0] = value2;
  }
  // @internal
  isOk() {
    return true;
  }
};
var Error = class extends Result {
  constructor(detail) {
    super();
    this[0] = detail;
  }
  // @internal
  isOk() {
    return false;
  }
};
function isEqual(x, y) {
  let values2 = [x, y];
  while (values2.length) {
    let a = values2.pop();
    let b = values2.pop();
    if (a === b)
      continue;
    if (!isObject(a) || !isObject(b))
      return false;
    let unequal = !structurallyCompatibleObjects(a, b) || unequalDates(a, b) || unequalBuffers(a, b) || unequalArrays(a, b) || unequalMaps(a, b) || unequalSets(a, b) || unequalRegExps(a, b);
    if (unequal)
      return false;
    const proto = Object.getPrototypeOf(a);
    if (proto !== null && typeof proto.equals === "function") {
      try {
        if (a.equals(b))
          continue;
        else
          return false;
      } catch {
      }
    }
    let [keys2, get3] = getters(a);
    for (let k of keys2(a)) {
      values2.push(get3(a, k), get3(b, k));
    }
  }
  return true;
}
function getters(object3) {
  if (object3 instanceof Map) {
    return [(x) => x.keys(), (x, y) => x.get(y)];
  } else {
    let extra = object3 instanceof globalThis.Error ? ["message"] : [];
    return [(x) => [...extra, ...Object.keys(x)], (x, y) => x[y]];
  }
}
function unequalDates(a, b) {
  return a instanceof Date && (a > b || a < b);
}
function unequalBuffers(a, b) {
  return a.buffer instanceof ArrayBuffer && a.BYTES_PER_ELEMENT && !(a.byteLength === b.byteLength && a.every((n, i) => n === b[i]));
}
function unequalArrays(a, b) {
  return Array.isArray(a) && a.length !== b.length;
}
function unequalMaps(a, b) {
  return a instanceof Map && a.size !== b.size;
}
function unequalSets(a, b) {
  return a instanceof Set && (a.size != b.size || [...a].some((e) => !b.has(e)));
}
function unequalRegExps(a, b) {
  return a instanceof RegExp && (a.source !== b.source || a.flags !== b.flags);
}
function isObject(a) {
  return typeof a === "object" && a !== null;
}
function structurallyCompatibleObjects(a, b) {
  if (typeof a !== "object" && typeof b !== "object" && (!a || !b))
    return false;
  let nonstructural = [Promise, WeakSet, WeakMap, Function];
  if (nonstructural.some((c) => a instanceof c))
    return false;
  return a.constructor === b.constructor;
}
function makeError(variant, module, line, fn, message, extra) {
  let error = new globalThis.Error(message);
  error.gleam_error = variant;
  error.module = module;
  error.line = line;
  error.function = fn;
  error.fn = fn;
  for (let k in extra)
    error[k] = extra[k];
  return error;
}

// build/dev/javascript/gleam_stdlib/gleam/option.mjs
var Some = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var None = class extends CustomType {
};
function is_some(option) {
  return !isEqual(option, new None());
}
function is_none(option) {
  return isEqual(option, new None());
}
function to_result(option, e) {
  if (option instanceof Some) {
    let a = option[0];
    return new Ok(a);
  } else {
    return new Error(e);
  }
}
function unwrap(option, default$) {
  if (option instanceof Some) {
    let x = option[0];
    return x;
  } else {
    return default$;
  }
}
function map(option, fun) {
  if (option instanceof Some) {
    let x = option[0];
    return new Some(fun(x));
  } else {
    return new None();
  }
}

// build/dev/javascript/gleam_stdlib/gleam/order.mjs
var Lt = class extends CustomType {
};
var Eq = class extends CustomType {
};
var Gt = class extends CustomType {
};

// build/dev/javascript/gleam_stdlib/gleam/float.mjs
function to_string(x) {
  return float_to_string(x);
}
function compare(a, b) {
  let $ = a === b;
  if ($) {
    return new Eq();
  } else {
    let $1 = a < b;
    if ($1) {
      return new Lt();
    } else {
      return new Gt();
    }
  }
}

// build/dev/javascript/gleam_stdlib/gleam/int.mjs
function absolute_value(x) {
  let $ = x >= 0;
  if ($) {
    return x;
  } else {
    return x * -1;
  }
}
function to_string3(x) {
  return to_string2(x);
}
function to_float(x) {
  return identity(x);
}
function compare2(a, b) {
  let $ = a === b;
  if ($) {
    return new Eq();
  } else {
    let $1 = a < b;
    if ($1) {
      return new Lt();
    } else {
      return new Gt();
    }
  }
}
function add(a, b) {
  return a + b;
}
function subtract(a, b) {
  return a - b;
}

// build/dev/javascript/gleam_stdlib/gleam/pair.mjs
function first(pair) {
  let a = pair[0];
  return a;
}
function second(pair) {
  let a = pair[1];
  return a;
}
function map_first(pair, fun) {
  let a = pair[0];
  let b = pair[1];
  return [fun(a), b];
}
function map_second(pair, fun) {
  let a = pair[0];
  let b = pair[1];
  return [a, fun(b)];
}
function new$(first4, second2) {
  return [first4, second2];
}

// build/dev/javascript/gleam_stdlib/gleam/list.mjs
var Ascending = class extends CustomType {
};
var Descending = class extends CustomType {
};
function length_loop(loop$list, loop$count) {
  while (true) {
    let list = loop$list;
    let count = loop$count;
    if (list.atLeastLength(1)) {
      let list$1 = list.tail;
      loop$list = list$1;
      loop$count = count + 1;
    } else {
      return count;
    }
  }
}
function length(list) {
  return length_loop(list, 0);
}
function reverse_loop(loop$remaining, loop$accumulator) {
  while (true) {
    let remaining = loop$remaining;
    let accumulator = loop$accumulator;
    if (remaining.hasLength(0)) {
      return accumulator;
    } else {
      let item = remaining.head;
      let rest$1 = remaining.tail;
      loop$remaining = rest$1;
      loop$accumulator = prepend(item, accumulator);
    }
  }
}
function reverse(list) {
  return reverse_loop(list, toList([]));
}
function is_empty(list) {
  return isEqual(list, toList([]));
}
function first2(list) {
  if (list.hasLength(0)) {
    return new Error(void 0);
  } else {
    let x = list.head;
    return new Ok(x);
  }
}
function map_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list.hasLength(0)) {
      return reverse(acc);
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = prepend(fun(first$1), acc);
    }
  }
}
function map2(list, fun) {
  return map_loop(list, fun, toList([]));
}
function index_map_loop(loop$list, loop$fun, loop$index, loop$acc) {
  while (true) {
    let list = loop$list;
    let fun = loop$fun;
    let index3 = loop$index;
    let acc = loop$acc;
    if (list.hasLength(0)) {
      return reverse(acc);
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let acc$1 = prepend(fun(first$1, index3), acc);
      loop$list = rest$1;
      loop$fun = fun;
      loop$index = index3 + 1;
      loop$acc = acc$1;
    }
  }
}
function index_map(list, fun) {
  return index_map_loop(list, fun, 0, toList([]));
}
function drop(loop$list, loop$n) {
  while (true) {
    let list = loop$list;
    let n = loop$n;
    let $ = n <= 0;
    if ($) {
      return list;
    } else {
      if (list.hasLength(0)) {
        return toList([]);
      } else {
        let rest$1 = list.tail;
        loop$list = rest$1;
        loop$n = n - 1;
      }
    }
  }
}
function take_loop(loop$list, loop$n, loop$acc) {
  while (true) {
    let list = loop$list;
    let n = loop$n;
    let acc = loop$acc;
    let $ = n <= 0;
    if ($) {
      return reverse(acc);
    } else {
      if (list.hasLength(0)) {
        return reverse(acc);
      } else {
        let first$1 = list.head;
        let rest$1 = list.tail;
        loop$list = rest$1;
        loop$n = n - 1;
        loop$acc = prepend(first$1, acc);
      }
    }
  }
}
function take(list, n) {
  return take_loop(list, n, toList([]));
}
function append_loop(loop$first, loop$second) {
  while (true) {
    let first4 = loop$first;
    let second2 = loop$second;
    if (first4.hasLength(0)) {
      return second2;
    } else {
      let item = first4.head;
      let rest$1 = first4.tail;
      loop$first = rest$1;
      loop$second = prepend(item, second2);
    }
  }
}
function append(first4, second2) {
  return append_loop(reverse(first4), second2);
}
function prepend2(list, item) {
  return prepend(item, list);
}
function reverse_and_prepend(loop$prefix, loop$suffix) {
  while (true) {
    let prefix = loop$prefix;
    let suffix = loop$suffix;
    if (prefix.hasLength(0)) {
      return suffix;
    } else {
      let first$1 = prefix.head;
      let rest$1 = prefix.tail;
      loop$prefix = rest$1;
      loop$suffix = prepend(first$1, suffix);
    }
  }
}
function concat_loop(loop$lists, loop$acc) {
  while (true) {
    let lists = loop$lists;
    let acc = loop$acc;
    if (lists.hasLength(0)) {
      return reverse(acc);
    } else {
      let list = lists.head;
      let further_lists = lists.tail;
      loop$lists = further_lists;
      loop$acc = reverse_and_prepend(list, acc);
    }
  }
}
function concat(lists) {
  return concat_loop(lists, toList([]));
}
function flatten(lists) {
  return concat_loop(lists, toList([]));
}
function flat_map(list, fun) {
  let _pipe = map2(list, fun);
  return flatten(_pipe);
}
function fold(loop$list, loop$initial, loop$fun) {
  while (true) {
    let list = loop$list;
    let initial = loop$initial;
    let fun = loop$fun;
    if (list.hasLength(0)) {
      return initial;
    } else {
      let x = list.head;
      let rest$1 = list.tail;
      loop$list = rest$1;
      loop$initial = fun(initial, x);
      loop$fun = fun;
    }
  }
}
function index_fold_loop(loop$over, loop$acc, loop$with, loop$index) {
  while (true) {
    let over = loop$over;
    let acc = loop$acc;
    let with$ = loop$with;
    let index3 = loop$index;
    if (over.hasLength(0)) {
      return acc;
    } else {
      let first$1 = over.head;
      let rest$1 = over.tail;
      loop$over = rest$1;
      loop$acc = with$(acc, first$1, index3);
      loop$with = with$;
      loop$index = index3 + 1;
    }
  }
}
function index_fold(list, initial, fun) {
  return index_fold_loop(list, initial, fun, 0);
}
function find_map(loop$list, loop$fun) {
  while (true) {
    let list = loop$list;
    let fun = loop$fun;
    if (list.hasLength(0)) {
      return new Error(void 0);
    } else {
      let x = list.head;
      let rest$1 = list.tail;
      let $ = fun(x);
      if ($.isOk()) {
        let x$1 = $[0];
        return new Ok(x$1);
      } else {
        loop$list = rest$1;
        loop$fun = fun;
      }
    }
  }
}
function sequences(loop$list, loop$compare, loop$growing, loop$direction, loop$prev, loop$acc) {
  while (true) {
    let list = loop$list;
    let compare3 = loop$compare;
    let growing = loop$growing;
    let direction = loop$direction;
    let prev = loop$prev;
    let acc = loop$acc;
    let growing$1 = prepend(prev, growing);
    if (list.hasLength(0)) {
      if (direction instanceof Ascending) {
        return prepend(reverse_loop(growing$1, toList([])), acc);
      } else {
        return prepend(growing$1, acc);
      }
    } else {
      let new$1 = list.head;
      let rest$1 = list.tail;
      let $ = compare3(prev, new$1);
      if ($ instanceof Gt && direction instanceof Descending) {
        loop$list = rest$1;
        loop$compare = compare3;
        loop$growing = growing$1;
        loop$direction = direction;
        loop$prev = new$1;
        loop$acc = acc;
      } else if ($ instanceof Lt && direction instanceof Ascending) {
        loop$list = rest$1;
        loop$compare = compare3;
        loop$growing = growing$1;
        loop$direction = direction;
        loop$prev = new$1;
        loop$acc = acc;
      } else if ($ instanceof Eq && direction instanceof Ascending) {
        loop$list = rest$1;
        loop$compare = compare3;
        loop$growing = growing$1;
        loop$direction = direction;
        loop$prev = new$1;
        loop$acc = acc;
      } else if ($ instanceof Gt && direction instanceof Ascending) {
        let acc$1 = (() => {
          if (direction instanceof Ascending) {
            return prepend(reverse_loop(growing$1, toList([])), acc);
          } else {
            return prepend(growing$1, acc);
          }
        })();
        if (rest$1.hasLength(0)) {
          return prepend(toList([new$1]), acc$1);
        } else {
          let next = rest$1.head;
          let rest$2 = rest$1.tail;
          let direction$1 = (() => {
            let $1 = compare3(new$1, next);
            if ($1 instanceof Lt) {
              return new Ascending();
            } else if ($1 instanceof Eq) {
              return new Ascending();
            } else {
              return new Descending();
            }
          })();
          loop$list = rest$2;
          loop$compare = compare3;
          loop$growing = toList([new$1]);
          loop$direction = direction$1;
          loop$prev = next;
          loop$acc = acc$1;
        }
      } else if ($ instanceof Lt && direction instanceof Descending) {
        let acc$1 = (() => {
          if (direction instanceof Ascending) {
            return prepend(reverse_loop(growing$1, toList([])), acc);
          } else {
            return prepend(growing$1, acc);
          }
        })();
        if (rest$1.hasLength(0)) {
          return prepend(toList([new$1]), acc$1);
        } else {
          let next = rest$1.head;
          let rest$2 = rest$1.tail;
          let direction$1 = (() => {
            let $1 = compare3(new$1, next);
            if ($1 instanceof Lt) {
              return new Ascending();
            } else if ($1 instanceof Eq) {
              return new Ascending();
            } else {
              return new Descending();
            }
          })();
          loop$list = rest$2;
          loop$compare = compare3;
          loop$growing = toList([new$1]);
          loop$direction = direction$1;
          loop$prev = next;
          loop$acc = acc$1;
        }
      } else {
        let acc$1 = (() => {
          if (direction instanceof Ascending) {
            return prepend(reverse_loop(growing$1, toList([])), acc);
          } else {
            return prepend(growing$1, acc);
          }
        })();
        if (rest$1.hasLength(0)) {
          return prepend(toList([new$1]), acc$1);
        } else {
          let next = rest$1.head;
          let rest$2 = rest$1.tail;
          let direction$1 = (() => {
            let $1 = compare3(new$1, next);
            if ($1 instanceof Lt) {
              return new Ascending();
            } else if ($1 instanceof Eq) {
              return new Ascending();
            } else {
              return new Descending();
            }
          })();
          loop$list = rest$2;
          loop$compare = compare3;
          loop$growing = toList([new$1]);
          loop$direction = direction$1;
          loop$prev = next;
          loop$acc = acc$1;
        }
      }
    }
  }
}
function merge_ascendings(loop$list1, loop$list2, loop$compare, loop$acc) {
  while (true) {
    let list1 = loop$list1;
    let list2 = loop$list2;
    let compare3 = loop$compare;
    let acc = loop$acc;
    if (list1.hasLength(0)) {
      let list = list2;
      return reverse_loop(list, acc);
    } else if (list2.hasLength(0)) {
      let list = list1;
      return reverse_loop(list, acc);
    } else {
      let first1 = list1.head;
      let rest1 = list1.tail;
      let first22 = list2.head;
      let rest2 = list2.tail;
      let $ = compare3(first1, first22);
      if ($ instanceof Lt) {
        loop$list1 = rest1;
        loop$list2 = list2;
        loop$compare = compare3;
        loop$acc = prepend(first1, acc);
      } else if ($ instanceof Gt) {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare3;
        loop$acc = prepend(first22, acc);
      } else {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare3;
        loop$acc = prepend(first22, acc);
      }
    }
  }
}
function merge_ascending_pairs(loop$sequences, loop$compare, loop$acc) {
  while (true) {
    let sequences2 = loop$sequences;
    let compare3 = loop$compare;
    let acc = loop$acc;
    if (sequences2.hasLength(0)) {
      return reverse_loop(acc, toList([]));
    } else if (sequences2.hasLength(1)) {
      let sequence = sequences2.head;
      return reverse_loop(
        prepend(reverse_loop(sequence, toList([])), acc),
        toList([])
      );
    } else {
      let ascending1 = sequences2.head;
      let ascending2 = sequences2.tail.head;
      let rest$1 = sequences2.tail.tail;
      let descending = merge_ascendings(
        ascending1,
        ascending2,
        compare3,
        toList([])
      );
      loop$sequences = rest$1;
      loop$compare = compare3;
      loop$acc = prepend(descending, acc);
    }
  }
}
function merge_descendings(loop$list1, loop$list2, loop$compare, loop$acc) {
  while (true) {
    let list1 = loop$list1;
    let list2 = loop$list2;
    let compare3 = loop$compare;
    let acc = loop$acc;
    if (list1.hasLength(0)) {
      let list = list2;
      return reverse_loop(list, acc);
    } else if (list2.hasLength(0)) {
      let list = list1;
      return reverse_loop(list, acc);
    } else {
      let first1 = list1.head;
      let rest1 = list1.tail;
      let first22 = list2.head;
      let rest2 = list2.tail;
      let $ = compare3(first1, first22);
      if ($ instanceof Lt) {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare3;
        loop$acc = prepend(first22, acc);
      } else if ($ instanceof Gt) {
        loop$list1 = rest1;
        loop$list2 = list2;
        loop$compare = compare3;
        loop$acc = prepend(first1, acc);
      } else {
        loop$list1 = rest1;
        loop$list2 = list2;
        loop$compare = compare3;
        loop$acc = prepend(first1, acc);
      }
    }
  }
}
function merge_descending_pairs(loop$sequences, loop$compare, loop$acc) {
  while (true) {
    let sequences2 = loop$sequences;
    let compare3 = loop$compare;
    let acc = loop$acc;
    if (sequences2.hasLength(0)) {
      return reverse_loop(acc, toList([]));
    } else if (sequences2.hasLength(1)) {
      let sequence = sequences2.head;
      return reverse_loop(
        prepend(reverse_loop(sequence, toList([])), acc),
        toList([])
      );
    } else {
      let descending1 = sequences2.head;
      let descending2 = sequences2.tail.head;
      let rest$1 = sequences2.tail.tail;
      let ascending = merge_descendings(
        descending1,
        descending2,
        compare3,
        toList([])
      );
      loop$sequences = rest$1;
      loop$compare = compare3;
      loop$acc = prepend(ascending, acc);
    }
  }
}
function merge_all(loop$sequences, loop$direction, loop$compare) {
  while (true) {
    let sequences2 = loop$sequences;
    let direction = loop$direction;
    let compare3 = loop$compare;
    if (sequences2.hasLength(0)) {
      return toList([]);
    } else if (sequences2.hasLength(1) && direction instanceof Ascending) {
      let sequence = sequences2.head;
      return sequence;
    } else if (sequences2.hasLength(1) && direction instanceof Descending) {
      let sequence = sequences2.head;
      return reverse_loop(sequence, toList([]));
    } else if (direction instanceof Ascending) {
      let sequences$1 = merge_ascending_pairs(sequences2, compare3, toList([]));
      loop$sequences = sequences$1;
      loop$direction = new Descending();
      loop$compare = compare3;
    } else {
      let sequences$1 = merge_descending_pairs(sequences2, compare3, toList([]));
      loop$sequences = sequences$1;
      loop$direction = new Ascending();
      loop$compare = compare3;
    }
  }
}
function sort(list, compare3) {
  if (list.hasLength(0)) {
    return toList([]);
  } else if (list.hasLength(1)) {
    let x = list.head;
    return toList([x]);
  } else {
    let x = list.head;
    let y = list.tail.head;
    let rest$1 = list.tail.tail;
    let direction = (() => {
      let $ = compare3(x, y);
      if ($ instanceof Lt) {
        return new Ascending();
      } else if ($ instanceof Eq) {
        return new Ascending();
      } else {
        return new Descending();
      }
    })();
    let sequences$1 = sequences(
      rest$1,
      compare3,
      toList([x]),
      direction,
      y,
      toList([])
    );
    return merge_all(sequences$1, new Ascending(), compare3);
  }
}
function range_loop(loop$start, loop$stop, loop$acc) {
  while (true) {
    let start3 = loop$start;
    let stop = loop$stop;
    let acc = loop$acc;
    let $ = compare2(start3, stop);
    if ($ instanceof Eq) {
      return prepend(stop, acc);
    } else if ($ instanceof Gt) {
      loop$start = start3;
      loop$stop = stop + 1;
      loop$acc = prepend(stop, acc);
    } else {
      loop$start = start3;
      loop$stop = stop - 1;
      loop$acc = prepend(stop, acc);
    }
  }
}
function range(start3, stop) {
  return range_loop(start3, stop, toList([]));
}
function sized_chunk_loop(loop$list, loop$count, loop$left, loop$current_chunk, loop$acc) {
  while (true) {
    let list = loop$list;
    let count = loop$count;
    let left = loop$left;
    let current_chunk = loop$current_chunk;
    let acc = loop$acc;
    if (list.hasLength(0)) {
      if (current_chunk.hasLength(0)) {
        return reverse(acc);
      } else {
        let remaining = current_chunk;
        return reverse(prepend(reverse(remaining), acc));
      }
    } else {
      let first$1 = list.head;
      let rest$1 = list.tail;
      let chunk$1 = prepend(first$1, current_chunk);
      let $ = left > 1;
      if ($) {
        loop$list = rest$1;
        loop$count = count;
        loop$left = left - 1;
        loop$current_chunk = chunk$1;
        loop$acc = acc;
      } else {
        loop$list = rest$1;
        loop$count = count;
        loop$left = count;
        loop$current_chunk = toList([]);
        loop$acc = prepend(reverse(chunk$1), acc);
      }
    }
  }
}
function sized_chunk(list, count) {
  return sized_chunk_loop(list, count, count, toList([]), toList([]));
}
function shuffle_pair_unwrap_loop(loop$list, loop$acc) {
  while (true) {
    let list = loop$list;
    let acc = loop$acc;
    if (list.hasLength(0)) {
      return acc;
    } else {
      let elem_pair = list.head;
      let enumerable = list.tail;
      loop$list = enumerable;
      loop$acc = prepend(elem_pair[1], acc);
    }
  }
}
function do_shuffle_by_pair_indexes(list_of_pairs) {
  return sort(
    list_of_pairs,
    (a_pair, b_pair) => {
      return compare(a_pair[0], b_pair[0]);
    }
  );
}
function shuffle(list) {
  let _pipe = list;
  let _pipe$1 = fold(
    _pipe,
    toList([]),
    (acc, a) => {
      return prepend([random_uniform(), a], acc);
    }
  );
  let _pipe$2 = do_shuffle_by_pair_indexes(_pipe$1);
  return shuffle_pair_unwrap_loop(_pipe$2, toList([]));
}

// build/dev/javascript/gleam_stdlib/gleam/string_tree.mjs
function append_tree(tree, suffix) {
  return add2(tree, suffix);
}
function from_string(string3) {
  return identity(string3);
}
function append2(tree, second2) {
  return append_tree(tree, from_string(second2));
}
function to_string4(tree) {
  return identity(tree);
}

// build/dev/javascript/gleam_stdlib/gleam/string.mjs
function length3(string3) {
  return string_length(string3);
}
function slice(string3, idx, len) {
  let $ = len < 0;
  if ($) {
    return "";
  } else {
    let $1 = idx < 0;
    if ($1) {
      let translated_idx = length3(string3) + idx;
      let $2 = translated_idx < 0;
      if ($2) {
        return "";
      } else {
        return string_slice(string3, translated_idx, len);
      }
    } else {
      return string_slice(string3, idx, len);
    }
  }
}
function drop_start(string3, num_graphemes) {
  let $ = num_graphemes < 0;
  if ($) {
    return string3;
  } else {
    return slice(string3, num_graphemes, length3(string3) - num_graphemes);
  }
}
function append3(first4, second2) {
  let _pipe = first4;
  let _pipe$1 = from_string(_pipe);
  let _pipe$2 = append2(_pipe$1, second2);
  return to_string4(_pipe$2);
}
function repeat_loop(loop$string, loop$times, loop$acc) {
  while (true) {
    let string3 = loop$string;
    let times = loop$times;
    let acc = loop$acc;
    let $ = times <= 0;
    if ($) {
      return acc;
    } else {
      loop$string = string3;
      loop$times = times - 1;
      loop$acc = acc + string3;
    }
  }
}
function repeat(string3, times) {
  return repeat_loop(string3, times, "");
}
function join2(strings, separator) {
  return join(strings, separator);
}
function inspect2(term) {
  let _pipe = inspect(term);
  return to_string4(_pipe);
}

// build/dev/javascript/gleam_stdlib/gleam/result.mjs
function map3(result, fun) {
  if (result.isOk()) {
    let x = result[0];
    return new Ok(fun(x));
  } else {
    let e = result[0];
    return new Error(e);
  }
}
function try$(result, fun) {
  if (result.isOk()) {
    let x = result[0];
    return fun(x);
  } else {
    let e = result[0];
    return new Error(e);
  }
}

// build/dev/javascript/gleam_stdlib/dict.mjs
var referenceMap = /* @__PURE__ */ new WeakMap();
var tempDataView = new DataView(new ArrayBuffer(8));
var referenceUID = 0;
function hashByReference(o) {
  const known = referenceMap.get(o);
  if (known !== void 0) {
    return known;
  }
  const hash = referenceUID++;
  if (referenceUID === 2147483647) {
    referenceUID = 0;
  }
  referenceMap.set(o, hash);
  return hash;
}
function hashMerge(a, b) {
  return a ^ b + 2654435769 + (a << 6) + (a >> 2) | 0;
}
function hashString(s) {
  let hash = 0;
  const len = s.length;
  for (let i = 0; i < len; i++) {
    hash = Math.imul(31, hash) + s.charCodeAt(i) | 0;
  }
  return hash;
}
function hashNumber(n) {
  tempDataView.setFloat64(0, n);
  const i = tempDataView.getInt32(0);
  const j = tempDataView.getInt32(4);
  return Math.imul(73244475, i >> 16 ^ i) ^ j;
}
function hashBigInt(n) {
  return hashString(n.toString());
}
function hashObject(o) {
  const proto = Object.getPrototypeOf(o);
  if (proto !== null && typeof proto.hashCode === "function") {
    try {
      const code2 = o.hashCode(o);
      if (typeof code2 === "number") {
        return code2;
      }
    } catch {
    }
  }
  if (o instanceof Promise || o instanceof WeakSet || o instanceof WeakMap) {
    return hashByReference(o);
  }
  if (o instanceof Date) {
    return hashNumber(o.getTime());
  }
  let h = 0;
  if (o instanceof ArrayBuffer) {
    o = new Uint8Array(o);
  }
  if (Array.isArray(o) || o instanceof Uint8Array) {
    for (let i = 0; i < o.length; i++) {
      h = Math.imul(31, h) + getHash(o[i]) | 0;
    }
  } else if (o instanceof Set) {
    o.forEach((v) => {
      h = h + getHash(v) | 0;
    });
  } else if (o instanceof Map) {
    o.forEach((v, k) => {
      h = h + hashMerge(getHash(v), getHash(k)) | 0;
    });
  } else {
    const keys2 = Object.keys(o);
    for (let i = 0; i < keys2.length; i++) {
      const k = keys2[i];
      const v = o[k];
      h = h + hashMerge(getHash(v), hashString(k)) | 0;
    }
  }
  return h;
}
function getHash(u) {
  if (u === null)
    return 1108378658;
  if (u === void 0)
    return 1108378659;
  if (u === true)
    return 1108378657;
  if (u === false)
    return 1108378656;
  switch (typeof u) {
    case "number":
      return hashNumber(u);
    case "string":
      return hashString(u);
    case "bigint":
      return hashBigInt(u);
    case "object":
      return hashObject(u);
    case "symbol":
      return hashByReference(u);
    case "function":
      return hashByReference(u);
    default:
      return 0;
  }
}
var SHIFT = 5;
var BUCKET_SIZE = Math.pow(2, SHIFT);
var MASK = BUCKET_SIZE - 1;
var MAX_INDEX_NODE = BUCKET_SIZE / 2;
var MIN_ARRAY_NODE = BUCKET_SIZE / 4;
var ENTRY = 0;
var ARRAY_NODE = 1;
var INDEX_NODE = 2;
var COLLISION_NODE = 3;
var EMPTY = {
  type: INDEX_NODE,
  bitmap: 0,
  array: []
};
function mask(hash, shift) {
  return hash >>> shift & MASK;
}
function bitpos(hash, shift) {
  return 1 << mask(hash, shift);
}
function bitcount(x) {
  x -= x >> 1 & 1431655765;
  x = (x & 858993459) + (x >> 2 & 858993459);
  x = x + (x >> 4) & 252645135;
  x += x >> 8;
  x += x >> 16;
  return x & 127;
}
function index(bitmap, bit) {
  return bitcount(bitmap & bit - 1);
}
function cloneAndSet(arr, at, val) {
  const len = arr.length;
  const out = new Array(len);
  for (let i = 0; i < len; ++i) {
    out[i] = arr[i];
  }
  out[at] = val;
  return out;
}
function spliceIn(arr, at, val) {
  const len = arr.length;
  const out = new Array(len + 1);
  let i = 0;
  let g = 0;
  while (i < at) {
    out[g++] = arr[i++];
  }
  out[g++] = val;
  while (i < len) {
    out[g++] = arr[i++];
  }
  return out;
}
function spliceOut(arr, at) {
  const len = arr.length;
  const out = new Array(len - 1);
  let i = 0;
  let g = 0;
  while (i < at) {
    out[g++] = arr[i++];
  }
  ++i;
  while (i < len) {
    out[g++] = arr[i++];
  }
  return out;
}
function createNode(shift, key1, val1, key2hash, key2, val2) {
  const key1hash = getHash(key1);
  if (key1hash === key2hash) {
    return {
      type: COLLISION_NODE,
      hash: key1hash,
      array: [
        { type: ENTRY, k: key1, v: val1 },
        { type: ENTRY, k: key2, v: val2 }
      ]
    };
  }
  const addedLeaf = { val: false };
  return assoc(
    assocIndex(EMPTY, shift, key1hash, key1, val1, addedLeaf),
    shift,
    key2hash,
    key2,
    val2,
    addedLeaf
  );
}
function assoc(root, shift, hash, key2, val, addedLeaf) {
  switch (root.type) {
    case ARRAY_NODE:
      return assocArray(root, shift, hash, key2, val, addedLeaf);
    case INDEX_NODE:
      return assocIndex(root, shift, hash, key2, val, addedLeaf);
    case COLLISION_NODE:
      return assocCollision(root, shift, hash, key2, val, addedLeaf);
  }
}
function assocArray(root, shift, hash, key2, val, addedLeaf) {
  const idx = mask(hash, shift);
  const node2 = root.array[idx];
  if (node2 === void 0) {
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root.size + 1,
      array: cloneAndSet(root.array, idx, { type: ENTRY, k: key2, v: val })
    };
  }
  if (node2.type === ENTRY) {
    if (isEqual(key2, node2.k)) {
      if (val === node2.v) {
        return root;
      }
      return {
        type: ARRAY_NODE,
        size: root.size,
        array: cloneAndSet(root.array, idx, {
          type: ENTRY,
          k: key2,
          v: val
        })
      };
    }
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root.size,
      array: cloneAndSet(
        root.array,
        idx,
        createNode(shift + SHIFT, node2.k, node2.v, hash, key2, val)
      )
    };
  }
  const n = assoc(node2, shift + SHIFT, hash, key2, val, addedLeaf);
  if (n === node2) {
    return root;
  }
  return {
    type: ARRAY_NODE,
    size: root.size,
    array: cloneAndSet(root.array, idx, n)
  };
}
function assocIndex(root, shift, hash, key2, val, addedLeaf) {
  const bit = bitpos(hash, shift);
  const idx = index(root.bitmap, bit);
  if ((root.bitmap & bit) !== 0) {
    const node2 = root.array[idx];
    if (node2.type !== ENTRY) {
      const n = assoc(node2, shift + SHIFT, hash, key2, val, addedLeaf);
      if (n === node2) {
        return root;
      }
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap,
        array: cloneAndSet(root.array, idx, n)
      };
    }
    const nodeKey = node2.k;
    if (isEqual(key2, nodeKey)) {
      if (val === node2.v) {
        return root;
      }
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap,
        array: cloneAndSet(root.array, idx, {
          type: ENTRY,
          k: key2,
          v: val
        })
      };
    }
    addedLeaf.val = true;
    return {
      type: INDEX_NODE,
      bitmap: root.bitmap,
      array: cloneAndSet(
        root.array,
        idx,
        createNode(shift + SHIFT, nodeKey, node2.v, hash, key2, val)
      )
    };
  } else {
    const n = root.array.length;
    if (n >= MAX_INDEX_NODE) {
      const nodes = new Array(32);
      const jdx = mask(hash, shift);
      nodes[jdx] = assocIndex(EMPTY, shift + SHIFT, hash, key2, val, addedLeaf);
      let j = 0;
      let bitmap = root.bitmap;
      for (let i = 0; i < 32; i++) {
        if ((bitmap & 1) !== 0) {
          const node2 = root.array[j++];
          nodes[i] = node2;
        }
        bitmap = bitmap >>> 1;
      }
      return {
        type: ARRAY_NODE,
        size: n + 1,
        array: nodes
      };
    } else {
      const newArray = spliceIn(root.array, idx, {
        type: ENTRY,
        k: key2,
        v: val
      });
      addedLeaf.val = true;
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap | bit,
        array: newArray
      };
    }
  }
}
function assocCollision(root, shift, hash, key2, val, addedLeaf) {
  if (hash === root.hash) {
    const idx = collisionIndexOf(root, key2);
    if (idx !== -1) {
      const entry = root.array[idx];
      if (entry.v === val) {
        return root;
      }
      return {
        type: COLLISION_NODE,
        hash,
        array: cloneAndSet(root.array, idx, { type: ENTRY, k: key2, v: val })
      };
    }
    const size = root.array.length;
    addedLeaf.val = true;
    return {
      type: COLLISION_NODE,
      hash,
      array: cloneAndSet(root.array, size, { type: ENTRY, k: key2, v: val })
    };
  }
  return assoc(
    {
      type: INDEX_NODE,
      bitmap: bitpos(root.hash, shift),
      array: [root]
    },
    shift,
    hash,
    key2,
    val,
    addedLeaf
  );
}
function collisionIndexOf(root, key2) {
  const size = root.array.length;
  for (let i = 0; i < size; i++) {
    if (isEqual(key2, root.array[i].k)) {
      return i;
    }
  }
  return -1;
}
function find(root, shift, hash, key2) {
  switch (root.type) {
    case ARRAY_NODE:
      return findArray(root, shift, hash, key2);
    case INDEX_NODE:
      return findIndex(root, shift, hash, key2);
    case COLLISION_NODE:
      return findCollision(root, key2);
  }
}
function findArray(root, shift, hash, key2) {
  const idx = mask(hash, shift);
  const node2 = root.array[idx];
  if (node2 === void 0) {
    return void 0;
  }
  if (node2.type !== ENTRY) {
    return find(node2, shift + SHIFT, hash, key2);
  }
  if (isEqual(key2, node2.k)) {
    return node2;
  }
  return void 0;
}
function findIndex(root, shift, hash, key2) {
  const bit = bitpos(hash, shift);
  if ((root.bitmap & bit) === 0) {
    return void 0;
  }
  const idx = index(root.bitmap, bit);
  const node2 = root.array[idx];
  if (node2.type !== ENTRY) {
    return find(node2, shift + SHIFT, hash, key2);
  }
  if (isEqual(key2, node2.k)) {
    return node2;
  }
  return void 0;
}
function findCollision(root, key2) {
  const idx = collisionIndexOf(root, key2);
  if (idx < 0) {
    return void 0;
  }
  return root.array[idx];
}
function without(root, shift, hash, key2) {
  switch (root.type) {
    case ARRAY_NODE:
      return withoutArray(root, shift, hash, key2);
    case INDEX_NODE:
      return withoutIndex(root, shift, hash, key2);
    case COLLISION_NODE:
      return withoutCollision(root, key2);
  }
}
function withoutArray(root, shift, hash, key2) {
  const idx = mask(hash, shift);
  const node2 = root.array[idx];
  if (node2 === void 0) {
    return root;
  }
  let n = void 0;
  if (node2.type === ENTRY) {
    if (!isEqual(node2.k, key2)) {
      return root;
    }
  } else {
    n = without(node2, shift + SHIFT, hash, key2);
    if (n === node2) {
      return root;
    }
  }
  if (n === void 0) {
    if (root.size <= MIN_ARRAY_NODE) {
      const arr = root.array;
      const out = new Array(root.size - 1);
      let i = 0;
      let j = 0;
      let bitmap = 0;
      while (i < idx) {
        const nv = arr[i];
        if (nv !== void 0) {
          out[j] = nv;
          bitmap |= 1 << i;
          ++j;
        }
        ++i;
      }
      ++i;
      while (i < arr.length) {
        const nv = arr[i];
        if (nv !== void 0) {
          out[j] = nv;
          bitmap |= 1 << i;
          ++j;
        }
        ++i;
      }
      return {
        type: INDEX_NODE,
        bitmap,
        array: out
      };
    }
    return {
      type: ARRAY_NODE,
      size: root.size - 1,
      array: cloneAndSet(root.array, idx, n)
    };
  }
  return {
    type: ARRAY_NODE,
    size: root.size,
    array: cloneAndSet(root.array, idx, n)
  };
}
function withoutIndex(root, shift, hash, key2) {
  const bit = bitpos(hash, shift);
  if ((root.bitmap & bit) === 0) {
    return root;
  }
  const idx = index(root.bitmap, bit);
  const node2 = root.array[idx];
  if (node2.type !== ENTRY) {
    const n = without(node2, shift + SHIFT, hash, key2);
    if (n === node2) {
      return root;
    }
    if (n !== void 0) {
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap,
        array: cloneAndSet(root.array, idx, n)
      };
    }
    if (root.bitmap === bit) {
      return void 0;
    }
    return {
      type: INDEX_NODE,
      bitmap: root.bitmap ^ bit,
      array: spliceOut(root.array, idx)
    };
  }
  if (isEqual(key2, node2.k)) {
    if (root.bitmap === bit) {
      return void 0;
    }
    return {
      type: INDEX_NODE,
      bitmap: root.bitmap ^ bit,
      array: spliceOut(root.array, idx)
    };
  }
  return root;
}
function withoutCollision(root, key2) {
  const idx = collisionIndexOf(root, key2);
  if (idx < 0) {
    return root;
  }
  if (root.array.length === 1) {
    return void 0;
  }
  return {
    type: COLLISION_NODE,
    hash: root.hash,
    array: spliceOut(root.array, idx)
  };
}
function forEach(root, fn) {
  if (root === void 0) {
    return;
  }
  const items = root.array;
  const size = items.length;
  for (let i = 0; i < size; i++) {
    const item = items[i];
    if (item === void 0) {
      continue;
    }
    if (item.type === ENTRY) {
      fn(item.v, item.k);
      continue;
    }
    forEach(item, fn);
  }
}
var Dict = class _Dict {
  /**
   * @template V
   * @param {Record<string,V>} o
   * @returns {Dict<string,V>}
   */
  static fromObject(o) {
    const keys2 = Object.keys(o);
    let m = _Dict.new();
    for (let i = 0; i < keys2.length; i++) {
      const k = keys2[i];
      m = m.set(k, o[k]);
    }
    return m;
  }
  /**
   * @template K,V
   * @param {Map<K,V>} o
   * @returns {Dict<K,V>}
   */
  static fromMap(o) {
    let m = _Dict.new();
    o.forEach((v, k) => {
      m = m.set(k, v);
    });
    return m;
  }
  static new() {
    return new _Dict(void 0, 0);
  }
  /**
   * @param {undefined | Node<K,V>} root
   * @param {number} size
   */
  constructor(root, size) {
    this.root = root;
    this.size = size;
  }
  /**
   * @template NotFound
   * @param {K} key
   * @param {NotFound} notFound
   * @returns {NotFound | V}
   */
  get(key2, notFound) {
    if (this.root === void 0) {
      return notFound;
    }
    const found = find(this.root, 0, getHash(key2), key2);
    if (found === void 0) {
      return notFound;
    }
    return found.v;
  }
  /**
   * @param {K} key
   * @param {V} val
   * @returns {Dict<K,V>}
   */
  set(key2, val) {
    const addedLeaf = { val: false };
    const root = this.root === void 0 ? EMPTY : this.root;
    const newRoot = assoc(root, 0, getHash(key2), key2, val, addedLeaf);
    if (newRoot === this.root) {
      return this;
    }
    return new _Dict(newRoot, addedLeaf.val ? this.size + 1 : this.size);
  }
  /**
   * @param {K} key
   * @returns {Dict<K,V>}
   */
  delete(key2) {
    if (this.root === void 0) {
      return this;
    }
    const newRoot = without(this.root, 0, getHash(key2), key2);
    if (newRoot === this.root) {
      return this;
    }
    if (newRoot === void 0) {
      return _Dict.new();
    }
    return new _Dict(newRoot, this.size - 1);
  }
  /**
   * @param {K} key
   * @returns {boolean}
   */
  has(key2) {
    if (this.root === void 0) {
      return false;
    }
    return find(this.root, 0, getHash(key2), key2) !== void 0;
  }
  /**
   * @returns {[K,V][]}
   */
  entries() {
    if (this.root === void 0) {
      return [];
    }
    const result = [];
    this.forEach((v, k) => result.push([k, v]));
    return result;
  }
  /**
   *
   * @param {(val:V,key:K)=>void} fn
   */
  forEach(fn) {
    forEach(this.root, fn);
  }
  hashCode() {
    let h = 0;
    this.forEach((v, k) => {
      h = h + hashMerge(getHash(v), getHash(k)) | 0;
    });
    return h;
  }
  /**
   * @param {unknown} o
   * @returns {boolean}
   */
  equals(o) {
    if (!(o instanceof _Dict) || this.size !== o.size) {
      return false;
    }
    let equal = true;
    this.forEach((v, k) => {
      equal = equal && isEqual(o.get(k, !v), v);
    });
    return equal;
  }
};

// build/dev/javascript/gleam_stdlib/gleam_stdlib.mjs
var Nil = void 0;
var NOT_FOUND = {};
function identity(x) {
  return x;
}
function to_string2(term) {
  return term.toString();
}
function float_to_string(float3) {
  const string3 = float3.toString().replace("+", "");
  if (string3.indexOf(".") >= 0) {
    return string3;
  } else {
    const index3 = string3.indexOf("e");
    if (index3 >= 0) {
      return string3.slice(0, index3) + ".0" + string3.slice(index3);
    } else {
      return string3 + ".0";
    }
  }
}
function string_length(string3) {
  if (string3 === "") {
    return 0;
  }
  const iterator = graphemes_iterator(string3);
  if (iterator) {
    let i = 0;
    for (const _ of iterator) {
      i++;
    }
    return i;
  } else {
    return string3.match(/./gsu).length;
  }
}
var segmenter = void 0;
function graphemes_iterator(string3) {
  if (globalThis.Intl && Intl.Segmenter) {
    segmenter ||= new Intl.Segmenter();
    return segmenter.segment(string3)[Symbol.iterator]();
  }
}
function add2(a, b) {
  return a + b;
}
function join(xs, separator) {
  const iterator = xs[Symbol.iterator]();
  let result = iterator.next().value || "";
  let current = iterator.next();
  while (!current.done) {
    result = result + separator + current.value;
    current = iterator.next();
  }
  return result;
}
function string_slice(string3, idx, len) {
  if (len <= 0 || idx >= string3.length) {
    return "";
  }
  const iterator = graphemes_iterator(string3);
  if (iterator) {
    while (idx-- > 0) {
      iterator.next();
    }
    let result = "";
    while (len-- > 0) {
      const v = iterator.next().value;
      if (v === void 0) {
        break;
      }
      result += v.segment;
    }
    return result;
  } else {
    return string3.match(/./gsu).slice(idx, idx + len).join("");
  }
}
var unicode_whitespaces = [
  " ",
  // Space
  "	",
  // Horizontal tab
  "\n",
  // Line feed
  "\v",
  // Vertical tab
  "\f",
  // Form feed
  "\r",
  // Carriage return
  "\x85",
  // Next line
  "\u2028",
  // Line separator
  "\u2029"
  // Paragraph separator
].join("");
var left_trim_regex = new RegExp(`^([${unicode_whitespaces}]*)`, "g");
var right_trim_regex = new RegExp(`([${unicode_whitespaces}]*)$`, "g");
function random_uniform() {
  const random_uniform_result = Math.random();
  if (random_uniform_result === 1) {
    return random_uniform();
  }
  return random_uniform_result;
}
function new_map() {
  return Dict.new();
}
function map_to_list(map6) {
  return List.fromArray(map6.entries());
}
function map_get(map6, key2) {
  const value2 = map6.get(key2, NOT_FOUND);
  if (value2 === NOT_FOUND) {
    return new Error(Nil);
  }
  return new Ok(value2);
}
function map_insert(key2, value2, map6) {
  return map6.set(key2, value2);
}
function inspect(v) {
  const t = typeof v;
  if (v === true)
    return "True";
  if (v === false)
    return "False";
  if (v === null)
    return "//js(null)";
  if (v === void 0)
    return "Nil";
  if (t === "string")
    return inspectString(v);
  if (t === "bigint" || Number.isInteger(v))
    return v.toString();
  if (t === "number")
    return float_to_string(v);
  if (Array.isArray(v))
    return `#(${v.map(inspect).join(", ")})`;
  if (v instanceof List)
    return inspectList(v);
  if (v instanceof UtfCodepoint)
    return inspectUtfCodepoint(v);
  if (v instanceof BitArray)
    return inspectBitArray(v);
  if (v instanceof CustomType)
    return inspectCustomType(v);
  if (v instanceof Dict)
    return inspectDict(v);
  if (v instanceof Set)
    return `//js(Set(${[...v].map(inspect).join(", ")}))`;
  if (v instanceof RegExp)
    return `//js(${v})`;
  if (v instanceof Date)
    return `//js(Date("${v.toISOString()}"))`;
  if (v instanceof Function) {
    const args = [];
    for (const i of Array(v.length).keys())
      args.push(String.fromCharCode(i + 97));
    return `//fn(${args.join(", ")}) { ... }`;
  }
  return inspectObject(v);
}
function inspectString(str) {
  let new_str = '"';
  for (let i = 0; i < str.length; i++) {
    let char = str[i];
    switch (char) {
      case "\n":
        new_str += "\\n";
        break;
      case "\r":
        new_str += "\\r";
        break;
      case "	":
        new_str += "\\t";
        break;
      case "\f":
        new_str += "\\f";
        break;
      case "\\":
        new_str += "\\\\";
        break;
      case '"':
        new_str += '\\"';
        break;
      default:
        if (char < " " || char > "~" && char < "\xA0") {
          new_str += "\\u{" + char.charCodeAt(0).toString(16).toUpperCase().padStart(4, "0") + "}";
        } else {
          new_str += char;
        }
    }
  }
  new_str += '"';
  return new_str;
}
function inspectDict(map6) {
  let body = "dict.from_list([";
  let first4 = true;
  map6.forEach((value2, key2) => {
    if (!first4)
      body = body + ", ";
    body = body + "#(" + inspect(key2) + ", " + inspect(value2) + ")";
    first4 = false;
  });
  return body + "])";
}
function inspectObject(v) {
  const name = Object.getPrototypeOf(v)?.constructor?.name || "Object";
  const props = [];
  for (const k of Object.keys(v)) {
    props.push(`${inspect(k)}: ${inspect(v[k])}`);
  }
  const body = props.length ? " " + props.join(", ") + " " : "";
  const head = name === "Object" ? "" : name + " ";
  return `//js(${head}{${body}})`;
}
function inspectCustomType(record) {
  const props = Object.keys(record).map((label) => {
    const value2 = inspect(record[label]);
    return isNaN(parseInt(label)) ? `${label}: ${value2}` : value2;
  }).join(", ");
  return props ? `${record.constructor.name}(${props})` : record.constructor.name;
}
function inspectList(list) {
  return `[${list.toArray().map(inspect).join(", ")}]`;
}
function inspectBitArray(bits) {
  return `<<${Array.from(bits.buffer).join(", ")}>>`;
}
function inspectUtfCodepoint(codepoint2) {
  return `//utfcodepoint(${String.fromCodePoint(codepoint2.value)})`;
}

// build/dev/javascript/gleam_stdlib/gleam/dict.mjs
function new$2() {
  return new_map();
}
function get(from, get3) {
  return map_get(from, get3);
}
function insert(dict, key2, value2) {
  return map_insert(key2, value2, dict);
}
function from_list_loop(loop$list, loop$initial) {
  while (true) {
    let list = loop$list;
    let initial = loop$initial;
    if (list.hasLength(0)) {
      return initial;
    } else {
      let x = list.head;
      let rest = list.tail;
      loop$list = rest;
      loop$initial = insert(initial, x[0], x[1]);
    }
  }
}
function from_list(list) {
  return from_list_loop(list, new$2());
}
function reverse_and_concat(loop$remaining, loop$accumulator) {
  while (true) {
    let remaining = loop$remaining;
    let accumulator = loop$accumulator;
    if (remaining.hasLength(0)) {
      return accumulator;
    } else {
      let item = remaining.head;
      let rest = remaining.tail;
      loop$remaining = rest;
      loop$accumulator = prepend(item, accumulator);
    }
  }
}
function do_keys_loop(loop$list, loop$acc) {
  while (true) {
    let list = loop$list;
    let acc = loop$acc;
    if (list.hasLength(0)) {
      return reverse_and_concat(acc, toList([]));
    } else {
      let first4 = list.head;
      let rest = list.tail;
      loop$list = rest;
      loop$acc = prepend(first4[0], acc);
    }
  }
}
function do_keys(dict) {
  let list_of_pairs = map_to_list(dict);
  return do_keys_loop(list_of_pairs, toList([]));
}
function keys(dict) {
  return do_keys(dict);
}
function do_values_loop(loop$list, loop$acc) {
  while (true) {
    let list = loop$list;
    let acc = loop$acc;
    if (list.hasLength(0)) {
      return reverse_and_concat(acc, toList([]));
    } else {
      let first4 = list.head;
      let rest = list.tail;
      loop$list = rest;
      loop$acc = prepend(first4[1], acc);
    }
  }
}
function do_values(dict) {
  let list_of_pairs = map_to_list(dict);
  return do_values_loop(list_of_pairs, toList([]));
}
function values(dict) {
  return do_values(dict);
}

// build/dev/javascript/gleam_stdlib/gleam/bool.mjs
function guard(requirement, consequence, alternative) {
  if (requirement) {
    return consequence;
  } else {
    return alternative();
  }
}

// build/dev/javascript/lustre/lustre/effect.mjs
var Effect = class extends CustomType {
  constructor(all) {
    super();
    this.all = all;
  }
};
function none() {
  return new Effect(toList([]));
}

// build/dev/javascript/lustre/lustre/internals/vdom.mjs
var Text = class extends CustomType {
  constructor(content) {
    super();
    this.content = content;
  }
};
var Element2 = class extends CustomType {
  constructor(key2, namespace, tag, attrs, children2, self_closing, void$) {
    super();
    this.key = key2;
    this.namespace = namespace;
    this.tag = tag;
    this.attrs = attrs;
    this.children = children2;
    this.self_closing = self_closing;
    this.void = void$;
  }
};
var Map2 = class extends CustomType {
  constructor(subtree) {
    super();
    this.subtree = subtree;
  }
};
var Attribute = class extends CustomType {
  constructor(x0, x1, as_property) {
    super();
    this[0] = x0;
    this[1] = x1;
    this.as_property = as_property;
  }
};
var Event2 = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
function attribute_to_event_handler(attribute2) {
  if (attribute2 instanceof Attribute) {
    return new Error(void 0);
  } else {
    let name = attribute2[0];
    let handler = attribute2[1];
    let name$1 = drop_start(name, 2);
    return new Ok([name$1, handler]);
  }
}
function do_element_list_handlers(elements2, handlers2, key2) {
  return index_fold(
    elements2,
    handlers2,
    (handlers3, element3, index3) => {
      let key$1 = key2 + "-" + to_string3(index3);
      return do_handlers(element3, handlers3, key$1);
    }
  );
}
function do_handlers(loop$element, loop$handlers, loop$key) {
  while (true) {
    let element3 = loop$element;
    let handlers2 = loop$handlers;
    let key2 = loop$key;
    if (element3 instanceof Text) {
      return handlers2;
    } else if (element3 instanceof Map2) {
      let subtree = element3.subtree;
      loop$element = subtree();
      loop$handlers = handlers2;
      loop$key = key2;
    } else {
      let attrs = element3.attrs;
      let children2 = element3.children;
      let handlers$1 = fold(
        attrs,
        handlers2,
        (handlers3, attr) => {
          let $ = attribute_to_event_handler(attr);
          if ($.isOk()) {
            let name = $[0][0];
            let handler = $[0][1];
            return insert(handlers3, key2 + "-" + name, handler);
          } else {
            return handlers3;
          }
        }
      );
      return do_element_list_handlers(children2, handlers$1, key2);
    }
  }
}
function handlers(element3) {
  return do_handlers(element3, new$2(), "0");
}

// build/dev/javascript/lustre/lustre/attribute.mjs
function attribute(name, value2) {
  return new Attribute(name, identity(value2), false);
}
function on(name, handler) {
  return new Event2("on" + name, handler);
}
function style(properties) {
  return attribute(
    "style",
    fold(
      properties,
      "",
      (styles, _use1) => {
        let name$1 = _use1[0];
        let value$1 = _use1[1];
        return styles + name$1 + ":" + value$1 + ";";
      }
    )
  );
}
function class$(name) {
  return attribute("class", name);
}

// build/dev/javascript/lustre/lustre/element.mjs
function element(tag, attrs, children2) {
  if (tag === "area") {
    return new Element2("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "base") {
    return new Element2("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "br") {
    return new Element2("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "col") {
    return new Element2("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "embed") {
    return new Element2("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "hr") {
    return new Element2("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "img") {
    return new Element2("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "input") {
    return new Element2("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "link") {
    return new Element2("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "meta") {
    return new Element2("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "param") {
    return new Element2("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "source") {
    return new Element2("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "track") {
    return new Element2("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "wbr") {
    return new Element2("", "", tag, attrs, toList([]), false, true);
  } else {
    return new Element2("", "", tag, attrs, children2, false, false);
  }
}
function text(content) {
  return new Text(content);
}
function none2() {
  return new Text("");
}
function fragment(elements2) {
  return element(
    "lustre-fragment",
    toList([style(toList([["display", "contents"]]))]),
    elements2
  );
}

// build/dev/javascript/gleam_stdlib/gleam/set.mjs
var Set2 = class extends CustomType {
  constructor(dict) {
    super();
    this.dict = dict;
  }
};
function new$4() {
  return new Set2(new$2());
}

// build/dev/javascript/lustre/lustre/internals/patch.mjs
var Diff = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Emit = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Init = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
function is_empty_element_diff(diff2) {
  return isEqual(diff2.created, new$2()) && isEqual(
    diff2.removed,
    new$4()
  ) && isEqual(diff2.updated, new$2());
}

// build/dev/javascript/lustre/lustre/internals/runtime.mjs
var Attrs = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Batch = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Debug = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Dispatch = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Emit2 = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Event3 = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Shutdown = class extends CustomType {
};
var Subscribe = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Unsubscribe = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var ForceModel = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};

// build/dev/javascript/lustre/vdom.ffi.mjs
if (globalThis.customElements && !globalThis.customElements.get("lustre-fragment")) {
  globalThis.customElements.define(
    "lustre-fragment",
    class LustreFragment extends HTMLElement {
      constructor() {
        super();
      }
    }
  );
}
function morph(prev, next, dispatch) {
  let out;
  let stack = [{ prev, next, parent: prev.parentNode }];
  while (stack.length) {
    let { prev: prev2, next: next2, parent } = stack.pop();
    while (next2.subtree !== void 0)
      next2 = next2.subtree();
    if (next2.content !== void 0) {
      if (!prev2) {
        const created = document.createTextNode(next2.content);
        parent.appendChild(created);
        out ??= created;
      } else if (prev2.nodeType === Node.TEXT_NODE) {
        if (prev2.textContent !== next2.content)
          prev2.textContent = next2.content;
        out ??= prev2;
      } else {
        const created = document.createTextNode(next2.content);
        parent.replaceChild(created, prev2);
        out ??= created;
      }
    } else if (next2.tag !== void 0) {
      const created = createElementNode({
        prev: prev2,
        next: next2,
        dispatch,
        stack
      });
      if (!prev2) {
        parent.appendChild(created);
      } else if (prev2 !== created) {
        parent.replaceChild(created, prev2);
      }
      out ??= created;
    }
  }
  return out;
}
function createElementNode({ prev, next, dispatch, stack }) {
  const namespace = next.namespace || "http://www.w3.org/1999/xhtml";
  const canMorph = prev && prev.nodeType === Node.ELEMENT_NODE && prev.localName === next.tag && prev.namespaceURI === (next.namespace || "http://www.w3.org/1999/xhtml");
  const el = canMorph ? prev : namespace ? document.createElementNS(namespace, next.tag) : document.createElement(next.tag);
  let handlersForEl;
  if (!registeredHandlers.has(el)) {
    const emptyHandlers = /* @__PURE__ */ new Map();
    registeredHandlers.set(el, emptyHandlers);
    handlersForEl = emptyHandlers;
  } else {
    handlersForEl = registeredHandlers.get(el);
  }
  const prevHandlers = canMorph ? new Set(handlersForEl.keys()) : null;
  const prevAttributes = canMorph ? new Set(Array.from(prev.attributes, (a) => a.name)) : null;
  let className = null;
  let style3 = null;
  let innerHTML = null;
  if (canMorph && next.tag === "textarea") {
    const innertText = next.children[Symbol.iterator]().next().value?.content;
    if (innertText !== void 0)
      el.value = innertText;
  }
  const delegated = [];
  for (const attr of next.attrs) {
    const name = attr[0];
    const value2 = attr[1];
    if (attr.as_property) {
      if (el[name] !== value2)
        el[name] = value2;
      if (canMorph)
        prevAttributes.delete(name);
    } else if (name.startsWith("on")) {
      const eventName = name.slice(2);
      const callback = dispatch(value2, eventName === "input");
      if (!handlersForEl.has(eventName)) {
        el.addEventListener(eventName, lustreGenericEventHandler);
      }
      handlersForEl.set(eventName, callback);
      if (canMorph)
        prevHandlers.delete(eventName);
    } else if (name.startsWith("data-lustre-on-")) {
      const eventName = name.slice(15);
      const callback = dispatch(lustreServerEventHandler);
      if (!handlersForEl.has(eventName)) {
        el.addEventListener(eventName, lustreGenericEventHandler);
      }
      handlersForEl.set(eventName, callback);
      el.setAttribute(name, value2);
      if (canMorph) {
        prevHandlers.delete(eventName);
        prevAttributes.delete(name);
      }
    } else if (name.startsWith("delegate:data-") || name.startsWith("delegate:aria-")) {
      el.setAttribute(name, value2);
      delegated.push([name.slice(10), value2]);
    } else if (name === "class") {
      className = className === null ? value2 : className + " " + value2;
    } else if (name === "style") {
      style3 = style3 === null ? value2 : style3 + value2;
    } else if (name === "dangerous-unescaped-html") {
      innerHTML = value2;
    } else {
      if (el.getAttribute(name) !== value2)
        el.setAttribute(name, value2);
      if (name === "value" || name === "selected")
        el[name] = value2;
      if (canMorph)
        prevAttributes.delete(name);
    }
  }
  if (className !== null) {
    el.setAttribute("class", className);
    if (canMorph)
      prevAttributes.delete("class");
  }
  if (style3 !== null) {
    el.setAttribute("style", style3);
    if (canMorph)
      prevAttributes.delete("style");
  }
  if (canMorph) {
    for (const attr of prevAttributes) {
      el.removeAttribute(attr);
    }
    for (const eventName of prevHandlers) {
      handlersForEl.delete(eventName);
      el.removeEventListener(eventName, lustreGenericEventHandler);
    }
  }
  if (next.tag === "slot") {
    window.queueMicrotask(() => {
      for (const child of el.assignedElements()) {
        for (const [name, value2] of delegated) {
          if (!child.hasAttribute(name)) {
            child.setAttribute(name, value2);
          }
        }
      }
    });
  }
  if (next.key !== void 0 && next.key !== "") {
    el.setAttribute("data-lustre-key", next.key);
  } else if (innerHTML !== null) {
    el.innerHTML = innerHTML;
    return el;
  }
  let prevChild = el.firstChild;
  let seenKeys = null;
  let keyedChildren = null;
  let incomingKeyedChildren = null;
  let firstChild = children(next).next().value;
  if (canMorph && firstChild !== void 0 && // Explicit checks are more verbose but truthy checks force a bunch of comparisons
  // we don't care about: it's never gonna be a number etc.
  firstChild.key !== void 0 && firstChild.key !== "") {
    seenKeys = /* @__PURE__ */ new Set();
    keyedChildren = getKeyedChildren(prev);
    incomingKeyedChildren = getKeyedChildren(next);
    for (const child of children(next)) {
      prevChild = diffKeyedChild(
        prevChild,
        child,
        el,
        stack,
        incomingKeyedChildren,
        keyedChildren,
        seenKeys
      );
    }
  } else {
    for (const child of children(next)) {
      stack.unshift({ prev: prevChild, next: child, parent: el });
      prevChild = prevChild?.nextSibling;
    }
  }
  while (prevChild) {
    const next2 = prevChild.nextSibling;
    el.removeChild(prevChild);
    prevChild = next2;
  }
  return el;
}
var registeredHandlers = /* @__PURE__ */ new WeakMap();
function lustreGenericEventHandler(event2) {
  const target2 = event2.currentTarget;
  if (!registeredHandlers.has(target2)) {
    target2.removeEventListener(event2.type, lustreGenericEventHandler);
    return;
  }
  const handlersForEventTarget = registeredHandlers.get(target2);
  if (!handlersForEventTarget.has(event2.type)) {
    target2.removeEventListener(event2.type, lustreGenericEventHandler);
    return;
  }
  handlersForEventTarget.get(event2.type)(event2);
}
function lustreServerEventHandler(event2) {
  const el = event2.currentTarget;
  const tag = el.getAttribute(`data-lustre-on-${event2.type}`);
  const data = JSON.parse(el.getAttribute("data-lustre-data") || "{}");
  const include = JSON.parse(el.getAttribute("data-lustre-include") || "[]");
  switch (event2.type) {
    case "input":
    case "change":
      include.push("target.value");
      break;
  }
  return {
    tag,
    data: include.reduce(
      (data2, property2) => {
        const path = property2.split(".");
        for (let i = 0, o = data2, e = event2; i < path.length; i++) {
          if (i === path.length - 1) {
            o[path[i]] = e[path[i]];
          } else {
            o[path[i]] ??= {};
            e = e[path[i]];
            o = o[path[i]];
          }
        }
        return data2;
      },
      { data }
    )
  };
}
function getKeyedChildren(el) {
  const keyedChildren = /* @__PURE__ */ new Map();
  if (el) {
    for (const child of children(el)) {
      const key2 = child?.key || child?.getAttribute?.("data-lustre-key");
      if (key2)
        keyedChildren.set(key2, child);
    }
  }
  return keyedChildren;
}
function diffKeyedChild(prevChild, child, el, stack, incomingKeyedChildren, keyedChildren, seenKeys) {
  while (prevChild && !incomingKeyedChildren.has(prevChild.getAttribute("data-lustre-key"))) {
    const nextChild = prevChild.nextSibling;
    el.removeChild(prevChild);
    prevChild = nextChild;
  }
  if (keyedChildren.size === 0) {
    stack.unshift({ prev: prevChild, next: child, parent: el });
    prevChild = prevChild?.nextSibling;
    return prevChild;
  }
  if (seenKeys.has(child.key)) {
    console.warn(`Duplicate key found in Lustre vnode: ${child.key}`);
    stack.unshift({ prev: null, next: child, parent: el });
    return prevChild;
  }
  seenKeys.add(child.key);
  const keyedChild = keyedChildren.get(child.key);
  if (!keyedChild && !prevChild) {
    stack.unshift({ prev: null, next: child, parent: el });
    return prevChild;
  }
  if (!keyedChild && prevChild !== null) {
    const placeholder = document.createTextNode("");
    el.insertBefore(placeholder, prevChild);
    stack.unshift({ prev: placeholder, next: child, parent: el });
    return prevChild;
  }
  if (!keyedChild || keyedChild === prevChild) {
    stack.unshift({ prev: prevChild, next: child, parent: el });
    prevChild = prevChild?.nextSibling;
    return prevChild;
  }
  el.insertBefore(keyedChild, prevChild);
  stack.unshift({ prev: keyedChild, next: child, parent: el });
  return prevChild;
}
function* children(element3) {
  for (const child of element3.children) {
    yield* forceChild(child);
  }
}
function* forceChild(element3) {
  if (element3.subtree !== void 0) {
    yield* forceChild(element3.subtree());
  } else {
    yield element3;
  }
}

// build/dev/javascript/lustre/lustre.ffi.mjs
var LustreClientApplication = class _LustreClientApplication {
  /**
   * @template Flags
   *
   * @param {object} app
   * @param {(flags: Flags) => [Model, Lustre.Effect<Msg>]} app.init
   * @param {(msg: Msg, model: Model) => [Model, Lustre.Effect<Msg>]} app.update
   * @param {(model: Model) => Lustre.Element<Msg>} app.view
   * @param {string | HTMLElement} selector
   * @param {Flags} flags
   *
   * @returns {Gleam.Ok<(action: Lustre.Action<Lustre.Client, Msg>>) => void>}
   */
  static start({ init: init3, update: update2, view: view2 }, selector, flags) {
    if (!is_browser())
      return new Error(new NotABrowser());
    const root = selector instanceof HTMLElement ? selector : document.querySelector(selector);
    if (!root)
      return new Error(new ElementNotFound(selector));
    const app = new _LustreClientApplication(root, init3(flags), update2, view2);
    return new Ok((action) => app.send(action));
  }
  /**
   * @param {Element} root
   * @param {[Model, Lustre.Effect<Msg>]} init
   * @param {(model: Model, msg: Msg) => [Model, Lustre.Effect<Msg>]} update
   * @param {(model: Model) => Lustre.Element<Msg>} view
   *
   * @returns {LustreClientApplication}
   */
  constructor(root, [init3, effects], update2, view2) {
    this.root = root;
    this.#model = init3;
    this.#update = update2;
    this.#view = view2;
    this.#tickScheduled = window.requestAnimationFrame(
      () => this.#tick(effects.all.toArray(), true)
    );
  }
  /** @type {Element} */
  root;
  /**
   * @param {Lustre.Action<Lustre.Client, Msg>} action
   *
   * @returns {void}
   */
  send(action) {
    if (action instanceof Debug) {
      if (action[0] instanceof ForceModel) {
        this.#tickScheduled = window.cancelAnimationFrame(this.#tickScheduled);
        this.#queue = [];
        this.#model = action[0][0];
        const vdom = this.#view(this.#model);
        const dispatch = (handler, immediate = false) => (event2) => {
          const result = handler(event2);
          if (result instanceof Ok) {
            this.send(new Dispatch(result[0], immediate));
          }
        };
        const prev = this.root.firstChild ?? this.root.appendChild(document.createTextNode(""));
        morph(prev, vdom, dispatch);
      }
    } else if (action instanceof Dispatch) {
      const msg = action[0];
      const immediate = action[1] ?? false;
      this.#queue.push(msg);
      if (immediate) {
        this.#tickScheduled = window.cancelAnimationFrame(this.#tickScheduled);
        this.#tick();
      } else if (!this.#tickScheduled) {
        this.#tickScheduled = window.requestAnimationFrame(() => this.#tick());
      }
    } else if (action instanceof Emit2) {
      const event2 = action[0];
      const data = action[1];
      this.root.dispatchEvent(
        new CustomEvent(event2, {
          detail: data,
          bubbles: true,
          composed: true
        })
      );
    } else if (action instanceof Shutdown) {
      this.#tickScheduled = window.cancelAnimationFrame(this.#tickScheduled);
      this.#model = null;
      this.#update = null;
      this.#view = null;
      this.#queue = null;
      while (this.root.firstChild) {
        this.root.firstChild.remove();
      }
    }
  }
  /** @type {Model} */
  #model;
  /** @type {(model: Model, msg: Msg) => [Model, Lustre.Effect<Msg>]} */
  #update;
  /** @type {(model: Model) => Lustre.Element<Msg>} */
  #view;
  /** @type {Array<Msg>} */
  #queue = [];
  /** @type {number | undefined} */
  #tickScheduled;
  /**
   * @param {Lustre.Effect<Msg>[]} effects
   */
  #tick(effects = []) {
    this.#tickScheduled = void 0;
    this.#flush(effects);
    const vdom = this.#view(this.#model);
    const dispatch = (handler, immediate = false) => (event2) => {
      const result = handler(event2);
      if (result instanceof Ok) {
        this.send(new Dispatch(result[0], immediate));
      }
    };
    const prev = this.root.firstChild ?? this.root.appendChild(document.createTextNode(""));
    morph(prev, vdom, dispatch);
  }
  #flush(effects = []) {
    while (this.#queue.length > 0) {
      const msg = this.#queue.shift();
      const [next, effect] = this.#update(this.#model, msg);
      effects = effects.concat(effect.all.toArray());
      this.#model = next;
    }
    while (effects.length > 0) {
      const effect = effects.shift();
      const dispatch = (msg) => this.send(new Dispatch(msg));
      const emit2 = (event2, data) => this.root.dispatchEvent(
        new CustomEvent(event2, {
          detail: data,
          bubbles: true,
          composed: true
        })
      );
      const select2 = () => {
      };
      const root = this.root;
      effect({ dispatch, emit: emit2, select: select2, root });
    }
    if (this.#queue.length > 0) {
      this.#flush(effects);
    }
  }
};
var start = LustreClientApplication.start;
var LustreServerApplication = class _LustreServerApplication {
  static start({ init: init3, update: update2, view: view2, on_attribute_change }, flags) {
    const app = new _LustreServerApplication(
      init3(flags),
      update2,
      view2,
      on_attribute_change
    );
    return new Ok((action) => app.send(action));
  }
  constructor([model, effects], update2, view2, on_attribute_change) {
    this.#model = model;
    this.#update = update2;
    this.#view = view2;
    this.#html = view2(model);
    this.#onAttributeChange = on_attribute_change;
    this.#renderers = /* @__PURE__ */ new Map();
    this.#handlers = handlers(this.#html);
    this.#tick(effects.all.toArray());
  }
  send(action) {
    if (action instanceof Attrs) {
      for (const attr of action[0]) {
        const decoder = this.#onAttributeChange.get(attr[0]);
        if (!decoder)
          continue;
        const msg = decoder(attr[1]);
        if (msg instanceof Error)
          continue;
        this.#queue.push(msg);
      }
      this.#tick();
    } else if (action instanceof Batch) {
      this.#queue = this.#queue.concat(action[0].toArray());
      this.#tick(action[1].all.toArray());
    } else if (action instanceof Debug) {
    } else if (action instanceof Dispatch) {
      this.#queue.push(action[0]);
      this.#tick();
    } else if (action instanceof Emit2) {
      const event2 = new Emit(action[0], action[1]);
      for (const [_, renderer] of this.#renderers) {
        renderer(event2);
      }
    } else if (action instanceof Event3) {
      const handler = this.#handlers.get(action[0]);
      if (!handler)
        return;
      const msg = handler(action[1]);
      if (msg instanceof Error)
        return;
      this.#queue.push(msg[0]);
      this.#tick();
    } else if (action instanceof Subscribe) {
      const attrs = keys(this.#onAttributeChange);
      const patch = new Init(attrs, this.#html);
      this.#renderers = this.#renderers.set(action[0], action[1]);
      action[1](patch);
    } else if (action instanceof Unsubscribe) {
      this.#renderers = this.#renderers.delete(action[0]);
    }
  }
  #model;
  #update;
  #queue;
  #view;
  #html;
  #renderers;
  #handlers;
  #onAttributeChange;
  #tick(effects = []) {
    this.#flush(effects);
    const vdom = this.#view(this.#model);
    const diff2 = elements(this.#html, vdom);
    if (!is_empty_element_diff(diff2)) {
      const patch = new Diff(diff2);
      for (const [_, renderer] of this.#renderers) {
        renderer(patch);
      }
    }
    this.#html = vdom;
    this.#handlers = diff2.handlers;
  }
  #flush(effects = []) {
    while (this.#queue.length > 0) {
      const msg = this.#queue.shift();
      const [next, effect] = this.#update(this.#model, msg);
      effects = effects.concat(effect.all.toArray());
      this.#model = next;
    }
    while (effects.length > 0) {
      const effect = effects.shift();
      const dispatch = (msg) => this.send(new Dispatch(msg));
      const emit2 = (event2, data) => this.root.dispatchEvent(
        new CustomEvent(event2, {
          detail: data,
          bubbles: true,
          composed: true
        })
      );
      const select2 = () => {
      };
      const root = null;
      effect({ dispatch, emit: emit2, select: select2, root });
    }
    if (this.#queue.length > 0) {
      this.#flush(effects);
    }
  }
};
var start_server_application = LustreServerApplication.start;
var is_browser = () => globalThis.window && window.document;

// build/dev/javascript/lustre/lustre.mjs
var App = class extends CustomType {
  constructor(init3, update2, view2, on_attribute_change) {
    super();
    this.init = init3;
    this.update = update2;
    this.view = view2;
    this.on_attribute_change = on_attribute_change;
  }
};
var ElementNotFound = class extends CustomType {
  constructor(selector) {
    super();
    this.selector = selector;
  }
};
var NotABrowser = class extends CustomType {
};
function application(init3, update2, view2) {
  return new App(init3, update2, view2, new None());
}
function simple(init3, update2, view2) {
  let init$1 = (flags) => {
    return [init3(flags), none()];
  };
  let update$1 = (model, msg) => {
    return [update2(model, msg), none()];
  };
  return application(init$1, update$1, view2);
}
function start2(app, selector, flags) {
  return guard(
    !is_browser(),
    new Error(new NotABrowser()),
    () => {
      return start(app, selector, flags);
    }
  );
}

// build/dev/javascript/lustre/lustre/event.mjs
function on2(name, handler) {
  return on(name, handler);
}
function on_click(msg) {
  return on2("click", (_) => {
    return new Ok(msg);
  });
}

// build/dev/javascript/sketch/sketch/internals/class.mjs
var Definitions = class extends CustomType {
  constructor(medias_def, selectors_def, class_def) {
    super();
    this.medias_def = medias_def;
    this.selectors_def = selectors_def;
    this.class_def = class_def;
  }
};
var Content = class extends CustomType {
  constructor(class_name4, class_id, definitions2, rules) {
    super();
    this.class_name = class_name4;
    this.class_id = class_id;
    this.definitions = definitions2;
    this.rules = rules;
  }
};
function class_name(class$4) {
  return class$4.class_name;
}
function definitions(class$4) {
  let $ = class$4.definitions;
  let medias = $.medias_def;
  let selectors = $.selectors_def;
  let class$1 = $.class_def;
  let _pipe = toList([toList([class$1]), selectors, medias]);
  return concat(_pipe);
}
function create(class_name4, class_id, rules, definitions2) {
  return new Content(class_name4, class_id, definitions2, rules);
}

// build/dev/javascript/sketch/sketch/internals/string.mjs
function indent(indent2) {
  return repeat(" ", indent2);
}
function wrap_class(id, properties, idt, pseudo) {
  let base_indent = indent(idt);
  let pseudo_ = unwrap(pseudo, "");
  let _pipe = prepend(
    base_indent + "." + id + pseudo_ + " {",
    properties
  );
  let _pipe$1 = join2(_pipe, "\n");
  return append3(_pipe$1, "\n" + base_indent + "}");
}

// build/dev/javascript/sketch/xxhash.ffi.bin.mjs
var wasmBytes = "AGFzbQEAAAABMAhgA39/fwF/YAN/f38AYAJ/fwBgAX8Bf2ADf39+AX5gA35/fwF+YAJ/fgBgAX8BfgMLCgAAAgEDBAUGAQcFAwEAAQdVCQNtZW0CAAV4eGgzMgAABmluaXQzMgACCHVwZGF0ZTMyAAMIZGlnZXN0MzIABAV4eGg2NAAFBmluaXQ2NAAHCHVwZGF0ZTY0AAgIZGlnZXN0NjQACQr7FgryAQEEfyAAIAFqIQMgAUEQTwR/IANBEGshBiACQaiIjaECaiEDIAJBievQ0AdrIQQgAkHPjKKOBmohBQNAIAMgACgCAEH3lK+veGxqQQ13QbHz3fF5bCEDIAQgAEEEaiIAKAIAQfeUr694bGpBDXdBsfPd8XlsIQQgAiAAQQRqIgAoAgBB95Svr3hsakENd0Gx893xeWwhAiAFIABBBGoiACgCAEH3lK+veGxqQQ13QbHz3fF5bCEFIAYgAEEEaiIATw0ACyACQQx3IAVBEndqIARBB3dqIANBAXdqBSACQbHP2bIBagsgAWogACABQQ9xEAELkgEAIAEgAmohAgNAIAFBBGogAktFBEAgACABKAIAQb3cypV8bGpBEXdBr9bTvgJsIQAgAUEEaiEBDAELCwNAIAEgAk9FBEAgACABLQAAQbHP2bIBbGpBC3dBsfPd8XlsIQAgAUEBaiEBDAELCyAAIABBD3ZzQfeUr694bCIAQQ12IABzQb3cypV8bCIAQRB2IABzCz8AIABBCGogAUGoiI2hAmo2AgAgAEEMaiABQYnr0NAHazYCACAAQRBqIAE2AgAgAEEUaiABQc+Moo4GajYCAAvDBAEGfyABIAJqIQYgAEEYaiEEIABBKGooAgAhAyAAIAAoAgAgAmo2AgAgAEEEaiIFIAUoAgAgAkEQTyAAKAIAQRBPcnI2AgAgAiADakEQSQRAIAMgBGogASAC/AoAACAAQShqIAIgA2o2AgAPCyADBEAgAyAEaiABQRAgA2siAvwKAAAgAEEIaiIDIAMoAgAgBCgCAEH3lK+veGxqQQ13QbHz3fF5bDYCACAAQQxqIgMgAygCACAEQQRqKAIAQfeUr694bGpBDXdBsfPd8XlsNgIAIABBEGoiAyADKAIAIARBCGooAgBB95Svr3hsakENd0Gx893xeWw2AgAgAEEUaiIDIAMoAgAgBEEMaigCAEH3lK+veGxqQQ13QbHz3fF5bDYCACAAQShqQQA2AgAgASACaiEBCyABIAZBEGtNBEAgBkEQayEIIABBCGooAgAhAiAAQQxqKAIAIQMgAEEQaigCACEFIABBFGooAgAhBwNAIAIgASgCAEH3lK+veGxqQQ13QbHz3fF5bCECIAMgAUEEaiIBKAIAQfeUr694bGpBDXdBsfPd8XlsIQMgBSABQQRqIgEoAgBB95Svr3hsakENd0Gx893xeWwhBSAHIAFBBGoiASgCAEH3lK+veGxqQQ13QbHz3fF5bCEHIAggAUEEaiIBTw0ACyAAQQhqIAI2AgAgAEEMaiADNgIAIABBEGogBTYCACAAQRRqIAc2AgALIAEgBkkEQCAEIAEgBiABayIB/AoAACAAQShqIAE2AgALC2EBAX8gAEEQaigCACEBIABBBGooAgAEfyABQQx3IABBFGooAgBBEndqIABBDGooAgBBB3dqIABBCGooAgBBAXdqBSABQbHP2bIBagsgACgCAGogAEEYaiAAQShqKAIAEAEL/wMCA34BfyAAIAFqIQYgAUEgTwR+IAZBIGshBiACQtbrgu7q/Yn14AB8IQMgAkKxqazBrbjUpj19IQQgAkL56tDQ58mh5OEAfCEFA0AgAyAAKQMAQs/W077Sx6vZQn58Qh+JQoeVr6+Ytt6bnn9+IQMgBCAAQQhqIgApAwBCz9bTvtLHq9lCfnxCH4lCh5Wvr5i23puef34hBCACIABBCGoiACkDAELP1tO+0ser2UJ+fEIfiUKHla+vmLbem55/fiECIAUgAEEIaiIAKQMAQs/W077Sx6vZQn58Qh+JQoeVr6+Ytt6bnn9+IQUgBiAAQQhqIgBPDQALIAJCDIkgBUISiXwgBEIHiXwgA0IBiXwgA0LP1tO+0ser2UJ+Qh+JQoeVr6+Ytt6bnn9+hUKHla+vmLbem55/fkKdo7Xqg7GNivoAfSAEQs/W077Sx6vZQn5CH4lCh5Wvr5i23puef36FQoeVr6+Ytt6bnn9+Qp2jteqDsY2K+gB9IAJCz9bTvtLHq9lCfkIfiUKHla+vmLbem55/foVCh5Wvr5i23puef35CnaO16oOxjYr6AH0gBULP1tO+0ser2UJ+Qh+JQoeVr6+Ytt6bnn9+hUKHla+vmLbem55/fkKdo7Xqg7GNivoAfQUgAkLFz9my8eW66id8CyABrXwgACABQR9xEAYLhgIAIAEgAmohAgNAIAIgAUEIak8EQCABKQMAQs/W077Sx6vZQn5CH4lCh5Wvr5i23puef34gAIVCG4lCh5Wvr5i23puef35CnaO16oOxjYr6AH0hACABQQhqIQEMAQsLIAFBBGogAk0EQCAAIAE1AgBCh5Wvr5i23puef36FQheJQs/W077Sx6vZQn5C+fPd8Zn2masWfCEAIAFBBGohAQsDQCABIAJJBEAgACABMQAAQsXP2bLx5brqJ36FQguJQoeVr6+Ytt6bnn9+IQAgAUEBaiEBDAELCyAAIABCIYiFQs/W077Sx6vZQn4iACAAQh2IhUL5893xmfaZqxZ+IgAgAEIgiIULTQAgAEEIaiABQtbrgu7q/Yn14AB8NwMAIABBEGogAUKxqazBrbjUpj19NwMAIABBGGogATcDACAAQSBqIAFC+erQ0OfJoeThAHw3AwAL9AQCA38EfiABIAJqIQUgAEEoaiEEIABByABqKAIAIQMgACAAKQMAIAKtfDcDACACIANqQSBJBEAgAyAEaiABIAL8CgAAIABByABqIAIgA2o2AgAPCyADBEAgAyAEaiABQSAgA2siAvwKAAAgAEEIaiIDIAMpAwAgBCkDAELP1tO+0ser2UJ+fEIfiUKHla+vmLbem55/fjcDACAAQRBqIgMgAykDACAEQQhqKQMAQs/W077Sx6vZQn58Qh+JQoeVr6+Ytt6bnn9+NwMAIABBGGoiAyADKQMAIARBEGopAwBCz9bTvtLHq9lCfnxCH4lCh5Wvr5i23puef343AwAgAEEgaiIDIAMpAwAgBEEYaikDAELP1tO+0ser2UJ+fEIfiUKHla+vmLbem55/fjcDACAAQcgAakEANgIAIAEgAmohAQsgAUEgaiAFTQRAIAVBIGshAiAAQQhqKQMAIQYgAEEQaikDACEHIABBGGopAwAhCCAAQSBqKQMAIQkDQCAGIAEpAwBCz9bTvtLHq9lCfnxCH4lCh5Wvr5i23puef34hBiAHIAFBCGoiASkDAELP1tO+0ser2UJ+fEIfiUKHla+vmLbem55/fiEHIAggAUEIaiIBKQMAQs/W077Sx6vZQn58Qh+JQoeVr6+Ytt6bnn9+IQggCSABQQhqIgEpAwBCz9bTvtLHq9lCfnxCH4lCh5Wvr5i23puef34hCSACIAFBCGoiAU8NAAsgAEEIaiAGNwMAIABBEGogBzcDACAAQRhqIAg3AwAgAEEgaiAJNwMACyABIAVJBEAgBCABIAUgAWsiAfwKAAAgAEHIAGogATYCAAsLvAIBBX4gAEEYaikDACEBIAApAwAiAkIgWgR+IABBCGopAwAiA0IBiSAAQRBqKQMAIgRCB4l8IAFCDIkgAEEgaikDACIFQhKJfHwgA0LP1tO+0ser2UJ+Qh+JQoeVr6+Ytt6bnn9+hUKHla+vmLbem55/fkKdo7Xqg7GNivoAfSAEQs/W077Sx6vZQn5CH4lCh5Wvr5i23puef36FQoeVr6+Ytt6bnn9+Qp2jteqDsY2K+gB9IAFCz9bTvtLHq9lCfkIfiUKHla+vmLbem55/foVCh5Wvr5i23puef35CnaO16oOxjYr6AH0gBULP1tO+0ser2UJ+Qh+JQoeVr6+Ytt6bnn9+hUKHla+vmLbem55/fkKdo7Xqg7GNivoAfQUgAULFz9my8eW66id8CyACfCAAQShqIAJCH4OnEAYL";

// build/dev/javascript/sketch/xxhash.ffi.mjs
var u32_BYTES = 4;
var u64_BYTES = 8;
var XXH32_STATE_SIZE_BYTES = u32_BYTES + // total_len
u32_BYTES + // large_len
u32_BYTES * 4 + // Accumulator lanes
u32_BYTES * 4 + // Internal buffer
u32_BYTES + // memsize
u32_BYTES;
var XXH64_STATE_SIZE_BYTES = u64_BYTES + // total_len
u64_BYTES * 4 + // Accumulator lanes
u64_BYTES * 4 + // Internal buffer
u32_BYTES + // memsize
u32_BYTES + // reserved32
u64_BYTES;
function xxhash() {
  const bytes = Uint8Array.from(atob(wasmBytes), (c) => c.charCodeAt(0));
  const mod = new WebAssembly.Module(bytes);
  const {
    exports: {
      mem,
      xxh32,
      xxh64,
      init32,
      update32,
      digest32,
      init64,
      update64,
      digest64
    }
  } = new WebAssembly.Instance(mod);
  let memory = new Uint8Array(mem.buffer);
  function growMemory(length5, offset) {
    if (mem.buffer.byteLength < length5 + offset) {
      const extraPages = Math.ceil(
        // Wasm pages are spec'd to 64K
        (length5 + offset - mem.buffer.byteLength) / (64 * 1024)
      );
      mem.grow(extraPages);
      memory = new Uint8Array(mem.buffer);
    }
  }
  function create2(size, seed, init3, update2, digest, finalize) {
    growMemory(size);
    const state = new Uint8Array(size);
    memory.set(state);
    init3(0, seed);
    state.set(memory.slice(0, size));
    return {
      update(input) {
        memory.set(state);
        let length5;
        if (typeof input === "string") {
          growMemory(input.length * 3, size);
          length5 = encoder.encodeInto(input, memory.subarray(size)).written;
        } else {
          growMemory(input.byteLength, size);
          memory.set(input, size);
          length5 = input.byteLength;
        }
        update2(0, size, length5);
        state.set(memory.slice(0, size));
        return this;
      },
      digest() {
        memory.set(state);
        return finalize(digest(0));
      }
    };
  }
  function forceUnsigned32(i) {
    return i >>> 0;
  }
  const u64Max = 2n ** 64n - 1n;
  function forceUnsigned64(i) {
    return i & u64Max;
  }
  const encoder = new TextEncoder();
  const defaultSeed = 0;
  const defaultBigSeed = 0n;
  function h32(str, seed = defaultSeed) {
    growMemory(str.length * 3, 0);
    return forceUnsigned32(
      xxh32(0, encoder.encodeInto(str, memory).written, seed)
    );
  }
  function h64(str, seed = defaultBigSeed) {
    growMemory(str.length * 3, 0);
    return forceUnsigned64(
      xxh64(0, encoder.encodeInto(str, memory).written, seed)
    );
  }
  return {
    h32,
    h32ToString(str, seed = defaultSeed) {
      return h32(str, seed).toString(16).padStart(8, "0");
    },
    h32Raw(inputBuffer, seed = defaultSeed) {
      growMemory(inputBuffer.byteLength, 0);
      memory.set(inputBuffer);
      return forceUnsigned32(xxh32(0, inputBuffer.byteLength, seed));
    },
    create32(seed = defaultSeed) {
      return create2(
        XXH32_STATE_SIZE_BYTES,
        seed,
        init32,
        update32,
        digest32,
        forceUnsigned32
      );
    },
    h64,
    h64ToString(str, seed = defaultBigSeed) {
      return h64(str, seed).toString(16).padStart(16, "0");
    },
    h64Raw(inputBuffer, seed = defaultBigSeed) {
      growMemory(inputBuffer.byteLength, 0);
      memory.set(inputBuffer);
      return forceUnsigned64(xxh64(0, inputBuffer.byteLength, seed));
    },
    create64(seed = defaultBigSeed) {
      return create2(
        XXH64_STATE_SIZE_BYTES,
        seed,
        init64,
        update64,
        digest64,
        forceUnsigned64
      );
    }
  };
}
var hasher = xxhash();
function xxHash32(content) {
  return hasher.h32(content);
}

// build/dev/javascript/sketch/sketch/internals/style.mjs
var Class = class extends CustomType {
  constructor(string_representation, content) {
    super();
    this.string_representation = string_representation;
    this.content = content;
  }
};
var EphemeralCache = class extends CustomType {
  constructor(cache2) {
    super();
    this.cache = cache2;
  }
};
var PersistentCache = class extends CustomType {
  constructor(cache2, current_id) {
    super();
    this.cache = cache2;
    this.current_id = current_id;
  }
};
var ClassName = class extends CustomType {
  constructor(class_name4) {
    super();
    this.class_name = class_name4;
  }
};
var Media = class extends CustomType {
  constructor(query, styles) {
    super();
    this.query = query;
    this.styles = styles;
  }
};
var PseudoSelector = class extends CustomType {
  constructor(pseudo_selector, styles) {
    super();
    this.pseudo_selector = pseudo_selector;
    this.styles = styles;
  }
};
var Property = class extends CustomType {
  constructor(key2, value2, important) {
    super();
    this.key = key2;
    this.value = value2;
    this.important = important;
  }
};
var NoStyle = class extends CustomType {
};
var ComputedProperties = class extends CustomType {
  constructor(properties, medias, pseudo_selectors, indent2) {
    super();
    this.properties = properties;
    this.medias = medias;
    this.pseudo_selectors = pseudo_selectors;
    this.indent = indent2;
  }
};
var MediaProperty = class extends CustomType {
  constructor(query, properties, pseudo_selectors) {
    super();
    this.query = query;
    this.properties = properties;
    this.pseudo_selectors = pseudo_selectors;
  }
};
var PseudoProperty = class extends CustomType {
  constructor(pseudo_selector, properties) {
    super();
    this.pseudo_selector = pseudo_selector;
    this.properties = properties;
  }
};
var ComputedClass = class extends CustomType {
  constructor(class_def, medias_def, selectors_def, name) {
    super();
    this.class_def = class_def;
    this.medias_def = medias_def;
    this.selectors_def = selectors_def;
    this.name = name;
  }
};
function persistent() {
  return new PersistentCache(new$2(), 0);
}
function ephemeral() {
  return new EphemeralCache(new$2());
}
function compute_property(indent2, key2, value2, important) {
  let base_indent = indent(indent2);
  let important_ = (() => {
    if (important) {
      return " !important";
    } else {
      return "";
    }
  })();
  return base_indent + key2 + ": " + value2 + important_ + ";";
}
function init_computed_properties(indent2) {
  return new ComputedProperties(toList([]), toList([]), toList([]), indent2);
}
function merge_computed_properties(target2, argument) {
  return new ComputedProperties(
    append(argument.properties, target2.properties),
    append(argument.medias, target2.medias),
    append(argument.pseudo_selectors, target2.pseudo_selectors),
    target2.indent
  );
}
function handle_property(props, style3) {
  if (!(style3 instanceof Property)) {
    throw makeError(
      "let_assert",
      "sketch/internals/style",
      133,
      "handle_property",
      "Pattern match failed, no pattern matched the value.",
      { value: style3 }
    );
  }
  let key2 = style3.key;
  let value2 = style3.value;
  let important = style3.important;
  let css_property = compute_property(props.indent, key2, value2, important);
  let properties = prepend(css_property, props.properties);
  return props.withFields({ properties });
}
function wrap_pseudo_selectors(id, indent2, pseudo_selectors) {
  return map2(
    pseudo_selectors,
    (p) => {
      return wrap_class(
        id,
        p.properties,
        indent2,
        new Some(p.pseudo_selector)
      );
    }
  );
}
function compute_classes(class_name4, computed_properties) {
  let properties = computed_properties.properties;
  let medias = computed_properties.medias;
  let pseudo_selectors = computed_properties.pseudo_selectors;
  let class_def = wrap_class(
    class_name4,
    properties,
    0,
    new None()
  );
  let medias_def = map2(
    medias,
    (_use0) => {
      let query = _use0.query;
      let properties$1 = _use0.properties;
      let pseudo_selectors$1 = _use0.pseudo_selectors;
      let selectors_def2 = wrap_pseudo_selectors(
        class_name4,
        2,
        pseudo_selectors$1
      );
      let _pipe = toList([
        query + " {",
        wrap_class(class_name4, properties$1, 2, new None())
      ]);
      let _pipe$1 = ((_capture) => {
        return prepend2(toList([selectors_def2, toList(["}"])]), _capture);
      })(_pipe);
      let _pipe$2 = concat(_pipe$1);
      return join2(_pipe$2, "\n");
    }
  );
  let selectors_def = wrap_pseudo_selectors(class_name4, 0, pseudo_selectors);
  let name = class_name4;
  return new ComputedClass(class_def, medias_def, selectors_def, name);
}
function class$2(styles) {
  let string_representation = inspect2(styles);
  return new Class(string_representation, styles);
}
function render_cache_dict(cache2) {
  let _pipe = values(cache2);
  let _pipe$1 = flat_map(
    _pipe,
    (c) => {
      return definitions(c[0]);
    }
  );
  return join2(_pipe$1, "\n\n");
}
function render(cache2) {
  if (cache2 instanceof EphemeralCache) {
    let cache$1 = cache2.cache;
    return render_cache_dict(cache$1);
  } else {
    let cache$1 = cache2.cache;
    return render_cache_dict(cache$1);
  }
}
function handle_media(cache2, props, style3) {
  if (!(style3 instanceof Media)) {
    throw makeError(
      "let_assert",
      "sketch/internals/style",
      140,
      "handle_media",
      "Pattern match failed, no pattern matched the value.",
      { value: style3 }
    );
  }
  let query = style3.query;
  let styles = style3.styles;
  let $ = compute_properties(cache2, styles, props.indent + 2);
  let cache$1 = $[0];
  let computed_props = $[1];
  let _pipe = new MediaProperty(
    query,
    computed_props.properties,
    computed_props.pseudo_selectors
  );
  let _pipe$1 = ((_capture) => {
    return prepend2(props.medias, _capture);
  })(
    _pipe
  );
  let _pipe$2 = ((m) => {
    return props.withFields({ medias: m });
  })(_pipe$1);
  return ((_capture) => {
    return new$(cache$1, _capture);
  })(_pipe$2);
}
function compute_properties(cache2, properties, indent2) {
  let init3 = init_computed_properties(indent2);
  return fold(
    reverse(properties),
    [cache2, init3],
    (_use0, prop) => {
      let cache$1 = _use0[0];
      let acc = _use0[1];
      if (prop instanceof NoStyle) {
        return [cache$1, acc];
      } else if (prop instanceof Property) {
        return [cache$1, handle_property(acc, prop)];
      } else if (prop instanceof Media) {
        return handle_media(cache$1, acc, prop);
      } else if (prop instanceof PseudoSelector) {
        return handle_pseudo_selector(cache$1, acc, prop);
      } else {
        let class$1 = prop.class_name;
        let $ = get(cache$1.cache, class$1.string_representation);
        if ($.isOk()) {
          let props = $[0][1];
          return [cache$1, merge_computed_properties(acc, props)];
        } else {
          let _pipe = compute_properties(cache$1, class$1.content, indent2);
          return map_second(
            _pipe,
            (_capture) => {
              return merge_computed_properties(acc, _capture);
            }
          );
        }
      }
    }
  );
}
function handle_pseudo_selector(cache2, props, style3) {
  if (!(style3 instanceof PseudoSelector)) {
    throw makeError(
      "let_assert",
      "sketch/internals/style",
      154,
      "handle_pseudo_selector",
      "Pattern match failed, no pattern matched the value.",
      { value: style3 }
    );
  }
  let pseudo_selector = style3.pseudo_selector;
  let styles = style3.styles;
  let $ = compute_properties(cache2, styles, props.indent + 2);
  let cache$1 = $[0];
  let computed_props = $[1];
  let _pipe = new PseudoProperty(pseudo_selector, computed_props.properties);
  let _pipe$1 = ((_capture) => {
    return prepend2(computed_props.pseudo_selectors, _capture);
  })(_pipe);
  let _pipe$2 = append(_pipe$1, props.pseudo_selectors);
  let _pipe$3 = ((p) => {
    return props.withFields({ pseudo_selectors: p });
  })(
    _pipe$2
  );
  return ((_capture) => {
    return new$(cache$1, _capture);
  })(_pipe$3);
}
function compute_class(cache2, class$4) {
  let string_representation = class$4.string_representation;
  let content = class$4.content;
  let $ = compute_properties(cache2, content, 2);
  let cache$1 = $[0];
  let properties = $[1];
  let class_id = (() => {
    if (cache$1 instanceof EphemeralCache) {
      return xxHash32(string_representation);
    } else {
      let cid = cache$1.current_id;
      return cid;
    }
  })();
  let class_name$1 = "css-" + to_string3(class_id);
  let _pipe = compute_classes(class_name$1, properties);
  let _pipe$1 = ((c) => {
    return create(
      c.name,
      class_id,
      new None(),
      new Definitions(c.medias_def, c.selectors_def, c.class_def)
    );
  })(_pipe);
  return ((class$5) => {
    let c = insert(
      cache$1.cache,
      string_representation,
      [class$5, properties]
    );
    let _pipe$2 = (() => {
      if (cache$1 instanceof EphemeralCache) {
        return new EphemeralCache(c);
      } else {
        return new PersistentCache(c, class_id + 1);
      }
    })();
    return new$(_pipe$2, class$5);
  })(_pipe$1);
}
function class_name2(class$4, cache2) {
  let s = class$4.string_representation;
  let c = class$4.content;
  return guard(
    is_empty(c),
    [cache2, ""],
    () => {
      let $ = get(cache2.cache, s);
      if ($.isOk()) {
        let content = $[0][0];
        return [cache2, class_name(content)];
      } else {
        let _pipe = compute_class(cache2, class$4);
        return map_second(_pipe, class_name);
      }
    }
  );
}

// build/dev/javascript/sketch/sketch/size.mjs
var Px = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Pt = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Vh = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Vw = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Em = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Rem = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Lh = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Rlh = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Pct = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
function percent(value2) {
  return new Pct(to_float(value2));
}
function vh(value2) {
  return new Vh(to_float(value2));
}
function to_string6(size) {
  if (size instanceof Px) {
    let value2 = size[0];
    return append3(to_string(value2), "px");
  } else if (size instanceof Pt) {
    let value2 = size[0];
    return append3(to_string(value2), "pt");
  } else if (size instanceof Pct) {
    let value2 = size[0];
    return append3(to_string(value2), "%");
  } else if (size instanceof Vh) {
    let value2 = size[0];
    return append3(to_string(value2), "vh");
  } else if (size instanceof Vw) {
    let value2 = size[0];
    return append3(to_string(value2), "vw");
  } else if (size instanceof Em) {
    let value2 = size[0];
    return append3(to_string(value2), "em");
  } else if (size instanceof Rem) {
    let value2 = size[0];
    return append3(to_string(value2), "rem");
  } else if (size instanceof Lh) {
    let value2 = size[0];
    return append3(to_string(value2), "lh");
  } else if (size instanceof Rlh) {
    let value2 = size[0];
    return append3(to_string(value2), "rlh");
  } else {
    let value2 = size[0];
    return append3(to_string(value2), "ch");
  }
}

// build/dev/javascript/sketch/sketch.mjs
var JsCache = class extends CustomType {
  constructor(cache2) {
    super();
    this.cache = cache2;
  }
};
var Ephemeral = class extends CustomType {
};
function class$3(styles) {
  return class$2(styles);
}
function render2(cache2) {
  if (!(cache2 instanceof JsCache)) {
    throw makeError(
      "let_assert",
      "sketch",
      38,
      "render",
      "Pattern match failed, no pattern matched the value.",
      { value: cache2 }
    );
  }
  let cache$1 = cache2.cache;
  return render(cache$1);
}
function class_name3(class$4, cache2) {
  if (!(cache2 instanceof JsCache)) {
    throw makeError(
      "let_assert",
      "sketch",
      53,
      "class_name",
      "Pattern match failed, no pattern matched the value.",
      { value: cache2 }
    );
  }
  let c = cache2.cache;
  let _pipe = class_name2(class$4, c);
  return map_first(_pipe, (var0) => {
    return new JsCache(var0);
  });
}
function cache(strategy) {
  return new Ok(
    (() => {
      if (strategy instanceof Ephemeral) {
        return new JsCache(ephemeral());
      } else {
        return new JsCache(persistent());
      }
    })()
  );
}
function property(field2, content) {
  return new Property(field2, content, false);
}
function aspect_ratio(aspect_ratio2) {
  return property("aspect-ratio", aspect_ratio2);
}
function background(background2) {
  return property("background", background2);
}
function background_color(value2) {
  return property("background-color", value2);
}
function border(border2) {
  return property("border", border2);
}
function border_bottom(value2) {
  return property("border-bottom", value2);
}
function border_color(value2) {
  return property("border-color", value2);
}
function border_right(value2) {
  return property("border-right", value2);
}
function border_style(value2) {
  return property("border-style", value2);
}
function box_shadow(box_shadow2) {
  return property("box-shadow", box_shadow2);
}
function color(color2) {
  return property("color", color2);
}
function column_gap(column_gap2) {
  return property("column-gap", to_string6(column_gap2));
}
function display(display2) {
  return property("display", display2);
}
function font_family(font_family2) {
  return property("font-family", font_family2);
}
function font_size(font_size2) {
  return property("font-size", to_string6(font_size2));
}
function font_weight(font_weight2) {
  return property("font-weight", font_weight2);
}
function grid_column(grid_column2) {
  return property("grid-column", grid_column2);
}
function grid_row(grid_row2) {
  return property("grid-row", grid_row2);
}
function height(height2) {
  return property("height", to_string6(height2));
}
function max_width(width) {
  return property("max-width", to_string6(width));
}
function padding(padding2) {
  return property("padding", to_string6(padding2));
}
function text_align(text_align2) {
  return property("text-align", text_align2);
}
function transform(transform2) {
  return property("transform", transform2);
}
function user_select(user_select2) {
  return property("user-select", user_select2);
}
function compose(class$4) {
  return new ClassName(class$4);
}

// build/dev/javascript/sketch_lustre/sketch_lustre.ffi.mjs
function wrap(current) {
  if (isPersistent(current))
    return { current };
  return current;
}
function set(variable, newValue) {
  if (!("current" in variable))
    return newValue;
  variable.current = newValue;
  return variable;
}
function get2(variable) {
  if ("current" in variable)
    return variable.current;
  return variable;
}
function isPersistent(cache2) {
  return "cache" in cache2 && "current_id" in cache2.cache;
}
function createCssStyleSheet(root) {
  const stylesheet = new CSSStyleSheet();
  if (root && root.adoptedStyleSheets) {
    root.adoptedStyleSheets.push(stylesheet);
  } else {
    document.adoptedStyleSheets.push(stylesheet);
  }
  return stylesheet;
}
function setStylesheet(content, stylesheet) {
  stylesheet.replaceSync(content);
}

// build/dev/javascript/sketch_lustre/sketch/lustre/element.mjs
var Nothing = class extends CustomType {
};
var Text2 = class extends CustomType {
  constructor(content) {
    super();
    this.content = content;
  }
};
var Map3 = class extends CustomType {
  constructor(subtree) {
    super();
    this.subtree = subtree;
  }
};
var Element3 = class extends CustomType {
  constructor(key2, namespace, tag, class$4, attributes, children2) {
    super();
    this.key = key2;
    this.namespace = namespace;
    this.tag = tag;
    this.class = class$4;
    this.attributes = attributes;
    this.children = children2;
  }
};
function text2(content) {
  return new Text2(content);
}
function element2(tag, class$4, attributes, children2) {
  let class$1 = new Some(class$4);
  return new Element3("", "", tag, class$1, attributes, children2);
}
function unstyled_children(cache2, children2) {
  return fold(
    reverse(children2),
    [cache2, toList([])],
    (acc, child) => {
      let cache$1 = acc[0];
      let children$1 = acc[1];
      let $ = unstyled(cache$1, child);
      let cache$2 = $[0];
      let child$1 = $[1];
      return [cache$2, prepend(child$1, children$1)];
    }
  );
}
function unstyled(loop$cache, loop$element) {
  while (true) {
    let cache2 = loop$cache;
    let element3 = loop$element;
    if (element3 instanceof Nothing) {
      return [cache2, none2()];
    } else if (element3 instanceof Text2) {
      let content = element3.content;
      return [cache2, text(content)];
    } else if (element3 instanceof Map3) {
      let subtree = element3.subtree;
      loop$cache = cache2;
      loop$element = subtree();
    } else {
      let key2 = element3.key;
      let namespace = element3.namespace;
      let tag = element3.tag;
      let class$4 = element3.class;
      let attributes = element3.attributes;
      let children2 = element3.children;
      let class$1 = map(
        class$4,
        (_capture) => {
          return class_name3(_capture, cache2);
        }
      );
      let class_name4 = map(class$1, second);
      let cache$1 = (() => {
        let _pipe = map(class$1, first);
        return unwrap(_pipe, cache2);
      })();
      let $ = unstyled_children(cache$1, children2);
      let cache$2 = $[0];
      let children$1 = $[1];
      let attributes$1 = (() => {
        if (class_name4 instanceof None) {
          return attributes;
        } else {
          let class_name$1 = class_name4[0];
          let class_name$2 = class$(class_name$1);
          return prepend(class_name$2, attributes);
        }
      })();
      return [
        cache$2,
        (() => {
          let $1 = element(tag, attributes$1, children$1);
          if ($1 instanceof Element2) {
            let t = $1.tag;
            let a = $1.attrs;
            let c = $1.children;
            let s = $1.self_closing;
            let v = $1.void;
            return new Element2(key2, namespace, t, a, c, s, v);
          } else {
            let e = $1;
            return e;
          }
        })()
      ];
    }
  }
}

// build/dev/javascript/sketch_lustre/sketch/lustre.mjs
var Node2 = class extends CustomType {
};
var Document = class extends CustomType {
};
var Options = class extends CustomType {
  constructor(stylesheet) {
    super();
    this.stylesheet = stylesheet;
  }
};
var CssStyleSheet = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var NodeStyleSheet = class extends CustomType {
};
function to_stylesheet(options) {
  if (options instanceof Options && options.stylesheet instanceof Node2) {
    return new NodeStyleSheet();
  } else if (options instanceof Options && options.stylesheet instanceof Document) {
    return new CssStyleSheet(createCssStyleSheet());
  } else {
    let root = options.stylesheet.root;
    return new CssStyleSheet(createCssStyleSheet(root));
  }
}
function render_stylesheet(content, node2, stylesheet) {
  if (stylesheet instanceof NodeStyleSheet) {
    if (node2 instanceof Element2 && node2.tag === "lustre-fragment") {
      let children2 = node2.children;
      return fragment(
        prepend(
          element("style", toList([]), toList([text(content)])),
          children2
        )
      );
    } else {
      return fragment(
        toList([
          element("style", toList([]), toList([text(content)])),
          node2
        ])
      );
    }
  } else {
    let stylesheet$1 = stylesheet[0];
    setStylesheet(content, stylesheet$1);
    return node2;
  }
}
function compose2(options, view2, cache2) {
  let cache$1 = wrap(cache2);
  let stylesheet = to_stylesheet(options);
  return (model) => {
    let node$1 = view2(model);
    let $ = unstyled(get2(cache$1), node$1);
    let result = $[0];
    let node$2 = $[1];
    let content = render2(result);
    set(cache$1, result);
    return render_stylesheet(content, node$2, stylesheet);
  };
}
function node() {
  return new Options(new Node2());
}

// build/dev/javascript/sketch_lustre/sketch/lustre/element/html.mjs
function div(class$4, attributes, children2) {
  return element2("div", class$4, attributes, children2);
}

// build/dev/javascript/app/game.mjs
var Coins = class extends CustomType {
};
var Swords = class extends CustomType {
};
var Clubs = class extends CustomType {
};
var Cups = class extends CustomType {
};
var MajorArcana = class extends CustomType {
  constructor(value2) {
    super();
    this.value = value2;
  }
};
var MinorArcana = class extends CustomType {
  constructor(suit, value2) {
    super();
    this.suit = suit;
    this.value = value2;
  }
};
var MajorArcanaFoundation = class extends CustomType {
  constructor(low, high) {
    super();
    this.low = low;
    this.high = high;
  }
};
var MinorArcanaFoundation = class extends CustomType {
  constructor(coins, swords, clubs, cups, blocking) {
    super();
    this.coins = coins;
    this.swords = swords;
    this.clubs = clubs;
    this.cups = cups;
    this.blocking = blocking;
  }
};
var GameState = class extends CustomType {
  constructor(major_arcana_foundation, minor_arcana_foundation, columns, previous_state) {
    super();
    this.major_arcana_foundation = major_arcana_foundation;
    this.minor_arcana_foundation = minor_arcana_foundation;
    this.columns = columns;
    this.previous_state = previous_state;
  }
};
var Column = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var BlockingMinorArcanaFoundation = class extends CustomType {
};
var Move = class extends CustomType {
  constructor(source, target2) {
    super();
    this.source = source;
    this.target = target2;
  }
};
function generate_all_cards() {
  let major_arcana = (() => {
    let _pipe = range(0, 21);
    return map2(_pipe, (var0) => {
      return new MajorArcana(var0);
    });
  })();
  let minor_arcana = flat_map(
    toList([new Coins(), new Swords(), new Clubs(), new Cups()]),
    (suit) => {
      let _pipe = range(2, 13);
      return map2(
        _pipe,
        (_capture) => {
          return new MinorArcana(suit, _capture);
        }
      );
    }
  );
  return append(major_arcana, minor_arcana);
}
function generate_columns() {
  let columns = (() => {
    let _pipe2 = generate_all_cards();
    let _pipe$12 = shuffle(_pipe2);
    return sized_chunk(_pipe$12, 7);
  })();
  let left_columns = (() => {
    let _pipe2 = columns;
    return take(_pipe2, 5);
  })();
  let right_columns = (() => {
    let _pipe2 = columns;
    return drop(_pipe2, 5);
  })();
  let all_columns = append(
    left_columns,
    prepend(toList([]), right_columns)
  );
  let _pipe = all_columns;
  let _pipe$1 = index_map(
    _pipe,
    (column, index3) => {
      return [index3, column];
    }
  );
  return from_list(_pipe$1);
}
function minor_arcana_foundation_cards(foundation) {
  return toList([
    new MinorArcana(new Clubs(), foundation.clubs),
    new MinorArcana(new Coins(), foundation.coins),
    new MinorArcana(new Cups(), foundation.cups),
    new MinorArcana(new Swords(), foundation.swords)
  ]);
}
function are_adjacent(n1, n2) {
  return absolute_value(n1 - n2) === 1;
}
function are_stackable(c1, c2) {
  if (c1 instanceof MajorArcana && c2 instanceof MajorArcana) {
    let v1 = c1.value;
    let v2 = c2.value;
    return are_adjacent(v1, v2);
  } else if (c1 instanceof MinorArcana && c2 instanceof MinorArcana) {
    let s1 = c1.suit;
    let v1 = c1.value;
    let s2 = c2.suit;
    let v2 = c2.value;
    return isEqual(s1, s2) && are_adjacent(v1, v2);
  } else {
    return false;
  }
}
function can_stack(selected, column) {
  if (column.hasLength(0)) {
    return true;
  } else {
    let topmost = column.head;
    return are_stackable(selected, topmost);
  }
}
function get_column(state, index3) {
  let $ = get(state.columns, index3);
  if (!$.isOk()) {
    throw makeError(
      "let_assert",
      "game",
      132,
      "get_column",
      "Pattern match failed, no pattern matched the value.",
      { value: $ }
    );
  }
  let column = $[0];
  return column;
}
function get_card(state, loc) {
  if (loc instanceof BlockingMinorArcanaFoundation) {
    let _pipe = state.minor_arcana_foundation.blocking;
    return to_result(_pipe, void 0);
  } else {
    let index3 = loc[0];
    let _pipe = get_column(state, index3);
    return first2(_pipe);
  }
}
function with_blocking_card(state, card) {
  return state.withFields({
    minor_arcana_foundation: state.minor_arcana_foundation.withFields({
      blocking: card
    })
  });
}
function with_updated_column(state, index3, func) {
  return state.withFields({
    columns: insert(
      state.columns,
      index3,
      (() => {
        let _pipe = get_column(state, index3);
        return func(_pipe);
      })()
    )
  });
}
function remove_card(state, loc) {
  if (loc instanceof BlockingMinorArcanaFoundation) {
    let _pipe = state;
    return with_blocking_card(_pipe, new None());
  } else {
    let index3 = loc[0];
    let _pipe = state;
    return with_updated_column(
      _pipe,
      index3,
      (_capture) => {
        return drop(_capture, 1);
      }
    );
  }
}
function pop_card(state, loc) {
  return map3(
    get_card(state, loc),
    (card) => {
      let new_state = remove_card(state, loc);
      return [card, new_state];
    }
  );
}
function put_card(state, card, loc) {
  if (loc instanceof BlockingMinorArcanaFoundation) {
    let _pipe = state;
    return with_blocking_card(_pipe, new Some(card));
  } else {
    let index3 = loc[0];
    let _pipe = state;
    return with_updated_column(
      _pipe,
      index3,
      (_capture) => {
        return prepend2(_capture, card);
      }
    );
  }
}
function is_valid(state, move) {
  return guard(
    isEqual(move.source, move.target),
    false,
    () => {
      let selected = get_card(state, move.source);
      let $ = move.target;
      if (!selected.isOk() && !selected[0]) {
        return false;
      } else if ($ instanceof BlockingMinorArcanaFoundation) {
        let _pipe = state.minor_arcana_foundation.blocking;
        return is_none(_pipe);
      } else {
        let card = selected[0];
        let index3 = $[0];
        let column = get_column(state, index3);
        return can_stack(card, column);
      }
    }
  );
}
function next_low_major_arcana(state) {
  let _pipe = state.major_arcana_foundation.low;
  let _pipe$1 = map(
    _pipe,
    (_capture) => {
      return add(_capture, 1);
    }
  );
  return unwrap(_pipe$1, 0);
}
function next_high_major_arcana(state) {
  let _pipe = state.major_arcana_foundation.high;
  let _pipe$1 = map(
    _pipe,
    (_capture) => {
      return subtract(_capture, 1);
    }
  );
  return unwrap(_pipe$1, 21);
}
function next_minor_arcana(state, suit) {
  if (suit instanceof Coins) {
    return state.minor_arcana_foundation.coins + 1;
  } else if (suit instanceof Swords) {
    return state.minor_arcana_foundation.swords + 1;
  } else if (suit instanceof Clubs) {
    return state.minor_arcana_foundation.clubs + 1;
  } else {
    return state.minor_arcana_foundation.cups + 1;
  }
}
function is_ready_for_foundation(state, card) {
  if (card instanceof MajorArcana) {
    let value2 = card.value;
    let expected_low = next_low_major_arcana(state);
    let expected_high = next_high_major_arcana(state);
    return value2 === expected_low || value2 === expected_high;
  } else {
    let suit = card.suit;
    let value2 = card.value;
    return value2 === next_minor_arcana(state, suit);
  }
}
function find_ready_for_foundation(state) {
  let locations = prepend(
    new BlockingMinorArcanaFoundation(),
    (() => {
      let _pipe = state.columns;
      let _pipe$1 = keys(_pipe);
      return map2(_pipe$1, (var0) => {
        return new Column(var0);
      });
    })()
  );
  let minor_arcana_blocked = (() => {
    let _pipe = state.minor_arcana_foundation.blocking;
    return is_some(_pipe);
  })();
  return find_map(
    locations,
    (loc) => {
      return try$(
        get_card(state, loc),
        (card) => {
          if (card instanceof MinorArcana && minor_arcana_blocked) {
            return new Error(void 0);
          } else {
            let $ = is_ready_for_foundation(state, card);
            if ($) {
              return new Ok(loc);
            } else {
              return new Error(void 0);
            }
          }
        }
      );
    }
  );
}
function new_game() {
  while (true) {
    let state = new GameState(
      new MajorArcanaFoundation(new None(), new None()),
      new MinorArcanaFoundation(1, 1, 1, 1, new None()),
      generate_columns(),
      new None()
    );
    let $ = find_ready_for_foundation(state);
    if ($.isOk()) {
    } else {
      return state;
    }
  }
}
function with_added_to_foundation(state, card) {
  if (card instanceof MajorArcana) {
    let value2 = card.value;
    let expected_low = next_low_major_arcana(state);
    let expected_high = next_high_major_arcana(state);
    let current = state.major_arcana_foundation;
    let new$5 = (() => {
      if (value2 === expected_low) {
        return current.withFields({ low: new Some(value2) });
      } else if (value2 === expected_high) {
        return current.withFields({ high: new Some(value2) });
      } else {
        throw makeError(
          "panic",
          "game",
          280,
          "with_added_to_foundation",
          "`panic` expression evaluated.",
          {}
        );
      }
    })();
    return state.withFields({ major_arcana_foundation: new$5 });
  } else {
    let suit = card.suit;
    let value2 = card.value;
    let current = state.minor_arcana_foundation;
    let new$5 = (() => {
      if (suit instanceof Coins) {
        return current.withFields({ coins: value2 });
      } else if (suit instanceof Swords) {
        return current.withFields({ swords: value2 });
      } else if (suit instanceof Clubs) {
        return current.withFields({ clubs: value2 });
      } else {
        return current.withFields({ cups: value2 });
      }
    })();
    return state.withFields({ minor_arcana_foundation: new$5 });
  }
}
function apply_colaterals(loop$state) {
  while (true) {
    let state = loop$state;
    let $ = find_ready_for_foundation(state);
    if ($.isOk()) {
      let location = $[0];
      let $1 = pop_card(state, location);
      if (!$1.isOk()) {
        throw makeError(
          "let_assert",
          "game",
          301,
          "apply_colaterals",
          "Pattern match failed, no pattern matched the value.",
          { value: $1 }
        );
      }
      let card = $1[0][0];
      let state_without_card = $1[0][1];
      let new_state = (() => {
        let _pipe = state_without_card;
        return with_added_to_foundation(_pipe, card);
      })();
      loop$state = new_state;
    } else {
      return state;
    }
  }
}
function try_make_move(loop$state, loop$move) {
  while (true) {
    let state = loop$state;
    let move = loop$move;
    let $ = is_valid(state, move);
    if ($) {
      let $1 = pop_card(state, move.source);
      if (!$1.isOk()) {
        throw makeError(
          "let_assert",
          "game",
          312,
          "try_make_move",
          "Pattern match failed, no pattern matched the value.",
          { value: $1 }
        );
      }
      let selected = $1[0][0];
      let state$1 = $1[0][1];
      let _pipe = state$1;
      let _pipe$1 = put_card(_pipe, selected, move.target);
      loop$state = _pipe$1;
      loop$move = move;
    } else {
      return apply_colaterals(state);
    }
  }
}

// build/dev/javascript/app/styles.mjs
var Horizontal = class extends CustomType {
};
var Vertical = class extends CustomType {
};
var GridRow = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var GridColumn = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
function composed(classes) {
  let _pipe = classes;
  let _pipe$1 = map2(_pipe, compose);
  return class$3(_pipe$1);
}
function background_class() {
  return class$3(
    toList([
      background("#302017"),
      user_select("none"),
      height(vh(100)),
      padding(percent(2))
    ])
  );
}
function grid_row_from_index(index3, total) {
  return new GridRow(total - index3);
}
function grid_column_from_index(index3) {
  return new GridColumn(index3 + 1);
}
function grid_container_class(col_gap) {
  return class$3(toList([display("grid"), column_gap(col_gap)]));
}
function major_arcana_foundation_class() {
  return grid_container_class(vh(3));
}
function minor_arcana_foundation_class() {
  return grid_container_class(vh(3));
}
function tableau_class() {
  return grid_container_class(vh(3));
}
function grid_element_class(row, col, direction, is_topmost) {
  let row$1 = row[0];
  let col$1 = col[0];
  let $ = (() => {
    if (!is_topmost && direction instanceof Vertical) {
      return [aspect_ratio("160 / 40"), border_bottom("none"), 1];
    } else if (!is_topmost && direction instanceof Horizontal) {
      return [aspect_ratio("25 / 280"), border_right("none"), 1];
    } else {
      return [aspect_ratio("160 / 280"), border("solid"), 7];
    }
  })();
  let aspect_ratio2 = $[0];
  let border_overlap_style = $[1];
  let row_span = $[2];
  return class$3(
    toList([
      grid_row(
        to_string3(row$1) + "/ span " + to_string3(row_span)
      ),
      grid_column(to_string3(col$1)),
      aspect_ratio2,
      border_overlap_style
    ])
  );
}
function card_class() {
  return class$3(
    toList([
      border_style("solid"),
      padding(percent(3)),
      font_family("sans"),
      font_size(percent(140)),
      font_weight("bold")
    ])
  );
}
function major_arcana_class() {
  let color2 = "#eea96b";
  return class$3(
    toList([
      background_color("#282523"),
      border_color(color2),
      color(color2),
      text_align("center")
    ])
  );
}
function suit_color(suit) {
  if (suit instanceof Clubs) {
    return "#497327";
  } else if (suit instanceof Coins) {
    return "#956f3f";
  } else if (suit instanceof Cups) {
    return "#963728";
  } else {
    return "#326973";
  }
}
function minor_arcana_class(suit) {
  let color2 = suit_color(suit);
  return class$3(
    toList([
      background_color("#f8e3c1"),
      border_color(color2),
      color(color2),
      text_align("left")
    ])
  );
}
function suit_icon(suit) {
  if (suit instanceof Clubs) {
    return "\u{1F33F}";
  } else if (suit instanceof Coins) {
    return "\u{1FA99}";
  } else if (suit instanceof Cups) {
    return "\u{1F377}";
  } else {
    return "\u2694\uFE0F";
  }
}
function selected_class() {
  return class$3(
    toList([
      transform("scale(1.1)"),
      box_shadow("5px -5px 7px 7px rgba(0, 0, 0, 0.2);")
    ])
  );
}
function empty_slot_class() {
  return class$3(toList([border("solid"), border_color("#946e3e")]));
}

// build/dev/javascript/app/app.mjs
var Model2 = class extends CustomType {
  constructor(game_state, selected) {
    super();
    this.game_state = game_state;
    this.selected = selected;
  }
};
var UserSelectedCard = class extends CustomType {
  constructor(location) {
    super();
    this.location = location;
  }
};
var UserClickedEmptySlot = class extends CustomType {
  constructor(location) {
    super();
    this.location = location;
  }
};
var UserClickedMinorArcanaFoundation = class extends CustomType {
};
function init2(_) {
  return new Model2(new_game(), new None());
}
function select(model, location) {
  return model.withFields({ selected: new Some(location) });
}
function deselect(model) {
  return model.withFields({ selected: new None() });
}
function try_make_move2(model, move) {
  return model.withFields({
    game_state: try_make_move(model.game_state, move)
  });
}
function update(model, msg) {
  let $ = model.selected;
  if ($ instanceof None) {
    if (msg instanceof UserSelectedCard) {
      let location = msg.location;
      let _pipe = model;
      return select(_pipe, location);
    } else if (msg instanceof UserClickedEmptySlot) {
      return model;
    } else {
      let $1 = model.game_state.minor_arcana_foundation.blocking;
      if ($1 instanceof Some) {
        let _pipe = model;
        return select(_pipe, new BlockingMinorArcanaFoundation());
      } else {
        return model;
      }
    }
  } else {
    let already_selected = $[0];
    if (msg instanceof UserSelectedCard) {
      let new_location = msg.location;
      let _pipe = model;
      let _pipe$1 = try_make_move2(
        _pipe,
        new Move(already_selected, new_location)
      );
      return deselect(_pipe$1);
    } else if (msg instanceof UserClickedEmptySlot) {
      let new_location = msg.location;
      let _pipe = model;
      let _pipe$1 = try_make_move2(
        _pipe,
        new Move(already_selected, new_location)
      );
      return deselect(_pipe$1);
    } else {
      let _pipe = model;
      let _pipe$1 = try_make_move2(
        _pipe,
        new Move(already_selected, new BlockingMinorArcanaFoundation())
      );
      return deselect(_pipe$1);
    }
  }
}
function view_empty_slot(column_index) {
  return div(
    composed(
      toList([
        grid_element_class(
          grid_row_from_index(0, 1),
          grid_column_from_index(column_index),
          new Vertical(),
          true
        ),
        empty_slot_class()
      ])
    ),
    toList([on_click(new UserSelectedCard(new Column(column_index)))]),
    toList([])
  );
}
function card_text(card) {
  if (card instanceof MajorArcana) {
    let value2 = card.value;
    let _pipe = value2;
    return to_string3(_pipe);
  } else {
    let suit = card.suit;
    let value2 = card.value;
    return (() => {
      if (value2 === 1) {
        return "A";
      } else if (value2 === 11) {
        return "J";
      } else if (value2 === 12) {
        return "Q";
      } else if (value2 === 13) {
        return "K";
      } else {
        let _pipe = value2;
        return to_string3(_pipe);
      }
    })() + suit_icon(suit);
  }
}
function view_card(card, row, col, direction, is_topmost, is_selected, if_selected) {
  let arcana_class = (() => {
    if (card instanceof MajorArcana) {
      return major_arcana_class();
    } else {
      let suit = card.suit;
      return minor_arcana_class(suit);
    }
  })();
  let grid_element_class2 = grid_element_class(
    row,
    col,
    direction,
    is_topmost
  );
  let base_class = composed(
    toList([card_class(), arcana_class, grid_element_class2])
  );
  let class$4 = (() => {
    let $ = is_selected && is_topmost;
    if ($) {
      return composed(toList([base_class, selected_class()]));
    } else {
      return base_class;
    }
  })();
  let attributes = (() => {
    if (!is_topmost) {
      return toList([]);
    } else {
      return toList([on_click(if_selected)]);
    }
  })();
  return div(class$4, attributes, toList([text2(card_text(card))]));
}
function view_major_arcana_foundation(foundation) {
  let empty = (col) => {
    return div(
      composed(
        toList([
          grid_element_class(
            grid_row_from_index(0, 1),
            col,
            new Horizontal(),
            true
          ),
          empty_slot_class()
        ])
      ),
      toList([]),
      toList([])
    );
  };
  let low_cards = (() => {
    let $ = foundation.low;
    if ($ instanceof None) {
      return toList([empty(grid_column_from_index(0))]);
    } else {
      let max_low_value = $[0];
      let _pipe = range(0, max_low_value);
      return map2(
        _pipe,
        (value2) => {
          return view_card(
            new MajorArcana(value2),
            new GridRow(1),
            grid_column_from_index(value2),
            new Horizontal(),
            value2 === max_low_value,
            false,
            new UserClickedMinorArcanaFoundation()
          );
        }
      );
    }
  })();
  let high_cards = (() => {
    let $ = foundation.high;
    if ($ instanceof None) {
      return toList([empty(grid_column_from_index(21))]);
    } else {
      let min_high_value = $[0];
      let _pipe = range(21, min_high_value);
      return map2(
        _pipe,
        (value2) => {
          return view_card(
            new MajorArcana(value2),
            new GridRow(1),
            grid_column_from_index(value2),
            new Horizontal(),
            value2 === min_high_value,
            false,
            new UserClickedMinorArcanaFoundation()
          );
        }
      );
    }
  })();
  return div(
    composed(toList([major_arcana_foundation_class()])),
    toList([]),
    flatten(toList([low_cards, high_cards]))
  );
}
function view_minor_arcana_foundation(foundation) {
  let cards = (() => {
    let $ = foundation.blocking;
    if ($ instanceof Some) {
      let card = $[0];
      return toList([
        view_card(
          card,
          new GridRow(1),
          new GridColumn(1),
          new Horizontal(),
          true,
          false,
          new UserClickedMinorArcanaFoundation()
        )
      ]);
    } else {
      let _pipe = foundation;
      let _pipe$1 = minor_arcana_foundation_cards(_pipe);
      return index_map(
        _pipe$1,
        (card, index3) => {
          return view_card(
            card,
            new GridRow(1),
            grid_column_from_index(index3),
            new Horizontal(),
            true,
            false,
            new UserClickedMinorArcanaFoundation()
          );
        }
      );
    }
  })();
  return div(
    composed(
      toList([
        class$3(toList([max_width(percent(25))])),
        minor_arcana_foundation_class()
      ])
    ),
    toList([]),
    cards
  );
}
function view_card_column(cards, column_index, is_selected) {
  if (cards.hasLength(0)) {
    return toList([view_empty_slot(column_index)]);
  } else {
    return index_map(
      cards,
      (card, index3) => {
        let is_topmost = index3 === 0;
        return view_card(
          card,
          grid_row_from_index(index3, length(cards)),
          grid_column_from_index(column_index),
          new Vertical(),
          is_topmost,
          is_selected,
          new UserSelectedCard(new Column(column_index))
        );
      }
    );
  }
}
function view_tableau(game_state, selected) {
  let cards = (() => {
    let _pipe = game_state.columns;
    let _pipe$1 = map_to_list(_pipe);
    return flat_map(
      _pipe$1,
      (indexed_column) => {
        let column_index = indexed_column[0];
        let cards2 = indexed_column[1];
        return view_card_column(
          cards2,
          column_index,
          isEqual(selected, new Some(new Column(column_index)))
        );
      }
    );
  })();
  return div(tableau_class(), toList([]), cards);
}
function view(model) {
  return div(
    background_class(),
    toList([]),
    toList([
      view_major_arcana_foundation(model.game_state.major_arcana_foundation),
      view_minor_arcana_foundation(model.game_state.minor_arcana_foundation),
      view_tableau(model.game_state, model.selected)
    ])
  );
}
function main() {
  let $ = cache(new Ephemeral());
  if (!$.isOk()) {
    throw makeError(
      "let_assert",
      "app",
      18,
      "main",
      "Pattern match failed, no pattern matched the value.",
      { value: $ }
    );
  }
  let cache$1 = $[0];
  let _pipe = node();
  let _pipe$1 = compose2(_pipe, view, cache$1);
  let _pipe$2 = ((_capture) => {
    return simple(init2, update, _capture);
  })(
    _pipe$1
  );
  return start2(_pipe$2, "#app", void 0);
}

// build/.lustre/entry.mjs
main();
