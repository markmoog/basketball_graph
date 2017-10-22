proc index_of*[T](a: openarray, b: T): int =
  for idx, item in a:
    if b == item:
      return idx
  return -1
