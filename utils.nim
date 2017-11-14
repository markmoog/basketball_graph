import strutils
import tables
import streams


# A simple function that returns the index of the element in an openarray.
# Returns -1 if the item is not found.

proc index_of*[T](a: openarray, b: T): int =
  for idx, item in a:
    if b == item:
      return idx
  return -1


# function for reading config values from a file, format should be:
# parameter_name1: parameter_value1
# parameter_name2: parameter_value2
# ...

proc load_config*(file_path: string): Table_Ref[string, string] =
  var config_table = new_table[string, string]()
  let config_data = new_file_stream(file_path, fm_read).read_all()

  if config_data == nil:
    quit("Cannot open configuration file")

  # Read the config file
  for line in split_lines(config_data):
    let key_value = split(line, ':')
    # make sure we have a key and a value in the line!
    if key_value.len != 2:
      continue

    let key: string = key_value[0]
    let value: string = key_value[1]

    config_table[key] = value

  return config_table


# Very simple date type and methods. Ignores many edge cases. Use with caution.

type Date* = tuple[year: int, month: int, day: int]

proc `$`*(d: Date): string =
  return $d.month & "/" & $d.day & "/" & $d.year

# Does not account for leap years!!!!
proc next_day*(d: Date): Date =
  let days: array = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

  var day = d.day
  var month = d.month
  var year = d.year

  if day < days[month - 1]:
    inc day
  else:
    if month < 12:
      inc month
      day = 1
    else:
      inc year
      day = 1
      month = 1

  return (year, month, day)

# Takes a string of the form MM/DD/YYYY and returns the date object

proc parse_date*(s: string): Date =
  let month: int = s[0 .. 1].parse_int()
  let day: int = s[3 .. 4].parse_int()
  let year: int = s[6 .. 9].parse_int()

  return (year, month, day)

proc `<`*(d0: Date, d1: Date): bool =
  if d0.year < d1.year:
    return true
  elif d0.year > d1.year:
    return false
  else:
    if d0.month < d1.month:
      return true
    elif d0.month > d1.month:
      return false
    else:
      if d0.day < d1.day:
        return true
      else:
       return false

proc `<=`*(d0: Date, d1: Date): bool =
  if d0.year < d1.year:
    return true
  elif d0.year > d1.year:
    return false
  else:
    if d0.month < d1.month:
      return true
    elif d0.month > d1.month:
      return false
    else:
      if d0.day <= d1.day:
        return true
      else:
       return false

proc `>`*(d0: Date, d1: Date): bool =
  if d0.year < d1.year:
    return false
  elif d0.year > d1.year:
    return true
  else:
    if d0.month < d1.month:
      return false
    elif d0.month > d1.month:
      return true
    else:
      if d0.day > d1.day:
        return true
      else:
       return false

proc `>=`*(d0: Date, d1: Date): bool =
  if d0.year < d1.year:
    return false
  elif d0.year > d1.year:
    return true
  else:
    if d0.month < d1.month:
      return false
    elif d0.month > d1.month:
      return true
    else:
      if d0.day >= d1.day:
        return true
      else:
       return false

proc `==`*(d0: Date, d1: Date): bool =
  if d0.year == d1.year and d0.month == d1.month and d0.day == d1.day:
    return true
  else:
    return false

